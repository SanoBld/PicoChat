// lib/services/web_intent.dart
// Decides when a message needs the web (automatic search mode).
import '../app_state.dart';
import 'location_service.dart';

class WebIntent {
  static final _needs = RegExp(
      r"m[ée]t[ée]o|weather|wetter|\bclima\b|quel temps|temps qu'il|temperature|temp[ée]rature|"
      r"aujourd'hui|ce soir|demain|maintenant|en ce moment|actualit|derni[èe]res? (?:news|nouvelles)|\bnews\b|latest|today|tonight|tomorrow|right now|"
      r"heute|morgen|jetzt|aktuell|noticias|hoy|ma[ñn]ana|ahora|"
      r"\bprix\b|\bcours\b|\bprice\b|\bpreis\b|\bprecio\b|bitcoin|\bscore\b|r[ée]sultat|\bmatch\b|classement|[ée]lection|"
      r"horaires?|ouvert|opening hours|near me|nearby|pr[èe]s de (?:moi|chez)|autour de moi|in der n[äa]he|cerca de m[ií]|"
      r"\b202[5-9]\b|qui est (?:le|la) (?:pr[ée]sident|premier)|who is the (?:president|prime)",
      caseSensitive: false);

  static final _local = RegExp(
      r"m[ée]t[ée]o|weather|wetter|\bclima\b|quel temps|temps qu'il|near me|nearby|pr[èe]s de (?:moi|chez)|autour de moi|in der n[äa]he|cerca de m[ií]|horaires?|ouvert|opening hours",
      caseSensitive: false);

  static bool needsWeb(String text) => _needs.hasMatch(text);

  /// Adds the city to local questions ("météo" → "météo Mulhouse").
  static String augment(String query) {
    final city = LocationService.instance.city;
    if (!locationEnabledNotifier.value || city == null || city.isEmpty) return query;
    if (!_local.hasMatch(query) || query.toLowerCase().contains(city.toLowerCase())) return query;
    return '$query $city';
  }
}
