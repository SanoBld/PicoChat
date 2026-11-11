// lib/services/sync/sync_prefs.dart
// The settings that can travel between devices (and into a backup), grouped by category.
// Nothing private is listed here: no API keys, no Hugging Face token, no permissions,
// nothing that depends on the device (models on disk, sidebar width, layout, location).

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../prefs.dart';

/// Categories shown to the person (sync page, intro, backup).
const String kCatChats = 'chats';
const String kCatMemory = 'memory';
const String kCatAppearance = 'appearance';
const String kCatBehavior = 'behavior';
const List<String> kAllCats = [kCatChats, kCatMemory, kCatAppearance, kCatBehavior];

class SyncPref {
  final String key; // SharedPreferences key
  final String cat;
  final Listenable notifier;
  final Object Function() read; // current value as a plain bool/int/double/String
  final void Function(Object v) write; // sets the notifier from a plain value
  const SyncPref(this.key, this.cat, this.notifier, this.read, this.write);
}

SyncPref _b(String key, String cat, ValueNotifier<bool> n) =>
    SyncPref(key, cat, n, () => n.value, (v) => n.value = v == true);

SyncPref _s(String key, String cat, ValueNotifier<String> n) =>
    SyncPref(key, cat, n, () => n.value, (v) => n.value = '$v');

SyncPref _d(String key, String cat, ValueNotifier<double> n) =>
    SyncPref(key, cat, n, () => n.value, (v) => n.value = (v as num).toDouble());

SyncPref _i(String key, String cat, ValueNotifier<int> n) =>
    SyncPref(key, cat, n, () => n.value, (v) => n.value = (v as num).toInt());

final List<SyncPref> kSyncPrefs = [
  // Appearance
  SyncPref(
      'pc_theme',
      kCatAppearance,
      themeModeNotifier,
      () => const {ThemeMode.system: 'system', ThemeMode.light: 'light', ThemeMode.dark: 'dark'}[themeModeNotifier.value]!,
      (v) => themeModeNotifier.value = themeFromString('$v')),
  SyncPref('pc_accent', kCatAppearance, accentNotifier, () => colorToHex(accentNotifier.value),
      (v) => accentNotifier.value = accentFromString('$v')),
  _b('pc_use_dynamic_color', kCatAppearance, useDynamicColorNotifier),
  _s('pc_color_harmony', kCatAppearance, colorHarmonyNotifier),
  _b('pc_oled_mode', kCatAppearance, oledModeNotifier),
  _d('pc_text_scale', kCatAppearance, textScaleNotifier),
  _s('pc_app_font', kCatAppearance, appFontNotifier),
  _s('pc_image_shape', kCatAppearance, imageShapeNotifier),
  _b('pc_haptic_feedback', kCatAppearance, hapticFeedbackNotifier),
  _b('pc_shapes', kCatAppearance, materialShapesNotifier),
  _b('pc_opening_anim', kCatAppearance, openingAnimNotifier),
  _b('pc_eco_mode', kCatAppearance, ecoModeNotifier),
  _s('pc_locale', kCatAppearance, localeNotifier),
  // Memory and profile
  _s('pc_display_name', kCatMemory, displayNameNotifier),
  _b('pc_memory', kCatMemory, memoryEnabledNotifier),
  _i('pc_memory_limit', kCatMemory, memoryLimitNotifier),
  // How the AI behaves
  _s('pc_system_prompt', kCatBehavior, systemPromptNotifier),
  _d('pc_temperature', kCatBehavior, temperatureNotifier),
  _i('pc_max_tokens', kCatBehavior, maxTokensNotifier),
  _b('pc_stream', kCatBehavior, streamResponsesNotifier),
  _b('pc_auto_title', kCatBehavior, autoTitleNotifier),
  _b('pc_auto_cmd', kCatBehavior, autoCommandsNotifier),
  _s('pc_search_engine', kCatBehavior, searchEngineNotifier),
  _s('pc_reasoning', kCatBehavior, reasoningModeNotifier),
  _b('pc_show_steps', kCatBehavior, showStepsNotifier),
  _b('pc_steps_open', kCatBehavior, stepsOpenNotifier),
  _b('pc_ultra', kCatBehavior, ultraModeNotifier),
  _b('pc_web_auto', kCatBehavior, webAutoNotifier),
  _b('pc_web_ask', kCatBehavior, webAskNotifier),
  _i('pc_web_max', kCatBehavior, webMaxSourcesNotifier),
  _b('pc_unlimited', kCatBehavior, unlimitedNotifier),
  _s('pc_answer_len', kCatBehavior, answerLengthNotifier),
  _b('pc_auto_speak', kCatBehavior, autoSpeakNotifier),
  _b('pc_ctx_time', kCatBehavior, contextTimeNotifier),
  _s('pc_city', kCatBehavior, cityManualNotifier),
];

SyncPref? syncPrefByKey(String key) {
  for (final p in kSyncPrefs) {
    if (p.key == key) return p;
  }
  return null;
}

/// Sets the setting on this device and saves it.
Future<void> applySyncPref(SyncPref p, Object v) async {
  p.write(v);
  await savePref(p.key, p.read());
}
