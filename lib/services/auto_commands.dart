// lib/services/auto_commands.dart
// Understands short spoken/typed commands ("go to max", "minimum", "turn off
// web search") and applies them. Can be turned off in the settings.
import '../app_state.dart';
import '../l10n/l10n.dart';
import 'prefs.dart';

class AutoCommands {
  static const presets = {
    'eco': (0.5, 512, 2048),
    'balanced': (0.7, 1024, 4096),
    'max': (0.8, 3072, 8192),
    'ultra': (0.6, 4096, 16384),
  };

  static final _verb = r"(?:mets?|met|passe|pousse[sz]?|active|go|set|switch|use|utilise|ponlo|pon|activa|aktiviere|stell)";
  static final _ultra = RegExp(r"\bultra\b|recherche (?:tr[èe]s )?approfondie|deep research|investigaci[óo]n profunda", caseSensitive: false);
  static final _max = RegExp(
      r"mode\s+(?:max|maximum|maximal)\b|\b" + _verb + r"\s+(?:(?:le|la|en|au|à|to|the|al|el)\s+)*(?:max\b|maximum|fond)|pousse[sz]?\s+(?:au\s+|à\s+)?(?:max|maximum|fond)|push\s+(?:it\s+)?to\s+the\s+(?:max|limit)|full power|puissance maximale|al m[áa]ximo|volle leistung",
      caseSensitive: false);
  static final _eco = RegExp(
      r"mode\s+(?:[ée]co|minimum|[ée]conomique)\b|\b" + _verb + r"\s+(?:(?:le|la|en|au|à|to|the|al|el)\s+)*(?:min\b|minimum|[ée]co\b)|au minimum|[ée]conomise la batterie|save battery|al m[íi]nimo",
      caseSensitive: false);
  static final _balanced = RegExp(
      r"mode\s+(?:[ée]quilibr[ée]|normal|standard|balanced|equilibrado|ausgewogen)\b|(?:remets?|retour|back to|vuelve)\s+(?:(?:en|le|to|al)\s+)*(?:normal|standard|[ée]quilibr)",
      caseSensitive: false);
  static final _webOn = RegExp(r"\b(?:active|allume|mets?|enable|turn on|activa)\s+(?:la\s+)?(?:recherche\s+(?:web|internet)|web search|b[úu]squeda web)", caseSensitive: false);
  static final _webOff = RegExp(r"\b(?:d[ée]sactive|coupe|[ée]teins|arr[êe]te|turn off|disable|stop|desactiva)\s+(?:la\s+)?(?:recherche\s+(?:web|internet)|web search|b[úu]squeda web)", caseSensitive: false);

  static String? powerMode(String t) {
    if (t.length > 160) return null;
    if (_ultra.hasMatch(t)) return 'ultra';
    if (_max.hasMatch(t)) return 'max';
    if (_eco.hasMatch(t)) return 'eco';
    if (_balanced.hasMatch(t)) return 'balanced';
    return null;
  }

  /// Applies the commands found in [text]. Returns a short description of
  /// what was done (for the timeline and for the AI), or null.
  static Future<String?> apply(String text) async {
    if (!autoCommandsNotifier.value) return null;
    final done = <String>[];
    final mode = powerMode(text);
    if (mode != null) {
      final v = presets[mode]!;
      ultraModeNotifier.value = mode == 'ultra';
      temperatureNotifier.value = v.$1;
      maxTokensNotifier.value = v.$2;
      contextSizeNotifier.value = v.$3;
      await savePref('pc_ultra', mode == 'ultra');
      await savePref('pc_temperature', v.$1);
      await savePref('pc_max_tokens', v.$2);
      await savePref('pc_context_size', v.$3);
      done.add(tr('cmd_mode', {'mode': tr('power_$mode')}));
    }
    if (text.length <= 160) {
      if (_webOff.hasMatch(text)) {
        webSearchNotifier.value = false;
        webAutoNotifier.value = false;
        await savePref('pc_web_search', false);
        await savePref('pc_web_auto', false);
        done.add(tr('cmd_web_off'));
      } else if (_webOn.hasMatch(text)) {
        webSearchNotifier.value = true;
        await savePref('pc_web_search', true);
        done.add(tr('cmd_web_on'));
      }
    }
    return done.isEmpty ? null : done.join(' · ');
  }
}
