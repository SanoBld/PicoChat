// lib/main.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'services/chat_store.dart';
import 'services/model_manager.dart';
import 'supported_locales.dart';
import 'theme/m3_interaction.dart';
import 'theme/m3_motion.dart';
import 'theme/m3_shapes.dart';
import 'widgets/app_text_scale.dart';
import 'widgets/custom_title_bar.dart';

void main() {
  // On desktop an uncaught async error outside a guarded zone ends the process.
  runZonedGuarded(_mainImpl, (error, stack) => debugPrint('Uncaught error: $error'));
}

Future<void> _mainImpl() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) => debugPrint('Flutter error: ${d.exception}');
  PlatformDispatcher.instance.onError = (e, s) {
    debugPrint('Platform error: $e');
    return true;
  };

  // Frameless window with a theme-matched title bar on Windows / Linux.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      minimumSize: Size(420, 500),
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final p = await SharedPreferences.getInstance();

  // First launch: follow the phone language when we support it.
  final deviceLang = PlatformDispatcher.instance.locale.languageCode;
  final fallbackLang = kSupportedLocales.any((l) => l.code == deviceLang) ? deviceLang : 'en';

  themeModeNotifier.value = themeFromString(p.getString('pc_theme'));
  accentNotifier.value = accentFromString(p.getString('pc_accent'));
  useDynamicColorNotifier.value = p.getBool('pc_use_dynamic_color') ?? false;
  localeNotifier.value = p.getString('pc_locale') ?? fallbackLang;
  colorHarmonyNotifier.value = p.getString('pc_color_harmony') ?? 'mono';
  oledModeNotifier.value = p.getBool('pc_oled_mode') ?? false;
  textScaleNotifier.value = p.getDouble('pc_text_scale') ?? 1.0;
  // A font removed together with the old theme falls back to the default.
  const knownFonts = {'GoogleSansFlex', 'Inter', 'Roboto', 'OpenSans', 'SpaceGrotesk'};
  final savedFont = p.getString('pc_app_font');
  appFontNotifier.value = knownFonts.contains(savedFont) ? savedFont! : 'GoogleSansFlex';
  imageShapeNotifier.value = p.getString('pc_image_shape') ?? 'mix';
  hapticFeedbackNotifier.value = p.getBool('pc_haptic_feedback') ?? true;
  pcModeNotifier.value = p.getString('pc_layout') ?? 'auto';
  displayNameNotifier.value = p.getString('pc_display_name') ?? '';

  systemPromptNotifier.value = p.getString('pc_system_prompt') ?? kDefaultSystemPrompt;
  temperatureNotifier.value = p.getDouble('pc_temperature') ?? 0.7;
  maxTokensNotifier.value = p.getInt('pc_max_tokens') ?? 1024;
  contextSizeNotifier.value = p.getInt('pc_context_size') ?? 4096;
  streamResponsesNotifier.value = p.getBool('pc_stream') ?? true;
  autoTitleNotifier.value = p.getBool('pc_auto_title') ?? true;
  sendOnEnterNotifier.value = p.getBool('pc_send_on_enter') ?? true;

  activeModelNotifier.value = p.getString('pc_active_model') ?? '';
  hfTokenNotifier.value = p.getString('pc_hf_token') ?? '';
  hfEndpointNotifier.value = p.getString('pc_hf_endpoint') ?? kDefaultHfEndpoint;

  await Future.wait([ChatStore.instance.init(), ModelManager.instance.init()]);

  runApp(PicoChatApp(onboarded: p.getBool('pc_onboarded') ?? false));
}

class PicoChatApp extends StatelessWidget {
  final bool onboarded;
  const PicoChatApp({super.key, required this.onboarded});

  ThemeData _decorate(ThemeData t) =>
      applyM3Interaction(applyM3Shapes(t.copyWith(pageTransitionsTheme: kM3PageTransitions)));

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            themeModeNotifier,
            accentNotifier,
            useDynamicColorNotifier,
            localeNotifier,
            colorHarmonyNotifier,
            oledModeNotifier,
          ]),
          builder: (_, _) {
            // Material You look with the chosen accent.
            final harmony = colorHarmonyNotifier.value;
            final useDyn = useDynamicColorNotifier.value;
            final accent = accentNotifier.value;
            final lightScheme = (useDyn && lightDynamic != null)
                ? applyColorHarmony(neutralizeIfGraySchemeItself(lightDynamic.harmonized()), harmony)
                : buildAppScheme(accent, Brightness.light, harmony);
            var darkScheme = (useDyn && darkDynamic != null)
                ? applyColorHarmony(neutralizeIfGraySchemeItself(darkDynamic.harmonized()), harmony)
                : buildAppScheme(accent, Brightness.dark, harmony);
            if (oledModeNotifier.value) {
              darkScheme = darkScheme.copyWith(
                surface: Colors.black,
                surfaceDim: Colors.black,
                surfaceBright: const Color(0xFF1C1C1C),
                surfaceContainerLowest: Colors.black,
                surfaceContainerLow: const Color(0xFF080808),
                surfaceContainer: const Color(0xFF0D0D0D),
                surfaceContainerHigh: const Color(0xFF141414),
                surfaceContainerHighest: const Color(0xFF1C1C1C),
              );
              if (harmony == 'tinted') darkScheme = tintNeutrals(darkScheme);
            }
            final light = _decorate(ThemeData(colorScheme: lightScheme, useMaterial3: true));
            final dark = _decorate(ThemeData(colorScheme: darkScheme, useMaterial3: true));

            return MaterialApp(
              title: 'PicoChat',
              debugShowCheckedModeBanner: false,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              locale: Locale(localeNotifier.value),
              supportedLocales: [for (final l in kSupportedLocales) Locale(l.code)],
              theme: light,
              darkTheme: dark,
              themeMode: themeModeNotifier.value,
              builder: (context, child) => AppTextScale(child: DesktopTitleBarShell(child: child!)),
              home: onboarded ? const HomeScreen() : const IntroScreen(),
            );
          },
        );
      },
    );
  }
}
