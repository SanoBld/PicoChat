// lib/services/map_service.dart
// "Where am I?" and "route from A to B": the app finds the real data
// (GPS, OpenStreetMap Nominatim, OSM routing) and draws a map card.
// The AI only describes what the app found.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_state.dart';
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
  static const _stop = r"(?=\s+(?:en|by|[àa] pied|[àa] v[ée]lo|on foot|zu fu[ßs]|mit|via)\b|[?.!]|$)";
  static final _fromTo = RegExp(
      r"(?:de|depuis|from|von|desde)\s+(.+?)\s+(?:[àa]|vers|jusqu'[àa]u?|to|nach|hasta)\s+(.+?)" + _stop,
      caseSensitive: false);
  static final _toOnly = RegExp(
      r"(?:[àa]|vers|jusqu'[àa]u?|chez|to|nach|hasta)\s+(.+?)" + _stop,
      caseSensitive: false);

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
      },
      'Current position of the user: $label (lat ${l.lat!.toStringAsFixed(5)}, lon ${l.lon!.toStringAsFixed(5)}). '
          'A map with their position is shown. Describe where they are in one or two sentences.',
      'step_map',
      l.label ?? '',
    );
  }

  static Future<List<double>?> _geocode(String place, {double? nearLat, double? nearLon}) async {
    final params = {
      'format': 'jsonv2',
      'limit': '1',
      'q': place,
      'accept-language': localeNotifier.value,
      if (nearLat != null && nearLon != null)
        'viewbox': '${nearLon - 0.6},${nearLat + 0.6},${nearLon + 0.6},${nearLat - 0.6}',
    };
    final r = await http
        .get(Uri.https('nominatim.openstreetmap.org', '/search', params), headers: _ua)
        .timeout(const Duration(seconds: 10));
    final j = jsonDecode(r.body);
    if (j is! List || j.isEmpty) return null;
    return [double.parse('${j[0]['lat']}'), double.parse('${j[0]['lon']}')];
  }

  static String _clean(String s) => s.replaceAll(RegExp(r"^(?:la|le|l'|les|the)\s+", caseSensitive: false), '').trim();

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

    final loc = LocationService.instance;
    final hasHere = await _ensureLocation();
    final near = hasHere ? [loc.lat!, loc.lon!] : null;
    List<double>? a;
    String fromName;
    if (from == null || RegExp(r"^(?:chez moi|ici|ma position|here|my location|moi)$", caseSensitive: false).hasMatch(from)) {
      if (!hasHere) return null;
      a = [loc.lat!, loc.lon!];
      fromName = loc.label ?? 'You';
    } else {
      a = await _geocode(from, nearLat: near?[0], nearLon: near?[1]);
      fromName = from;
    }
    final b = await _geocode(to, nearLat: near?[0] ?? a?[0], nearLon: near?[1] ?? a?[1]);
    if (a == null || b == null) return null;

    final foot = RegExp(r"[àa] pied|on foot|walk|zu fu[ßs]|a pie", caseSensitive: false).hasMatch(q);
    final bike = RegExp(r"v[ée]lo|bike|cycl|fahrrad|bici", caseSensitive: false).hasMatch(q);
    final mode = foot ? 'foot' : (bike ? 'bike' : 'car');
    final url = Uri.parse('https://routing.openstreetmap.de/routed-$mode/route/v1/driving/'
        '${a[1]},${a[0]};${b[1]},${b[0]}?overview=full&geometries=geojson&steps=true');
    final r = await http.get(url, headers: _ua).timeout(const Duration(seconds: 15));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final routes = j['routes'] as List?;
    if (routes == null || routes.isEmpty) return null;
    final rt = routes.first as Map<String, dynamic>;

    // At most ~250 points: smooth line, light to save in the chat.
    final coords = (rt['geometry']['coordinates'] as List).cast<List>();
    final stepN = (coords.length / 250).ceil().clamp(1, 1000);
    final pts = <List<double>>[
      for (var i = 0; i < coords.length; i += stepN) [(coords[i][1] as num).toDouble(), (coords[i][0] as num).toDouble()],
      [(coords.last[1] as num).toDouble(), (coords.last[0] as num).toDouble()],
    ];
    final km = (rt['distance'] as num) / 1000;
    final min = ((rt['duration'] as num) / 60).round();

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
    final modeName = {'car': 'by car', 'foot': 'on foot', 'bike': 'by bike'}[mode]!;
    return CardResult(
      {'type': 'map', 'mode': mode, 'from': fromName, 'to': to, 'km': km, 'min': min, 'pts': pts},
      'Route $modeName from $fromName to $to: ${km.toStringAsFixed(1)} km, about $min min. '
          '${roads.isEmpty ? '' : 'Main roads: ${roads.take(8).join(', ')}. '}'
          'A map with the route is shown. Describe the trip briefly (distance, time, main roads). Do not invent other steps.',
      'step_map',
      '$fromName → $to',
    );
  }
}
