// lib/supported_locales.dart
// Single source of truth for the languages the app offers. Every language
// picker reads this list. To add a language, add one line here and register
// its strings table in l10n/l10n.dart.

class SupportedLocale {
  final String code; // matches pc_locale / localeNotifier
  final String flag; // emoji shown in pickers
  final String nativeName; // name in that language
  final String englishName;

  const SupportedLocale({
    required this.code,
    required this.flag,
    required this.nativeName,
    required this.englishName,
  });
}

const List<SupportedLocale> kSupportedLocales = [
  SupportedLocale(code: 'en', flag: '🇬🇧', nativeName: 'English', englishName: 'English'),
  SupportedLocale(code: 'fr', flag: '🇫🇷', nativeName: 'Français', englishName: 'French'),
  SupportedLocale(code: 'es', flag: '🇪🇸', nativeName: 'Español', englishName: 'Spanish'),
  SupportedLocale(code: 'de', flag: '🇩🇪', nativeName: 'Deutsch', englishName: 'German'),
];

/// Finds a locale by code, falling back to English.
SupportedLocale supportedLocaleFor(String code) {
  for (final l in kSupportedLocales) {
    if (l.code == code) return l;
  }
  return kSupportedLocales.first;
}
