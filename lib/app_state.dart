// lib/app_state.dart
// ══════════════════════════════════════════════════════════════════════════
//  Global app state: one ValueNotifier per setting.
//  Every notifier is loaded from SharedPreferences in main.dart and written
//  back by the settings page that owns it. All preference keys start with 'pc_'.
//  The colour helpers at the bottom are the same ones as LastStats.
// ══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// PicoChat brand colour (teal), used until another accent is picked.
const Color kDefaultAccent = Color(0xFF0F766E);

// ── Appearance ───────────────────────────────────────────────────────────────
final themeModeNotifier        = ValueNotifier<ThemeMode>(ThemeMode.system); // pc_theme
final accentNotifier           = ValueNotifier<Color>(kDefaultAccent);       // pc_accent
final useDynamicColorNotifier  = ValueNotifier<bool>(false);                 // pc_use_dynamic_color
final localeNotifier           = ValueNotifier<String>('en');                // pc_locale
final colorHarmonyNotifier     = ValueNotifier<String>('mono');              // pc_color_harmony
final oledModeNotifier         = ValueNotifier<bool>(false);                 // pc_oled_mode
final textScaleNotifier        = ValueNotifier<double>(1.0);                 // pc_text_scale
final appFontNotifier          = ValueNotifier<String>('GoogleSansFlex');    // pc_app_font
final imageShapeNotifier       = ValueNotifier<String>('mix');               // pc_image_shape
final hapticFeedbackNotifier   = ValueNotifier<bool>(true);                  // pc_haptic_feedback
final pcModeNotifier           = ValueNotifier<String>('auto');              // pc_layout: auto | on | off
final displayNameNotifier      = ValueNotifier<String>('');                  // pc_display_name

// ── Chat behaviour ───────────────────────────────────────────────────────────
const String kDefaultSystemPrompt =
    'You are PicoChat, a helpful, concise and friendly assistant running '
    'entirely on the user\'s device.';
final systemPromptNotifier     = ValueNotifier<String>(kDefaultSystemPrompt); // pc_system_prompt
final temperatureNotifier      = ValueNotifier<double>(0.7);                  // pc_temperature
final maxTokensNotifier        = ValueNotifier<int>(1024);                    // pc_max_tokens
final contextSizeNotifier      = ValueNotifier<int>(4096);                    // pc_context_size
final streamResponsesNotifier  = ValueNotifier<bool>(true);                   // pc_stream
final autoTitleNotifier        = ValueNotifier<bool>(true);                   // pc_auto_title
final sendOnEnterNotifier      = ValueNotifier<bool>(true);                   // pc_send_on_enter
final webSearchNotifier        = ValueNotifier<bool>(false);                  // pc_web_search
final memoryEnabledNotifier    = ValueNotifier<bool>(true);                   // pc_memory
final webMaxSourcesNotifier    = ValueNotifier<int>(8);                       // pc_web_max (0 = no limit)
final autoSpeakNotifier        = ValueNotifier<bool>(false);                  // pc_auto_speak

// ── Models / Hugging Face ────────────────────────────────────────────────────
const String kDefaultHfEndpoint = 'https://huggingface.co';
final activeModelNotifier      = ValueNotifier<String>('');                   // pc_active_model
final hfTokenNotifier          = ValueNotifier<String>('');                   // pc_hf_token
final hfEndpointNotifier       = ValueNotifier<String>(kDefaultHfEndpoint);   // pc_hf_endpoint

ThemeMode themeFromString(String? s) {
  switch (s) {
    case 'light':  return ThemeMode.light;
    case 'dark':   return ThemeMode.dark;
    default:       return ThemeMode.system;
  }
}

/// Accepts a named key ('purple', 'blue'…) or a hex code '#RRGGBB'.
Color accentFromString(String? s) {
  if (s == null) return kDefaultAccent;
  if (s.startsWith('#') && s.length == 7) {
    try {
      return Color(0xFF000000 | int.parse(s.substring(1), radix: 16));
    } catch (_) {}
  }
  switch (s) {
    case 'blue':    return const Color(0xFF1D4ED8);
    case 'green':   return const Color(0xFF059669);
    case 'red':     return const Color(0xFFDC2626);
    case 'orange':  return const Color(0xFFD97706);
    case 'pink':    return const Color(0xFFDB2777);
    case 'neutral': return const Color(0xFF607D8B);
    case 'purple':  return const Color(0xFF7C3AED);
    default:        return kDefaultAccent;
  }
}

