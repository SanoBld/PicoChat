// lib/services/image_lookup.dart
// Finds a real picture for a subject ("Lyon, France") through Wikipedia, so the
// AI can show images without inventing URLs.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_state.dart';

class ImageLookup {
  static final Map<String, Future<String?>> _cache = {};

  static Future<String?> find(String query) =>
      _cache.putIfAbsent(query.toLowerCase().trim(), () => _find(query.trim()));

  static Future<String?> _find(String q) async {
    if (q.isEmpty) return null;
    final langs = <String>{localeNotifier.value, 'en'};
    for (final lang in langs) {
      try {
        final u = Uri.https('$lang.wikipedia.org', '/w/api.php', {
          'action': 'query',
          'generator': 'search',
          'gsrsearch': q,
          'gsrlimit': '4',
          'prop': 'pageimages',
          'piprop': 'thumbnail',
          'pithumbsize': '900',
          'format': 'json',
          'origin': '*',
        });
        final r = await http.get(u, headers: {'User-Agent': 'PicoChat/0.1 (private chat app)'}).timeout(const Duration(seconds: 8));
        final pages = ((jsonDecode(r.body)['query']?['pages'] as Map?)?.values.toList() ?? []).whereType<Map>().toList()
          ..sort((a, b) => ((a['index'] as num?) ?? 99).compareTo((b['index'] as num?) ?? 99));
        for (final p in pages) {
          final t = p['thumbnail']?['source'];
          if (t is String && t.startsWith('http')) return t;
        }
      } catch (_) {}
    }
    return null;
  }
}
