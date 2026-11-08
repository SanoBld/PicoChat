// lib/l10n/l10n.dart
// ══════════════════════════════════════════════════════════════════════════
//  Localisation entry point.
//    tr('key')                     → text in the current language
//    tr('key', {'name': 'Nono'})   → replaces {name} in the text
//    L.commonCancel …              → shortcuts used by the shared settings kit
//
//  To add a language:
//    1. Copy strings_en.dart to strings_xx.dart and translate the values.
//    2. Add it to the _tables map below.
//    3. Add one line to supported_locales.dart.
//  Missing keys fall back to English, then to the key itself.
// ══════════════════════════════════════════════════════════════════════════

import '../app_state.dart';
import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_es.dart';
import 'strings_fr.dart';

const Map<String, Map<String, String>> _tables = {
  'en': kStringsEn,
  'fr': kStringsFr,
  'es': kStringsEs,
  'de': kStringsDe,
};

/// Translates [key] into the current language.
String tr(String key, [Map<String, String>? args]) {
  var s = _tables[localeNotifier.value]?[key] ?? kStringsEn[key] ?? key;
  if (args != null) {
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
  }
  return s;
}

/// Named shortcuts for the strings used by the shared settings widgets.
class _Strings {
  const _Strings();
  String get commonCancel => tr('cancel');
  String get commonSave => tr('save');
  String get commonApply => tr('apply');
  String get commonRetry => tr('retry');
  String get restartHintFeatures => tr('restart_hint');
  String get colorPickerTitle => tr('cp_title');
  String get colorPickerInvalid => tr('cp_invalid');
  String get colorPickerHue => tr('cp_hue');
  String get colorPickerSaturation => tr('cp_sat');
  String get colorPickerBrightness => tr('cp_bright');
  String get colorPickerQuickColors => tr('cp_quick');
}

const L = _Strings();