/// Converts a [Color] to an uppercase '#RRGGBB' string.
String colorToHex(Color c) {
  final r = (c.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final g = (c.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final b = (c.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}

/// Returns the seed color to pass to ColorScheme.fromSeed.
///
/// Any color, including pure black and white, is passed through unchanged.
Color seedColorForScheme(Color c) => c;

/// True for colors with (near) zero saturation: black, white, and grays.
bool isNeutralColor(Color c) => HSLColor.fromColor(c).saturation < 0.03;

/// Strips any hue from [c], keeping only its lightness, so it reads as a
/// true neutral gray (same lightness, zero saturation).
Color _toNeutralGray(Color c) =>
    HSLColor.fromColor(c).withSaturation(0).withHue(0).toColor();

/// Same fix as [neutralizeIfGraySeed], but for a ColorScheme that came from
/// the OS (Material You / dynamic color from wallpaper) rather than from
/// our own seed color — there [scheme.primary] itself is the best signal
/// for "this device's dynamic color is essentially gray".
ColorScheme neutralizeIfGraySchemeItself(ColorScheme scheme) =>
    neutralizeIfGraySeed(scheme, scheme.primary);

/// Material's HCT-based ColorScheme.fromSeed bakes in a faint hue (often
/// blue/purple) even for a seed with zero chroma — a float-rounding quirk
/// in the underlying HCT conversion, not something under our control. When
/// the user picked a true black/white/gray accent, that tint is exactly
/// the "everything looks bluish" bug: this strips it back out of every
/// scheme field that would otherwise carry it, without touching schemes
/// built from an actually-colored seed.
ColorScheme neutralizeIfGraySeed(ColorScheme scheme, Color seed) {
  if (!isNeutralColor(seed)) return scheme;
  return scheme.copyWith(
    primary:                 _toNeutralGray(scheme.primary),
    onPrimary:               _toNeutralGray(scheme.onPrimary),
    primaryContainer:        _toNeutralGray(scheme.primaryContainer),
    onPrimaryContainer:      _toNeutralGray(scheme.onPrimaryContainer),
    secondary:               _toNeutralGray(scheme.secondary),
    onSecondary:             _toNeutralGray(scheme.onSecondary),
    secondaryContainer:      _toNeutralGray(scheme.secondaryContainer),
    onSecondaryContainer:    _toNeutralGray(scheme.onSecondaryContainer),
    tertiary:                _toNeutralGray(scheme.tertiary),
    onTertiary:              _toNeutralGray(scheme.onTertiary),
    tertiaryContainer:       _toNeutralGray(scheme.tertiaryContainer),
    onTertiaryContainer:     _toNeutralGray(scheme.onTertiaryContainer),
    outline:                 _toNeutralGray(scheme.outline),
    outlineVariant:          _toNeutralGray(scheme.outlineVariant),
    surfaceTint:             _toNeutralGray(scheme.surfaceTint),
    surface:                 _toNeutralGray(scheme.surface),
    surfaceDim:              _toNeutralGray(scheme.surfaceDim),
    surfaceBright:           _toNeutralGray(scheme.surfaceBright),
    surfaceContainerLowest:  _toNeutralGray(scheme.surfaceContainerLowest),
    surfaceContainerLow:     _toNeutralGray(scheme.surfaceContainerLow),
    surfaceContainer:        _toNeutralGray(scheme.surfaceContainer),
    surfaceContainerHigh:    _toNeutralGray(scheme.surfaceContainerHigh),
    surfaceContainerHighest: _toNeutralGray(scheme.surfaceContainerHighest),
    onSurface:               _toNeutralGray(scheme.onSurface),
    onSurfaceVariant:        _toNeutralGray(scheme.onSurfaceVariant),
  );
}

/// Makes every accent role share the primary's hue (only lightness and
/// saturation change). Material's tertiary is normally a different hue,
/// which put unrelated colors next to a blue/teal/... theme. Pure grays are
/// left untouched.
ColorScheme monochromeAccents(ColorScheme s) {
  if (isNeutralColor(s.primary)) return s;
  final p = HSLColor.fromColor(s.primary);
  final dark = s.brightness == Brightness.dark;

  Color same(Color ref, {double sat = 1.0, double dl = 0.0}) {
    final r = HSLColor.fromColor(ref);
    return HSLColor.fromAHSL(1, p.hue,
        (p.saturation * sat).clamp(0.0, 1.0).toDouble(),
        (r.lightness + dl).clamp(0.0, 1.0).toDouble()).toColor();
  }
  Color on(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark
          ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  final secondary = same(s.secondary, sat: 0.6);
  final secondaryContainer = same(s.secondaryContainer, sat: 0.6);
  final tertiary = same(s.primary, dl: dark ? -0.16 : 0.16);
  final tertiaryContainer = same(s.primaryContainer, sat: 0.9, dl: dark ? 0.09 : -0.07);
  return s.copyWith(
    secondary: secondary,
    onSecondary: on(secondary),
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: same(s.onSecondaryContainer, sat: 0.6),
    tertiary: tertiary,
    onTertiary: on(tertiary),
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: same(s.onPrimaryContainer, sat: 0.8),
  );
}

/// Gives every neutral role (surfaces, outlines, on-surface text) a faint tint
/// of the primary hue, so the UI never shows a dead neutral gray.
/// Lightness is kept, only hue / a little saturation change.
ColorScheme tintNeutrals(ColorScheme s) {
  if (isNeutralColor(s.primary)) return s;
  final h = HSLColor.fromColor(s.primary).hue;
  final dark = s.brightness == Brightness.dark;
  // Fixed saturation (not "at least"): the tonal palette is almost gray at
  // these lightness values, so a floor would change nothing visible.
  Color t(Color c, {double sat = 0.30}) {
    final l = HSLColor.fromColor(c);
    if (l.lightness < 0.02) return c; // keep pure black (OLED)
    final target = dark ? sat * 0.75 : sat;
    return HSLColor.fromAHSL(1, h, target.clamp(0.0, 1.0), l.lightness).toColor();
  }
  return s.copyWith(
    outline: t(s.outline, sat: 0.22),
    outlineVariant: t(s.outlineVariant),
    surface: t(s.surface), surfaceDim: t(s.surfaceDim), surfaceBright: t(s.surfaceBright),
    surfaceContainerLowest: t(s.surfaceContainerLowest),
    surfaceContainerLow: t(s.surfaceContainerLow),
    surfaceContainer: t(s.surfaceContainer),
    surfaceContainerHigh: t(s.surfaceContainerHigh),
    surfaceContainerHighest: t(s.surfaceContainerHighest),
    onSurface: t(s.onSurface, sat: 0.22),
    onSurfaceVariant: t(s.onSurfaceVariant, sat: 0.2),
    inverseSurface: t(s.inverseSurface, sat: 0.2),
    onInverseSurface: t(s.onInverseSurface, sat: 0.2),
    shadow: t(s.shadow, sat: 0.2),
  );
}

/// Builds the app color scheme for a seed and a harmony style.
ColorScheme buildAppScheme(Color seed, Brightness b, String harmony) {
  final variant = switch (harmony) {
    'vivid' => DynamicSchemeVariant.vibrant,
    'soft'  => DynamicSchemeVariant.neutral,
    'tinted' => DynamicSchemeVariant.tonalSpot,
    _       => DynamicSchemeVariant.tonalSpot,
  };
  final base = neutralizeIfGraySeed(ColorScheme.fromSeed(
    seedColor: seedColorForScheme(seed),
    brightness: b,
    dynamicSchemeVariant: variant,
  ), seed);
  return applyColorHarmony(base, harmony);
}

/// 'classic' keeps the scheme as is, 'tinted' uses one hue and tints every
/// neutral too, every other style uses one hue.
ColorScheme applyColorHarmony(ColorScheme s, String harmony) => switch (harmony) {
      'classic' => s,
      'tinted'  => tintNeutrals(monochromeAccents(s)),
      _         => monochromeAccents(s),
    };
