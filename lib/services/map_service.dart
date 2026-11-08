// lib/services/map_service.dart
// Map data from OpenStreetMap (Nominatim + OSM routing).
//  • "Where am I?" / "route from A to B" in the question -> a map card.
//  • The AI can control the map with hidden tags in its answer:
//      [[map-point: place]]   [[map-route: A => B ; car|foot|bike]]   [[map-clear]]
//  • The person can touch the map too (see widgets/map_card.dart).
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../models/chat_models.dart';
import 'cards.dart';
import 'location_service.dart';

class MapService {
  static const _ua = {'User-Agent': 'PicoChat'};

  static final _whereRe = RegExp(
      r"o[uù] (?:suis[- ]je|je suis|on est|me trouve)|ma position|where am i|my location|where are we|wo bin ich|d[oó]nde estoy",
      caseSensitive: false);
  static final _routeRe = RegExp(
      r"itin[ée]raire|trajet|\broute\b|chemin pour|comment (?:aller|me rendre|se rendre|j'y vais)|how (?:do i|to|can i) (?:get|go|drive|walk)|directions?|navigate|wie komme ich|c[oó]mo llego",
      caseSensitive: false);
  static final _mapRe = RegExp(
      r"\bcarte\b|\bmaps?\b|marqueur|marque[rz]? |place[rz]? un point|ajoute[rz]? un point|un point sur|trajet|itin[ée]raire|\broute\b|where am i|ma position|on the map|auf der karte|en el mapa",
      caseSensitive: false);
  static const _stop = r"(?=\s+(?:en|by|[àa] pied|[àa] v[ée]lo|on foot|zu fu[ßs]|mit|via)\b|[?.!]|$)";
  static final _fromTo = RegExp(
      r"(?:de|depuis|from|von|desde)\s+(.+?)\s+(?:[àa]|vers|jusqu'[àa]u?|to|nach|hasta)\s+(.+?)" + _stop,
      caseSensitive: false);
  static final _toOnly = RegExp(
      r"(?:[àa]|vers|jusqu'[àa]u?|chez|to|nach|hasta)\s+(.+?)" + _stop,
      caseSensitive: false);
  static final _hereWords = RegExp(r"^(?:chez moi|ici|ma position|here|my location|moi|me)$", caseSensitive: false);
  static final _tagRe = RegExp(r"\[\[map-(point|route|clear)\s*:?\s*([^\]]*)\]\]");

  static bool needsNetwork(String q) => _whereRe.hasMatch(q) || _routeRe.hasMatch(q);
  static bool mapIntent(String q) => _mapRe.hasMatch(q);
  static bool hasTags(String s) => _tagRe.hasMatch(s);

  /// Given to the AI so it knows it can act on the map.
  static const hint = 'You can control the map shown to the user with hidden tags written in your answer '
      '(the user does not see them): [[map-point: place name or address]] adds a marker, '
      '[[map-route: A => B ; car]] draws a route (A can be left out = the user\'s position; use car, foot or bike), '
      '[[map-clear]] clears the map. Use them only when the user asks to mark, show or trace something, '
      'one tag per point, and keep the visible answer short.';

  static Future<CardResult?> build(String q) async {
    try {
      if (_whereRe.hasMatch(q)) return await _here();
      if (_routeRe.hasMatch(q)) return await _route(q);
    } catch (_) {}
    return null;
  }

  static Future<bool> _ensureLocation() async {
    final loc = LocationService.instance;
    if (loc.lat == null) {
      loc.busy = false;
      await loc.refresh();
    }
    return loc.lat != null && loc.lon != null;
  }

  static Map<String, dynamic> _mark(double lat, double lon, String label) => {'lat': lat, 'lon': lon, 'label': label};

  static Future<CardResult?> _here() async {
    if (!await _ensureLocation()) return null;
    final l = LocationService.instance;
    final label = l.address ?? l.label ?? '';
    return CardResult(
      {
        'type': 'map',
        'mode': 'here',
        'title': l.label ?? label,
        'sub': l.address ?? '',
        'pts': [[l.lat, l.lon]],
        'marks': [_mark(l.lat!, l.lon!, l.label ?? '')],
      },
      'Current position of the user: $label (lat ${l.lat!.toStringAsFixed(5)}, lon ${l.lon!.toStringAsFixed(5)}). '
          'A map with their position is shown. Describe where they are in one or two sentences.',
      'step_map',
      l.label ?? '',
    );
  }

  static Future<List<double>?> geocode(String place) async {
    final l = LocationService.instance;
    final params = {
      'format': 'jsonv2',
      'limit': '1',
      'q': place,
      'accept-language': localeNotifier.value,
      if (l.lat != null && l.lon != null) 'viewbox': '${l.lon! - 0.6},${l.lat! + 0.6},${l.lon! + 0.6},${l.lat! - 0.6}',
    };
    final r = await http
        .get(Uri.https('nominatim.openstreetmap.org', '/search', params), headers: _ua)
        .timeout(const Duration(seconds: 10));
    final j = jsonDecode(r.body);
    if (j is! List || j.isEmpty) return null;
    return [double.parse('${j[0]['lat']}'), double.parse('${j[0]['lon']}')];
  }

  static String _clean(String s) => s.replaceAll(RegExp(r"^(?:la|le|l'|les|the)\s+", caseSensitive: false), '').trim();

