// lib/main.dart
import 'services/location_service.dart';
import 'services/memory_store.dart';
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
import 'screens/assist_overlay.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'services/chat_store.dart';
import 'services/inference_engine.dart';
import 'services/llama_engine.dart';
import 'services/model_manager.dart';
import 'services/notif_service.dart';
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

  // Real llama.cpp engine on every native platform. The web build keeps the
  // demo engine, because it cannot open model files from disk.
  if (!kIsWeb) InferenceService.engine = LlamaDartEngine();
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

  final p = await _loadState();
  if (locationEnabledNotifier.value) LocationService.instance.refresh();
  runApp(PicoChatApp(onboarded: p.getBool('pc_onboarded') ?? false));
}

/// Loads the saved settings, chats, models and memory (shared with the assistant overlay).
Future<SharedPreferences> _loadState() async {
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
  searchEngineNotifier.value = p.getString('pc_search_engine') ?? 'duckduckgo';
  sidebarCollapsedNotifier.value = p.getBool('pc_sidebar_collapsed') ?? false;
  voiceEngineNotifier.value = p.getString('pc_voice_engine') ?? 'whisper';
  voiceModelNotifier.value = p.getString('pc_voice_model') ?? 'base';
  reasoningModeNotifier.value = p.getString('pc_reasoning') ?? 'auto';
  showStepsNotifier.value = p.getBool('pc_show_steps') ?? true;
  stepsOpenNotifier.value = p.getBool('pc_steps_open') ?? true;
  autoCommandsNotifier.value = p.getBool('pc_auto_cmd') ?? true;
  ultraModeNotifier.value = p.getBool('pc_ultra') ?? false;
  cityManualNotifier.value = p.getString('pc_city') ?? '';
  webAutoNotifier.value = p.getBool('pc_web_auto') ?? true;
  locationEnabledNotifier.value = p.getBool('pc_location') ?? false;
  contextTimeNotifier.value = p.getBool('pc_ctx_time') ?? true;
  webSearchNotifier.value = p.getBool('pc_web_search') ?? false;
  materialShapesNotifier.value = p.getBool('pc_shapes') ?? true;
  memoryEnabledNotifier.value = p.getBool('pc_memory') ?? true;
  webMaxSourcesNotifier.value = p.getInt('pc_web_max') ?? 8;
  autoSpeakNotifier.value = p.getBool('pc_auto_speak') ?? false;
  devModeNotifier.value = p.getBool('pc_dev') ?? false;
  assistModelNotifier.value = p.getString('pc_assist_model') ?? '';
  accContactsNotifier.value = p.getBool('pc_acc_contacts') ?? false;
  accSmsNotifier.value = p.getBool('pc_acc_sms') ?? false;
  accNotifNotifier.value = p.getBool('pc_acc_notif') ?? false;
  accCalendarNotifier.value = p.getBool('pc_acc_cal') ?? false;
  notifProgressNotifier.value = p.getBool('pc_n_progress') ?? true;
  notifDoneNotifier.value = p.getBool('pc_n_done') ?? true;
  notifBackgroundNotifier.value = p.getBool('pc_n_bg') ?? true;

  activeModelNotifier.value = p.getString('pc_active_model') ?? '';
  hfTokenNotifier.value = p.getString('pc_hf_token') ?? '';
  hfEndpointNotifier.value = p.getString('pc_hf_endpoint') ?? kDefaultHfEndpoint;

  await Future.wait([ChatStore.instance.init(), ModelManager.instance.init(), MemoryStore.instance.init()]);
  NotifService.instance.attach();
  return p;
}

/// Entry point of the Android assistant overlay (started by AssistActivity).
@pragma('vm:entry-point')
Future<void> assistMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) InferenceService.engine = LlamaDartEngine();
  await _loadState();
  ChatStore.instance.persist = false; // the overlay must not overwrite the saved chats
  if (locationEnabledNotifier.value) LocationService.instance.refresh();
  runApp(const AssistApp());
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
