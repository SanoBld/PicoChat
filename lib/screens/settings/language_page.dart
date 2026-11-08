// lib/screens/settings/language_page.dart
// Language picker. Reads the list from supported_locales.dart.

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../services/prefs.dart';
import '../../supported_locales.dart';
import '../../theme/m3_interaction.dart';
import '../../widgets/m3_components.dart';
import 'settings_helpers.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  @override
  void initState() {
    super.initState();
    localeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _setLocale(String code) async {
    localeNotifier.value = code;
    await savePref('pc_locale', code);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final current = localeNotifier.value;

    return Scaffold(
      appBar: M3AppBar(title: tr('set_language')),
      body: M3MaxWidth(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          SettingsSection(label: tr('set_language'), children: [
            for (final lang in kSupportedLocales)
              M3InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _setLocale(lang.code),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Text(lang.flag, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(lang.nativeName,
                            style: text.bodyLarge?.copyWith(
                                fontWeight: current == lang.code ? FontWeight.w700 : FontWeight.w500)),
                        Text(lang.englishName, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                    if (current == lang.code)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded, color: scheme.onPrimary, size: 16),
                      )
                    else
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.outlineVariant, width: 1.5),
                        ),
                      ),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('language_note'), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
            ]),
          ),
        ]),
      ),
    );
  }
}