  /// Route through [pts] (lat, lon), in order. Returns pts/km/min/roads or null.
  static Future<Map<String, dynamic>?> routeVia(List<List<double>> pts, String mode) async {
    if (pts.length < 2) return null;
    final path = pts.map((p) => '${p[1]},${p[0]}').join(';');
    final url = Uri.parse('https://routing.openstreetmap.de/routed-$mode/route/v1/driving/$path'
        '?overview=full&geometries=geojson&steps=true');
    final r = await http.get(url, headers: _ua).timeout(const Duration(seconds: 15));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final routes = j['routes'] as List?;
    if (routes == null || routes.isEmpty) return null;
    final rt = routes.first as Map<String, dynamic>;
    // At most ~250 points: smooth line, light to save in the chat.
    final coords = (rt['geometry']['coordinates'] as List).cast<List>();
    final n = (coords.length / 250).ceil().clamp(1, 1000);
    final line = <List<double>>[
      for (var i = 0; i < coords.length; i += n) [(coords[i][1] as num).toDouble(), (coords[i][0] as num).toDouble()],
      [(coords.last[1] as num).toDouble(), (coords.last[0] as num).toDouble()],
    ];
    final roads = <String>[];
    for (final leg in (rt['legs'] as List)) {
      for (final s in (leg['steps'] as List)) {
        final name = '${s['name'] ?? ''}'.trim();
        final d = (s['distance'] as num) / 1000;
        if (name.isNotEmpty && d >= 0.3 && !roads.any((x) => x.startsWith(name))) {
          roads.add('$name (${d.toStringAsFixed(1)} km)');
        }
      }
    }
    return {
      'pts': line,
      'km': (rt['distance'] as num) / 1000,
      'min': ((rt['duration'] as num) / 60).round(),
      'roads': roads,
    };
  }

  static String _modeOf(String q) {
    if (RegExp(r"[àa] pied|on foot|walk|zu fu[ßs]|a pie|foot", caseSensitive: false).hasMatch(q)) return 'foot';
    if (RegExp(r"v[ée]lo|bike|cycl|fahrrad|bici", caseSensitive: false).hasMatch(q)) return 'bike';
    return 'car';
  }

  /// A route card between two named places ([from] null = the user's position).
  static Future<CardResult?> routeBetween(String? from, String to, String mode) async {
    final loc = LocationService.instance;
    final hasHere = await _ensureLocation();
    List<double>? a;
    String fromName;
    if (from == null || from.isEmpty || _hereWords.hasMatch(from)) {
      if (!hasHere) return null;
      a = [loc.lat!, loc.lon!];
      fromName = loc.label ?? 'You';
    } else {
      a = await geocode(from);
      fromName = from;
    }
    final b = await geocode(to);
    if (a == null || b == null) return null;
    final r = await routeVia([a, b], mode);
    if (r == null) return null;
    final km = r['km'] as double, min = r['min'] as int, roads = r['roads'] as List<String>;
    final modeName = {'car': 'by car', 'foot': 'on foot', 'bike': 'by bike'}[mode]!;
    return CardResult(
      {
        'type': 'map',
        'mode': mode,
        'from': fromName,
        'to': to,
        'km': km,
        'min': min,
        'pts': r['pts'],
        'marks': [_mark(a[0], a[1], fromName), _mark(b[0], b[1], to)],
      },
      'Route $modeName from $fromName to $to: ${km.toStringAsFixed(1)} km, about $min min. '
          '${roads.isEmpty ? '' : 'Main roads: ${roads.take(8).join(', ')}. '}'
          'A map with the route is shown. Describe the trip briefly (distance, time, main roads). Do not invent other steps.',
      'step_map',
      '$fromName → $to',
    );
  }

  static Future<CardResult?> _route(String q) async {
    String? from, to;
    final ft = _fromTo.firstMatch(q);
    if (ft != null) {
      from = _clean(ft.group(1)!);
      to = _clean(ft.group(2)!);
    } else {
      final t = _toOnly.firstMatch(q);
      if (t != null) to = _clean(t.group(1)!);
    }
    if (to == null || to.length < 2) return null;
    return routeBetween(from, to, _modeOf(q));
  }

  // ── Tags written by the AI ───────────────────────────────────────────
  /// Applies [[map-...]] tags of [raw] to the map card of [reply] (creates it if needed).
  static Future<void> applyTags(ChatMessage reply, String raw) async {
    Map<String, dynamic>? card() {
      for (final c in reply.cards) {
        if (c['type'] == 'map') return c;
      }
      return null;
    }

    for (final m in _tagRe.allMatches(raw)) {
      final kind = m.group(1)!;
      final arg = (m.group(2) ?? '').trim();
      try {
        if (kind == 'clear') {
          reply.cards.removeWhere((c) => c['type'] == 'map');
        } else if (kind == 'point' && arg.isNotEmpty) {
          final p = await geocode(arg);
          if (p == null) continue;
          var c = card();
          if (c == null) {
            c = {'type': 'map', 'mode': 'marks', 'pts': <dynamic>[], 'marks': <dynamic>[]};
            reply.cards.add(c);
          }
          (c['marks'] as List).add(_mark(p[0], p[1], arg));
          if (c['mode'] == 'here') c['mode'] = 'marks';
        } else if (kind == 'route' && arg.isNotEmpty) {
          final parts = arg.split(';');
          final mode = parts.length > 1 ? _modeOf(parts[1]) : 'car';
          final ends = parts.first.split(RegExp(r'=>|->|→'));
          final to = _clean(ends.last);
          final from = ends.length > 1 ? _clean(ends.first) : null;
          final r = await routeBetween(from, to, mode);
          if (r == null) continue;
          reply.cards.removeWhere((c) => c['type'] == 'map');
          reply.cards.add(r.card);
        }
      } catch (_) {}
    }
  }
}
