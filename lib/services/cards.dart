// lib/services/cards.dart
// Real data for visual cards: exact calculations, weather (Open-Meteo) and
// live scores (ESPN). The app fetches the data, the AI only comments it.
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../app_state.dart';
import 'location_service.dart';

class CardResult {
  final Map<String, dynamic> card;
  final String summary; // given to the AI as context
  final String step; // l10n key of the timeline step
  final String detail;
  final bool only; // true: the card is the whole answer, the AI writes nothing
  const CardResult(this.card, this.summary, this.step, this.detail, {this.only = false});
}

class CardService {
  static final _weatherRe = RegExp(
      r"m[ée]t[ée]o|weather|wetter|\bclima\b|quel temps|temps qu'il|qu'il fait|forecast|pr[ée]visions",
      caseSensitive: false);
  static final _scoreRe = RegExp(r"\bscore\b|r[ée]sultat|\bmatch\b|gagn[ée]|\bwon\b|resultado|ergebnis|spiel", caseSensitive: false);

  /// True when answering this needs the internet (weather, scores), not the local calculator.
  static bool needsNetwork(String q) => _calc(q) == null && (_weatherRe.hasMatch(q) || _scoreRe.hasMatch(q));

  static Future<CardResult?> build(String q) async {
    try {
      final c = _calc(q);
      if (c != null) return c;
      if (_weatherRe.hasMatch(q)) return await _weather(q);
      if (_scoreRe.hasMatch(q)) return await _score(q);
    } catch (_) {}
    return null;
  }

  // ── Calculator ─────────────────────────────────────────────────────────
  // Finds a calculation anywhere in the message ("ok et fais-moi 456+45"),
  // not only when the whole message is the calculation.

  // One calculation: numbers, + - * / ^ and parentheses.
  static final _exprRe = RegExp(r'\(*-?\d+(?:\.\d+)?(?:\s*[-+*/^]\s*\(*\s*-?\d+(?:\.\d+)?\s*\)*)+');
  static final _intentRe = RegExp(
      r"calcul|combien|r[ée]sultat|compute|calculate|how much|what is|what's|wie viel|berechne|cu[áa]nto|\bfais\b|\bfait\b|\bdonne|=|\?");
  // Words that do not count as "another topic" around a calculation.
  static const _filler = {
    'ok', 'et', 'alors', 'puis', 'calcul', 'calcule', 'calculer', 'calculez', 'combien', 'font', 'fait', 'fais', 'faire',
    'moi', 'me', 'donne', 'dis', 'resultat', 'résultat', 'reponse', 'réponse', 'est', 'vaut', 'egal', 'égal', 'egale',
    'égale', 'equals', 'is', 'what', 'whats', 'how', 'much', 'compute', 'calculate', 'wie', 'viel', 'ist', 'berechne',
    'cuánto', 'cuanto', 'es', 'calcula', 'peux', 'tu', 'pouvez', 'vous', 'please', 'svp', 'stp', 'merci', 'le', 'la',
    'les', 'de', 'du', 'des', 'un', 'une', 'quel', 'quelle', 'il', 'te', 'plait', 'plaît', 'the', 'of', 'can', 'you',
    'encore', 'aussi', 'juste', 'voir',
  };

  /// Lower case, symbols and words turned into plain operators ("12 x 5", "3 fois 4", "2,5 + 1").
  static String _normalize(String q) {
    var s = q.toLowerCase();
    s = s.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-').replaceAll('–', '-');
    s = s.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m.group(1)}.${m.group(2)}');
    s = s.replaceAllMapped(RegExp(r'(\d)\s*x\s*(?=[\d(])'), (m) => '${m.group(1)}*');
    s = s.replaceAllMapped(
        RegExp(r'(\d)\s*(plus|moins|fois|times|minus|divis[ée] par|divided by|multipli[ée] par)\s*(?=[\d(])'), (m) {
      final w = m.group(2)!;
      final op = w == 'plus' ? '+' : (w == 'moins' || w == 'minus') ? '-' : (w.startsWith('divis') || w.startsWith('divided')) ? '/' : '*';
      return '${m.group(1)}$op';
    });
    return s;
  }

  /// "1 + 2" as the card shows it: spaced operators, × ÷ − signs.
  static String _pretty(String expr) => expr
      .replaceAllMapped(RegExp(r'(?<=[\d)])\s*([-+*/^])\s*'), (m) {
        final o = m.group(1)!;
        return ' ${o == '*' ? '×' : o == '/' ? '÷' : o == '-' ? '−' : o} ';
      })
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Computes one expression (already normalized). Null if it is not a calculation.
  static Map<String, dynamic>? _evalExpr(String expr) {
    final clean = expr.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty ||
        clean.length > 80 ||
        !RegExp(r'^[\d+\-*/().^]+$').hasMatch(clean) ||
        !RegExp(r'\d[+\-*/^]\(*-?\d').hasMatch(clean)) {
      return null;
    }
    try {
      final p = _P(clean);
      final v = p.expr();
      if (!p.done || v.isNaN || v.isInfinite) return null;
      return {'type': 'calc', 'expr': _pretty(expr.trim()), 'result': _fmt(v)};
    } catch (_) {
      return null;
    }
  }

  static CardResult? _calc(String q) {
    final s = _normalize(q);
    // The longest calculation of the message.
    RegExpMatch? best;
    for (final m in _exprRe.allMatches(s)) {
      if (best == null || m.end - m.start > best.end - best.start) best = m;
    }
    if (best == null) return null;
    // Not the end of a longer number ("1 000 + 5") or of a word.
    if (RegExp(r'(\d\s*|[.,]|\p{L})$', unicode: true).hasMatch(s.substring(0, best.start))) return null;
    final expr = best.group(0)!;
    final card = _evalExpr(expr);
    if (card == null) return null;

    final rest = s.replaceRange(best.start, best.end, ' ');
    final leftover = rest
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.length >= 2 && !_filler.contains(w))
        .length;
    final intent = _intentRe.hasMatch(s);
    final compact = expr.replaceAll(RegExp(r'\s+'), '');
    final dateLike = RegExp(r'^\d{1,4}[-/]\d{1,2}[-/]\d{1,4}$|^\d{4}[-/]\d{1,2}$|^\d{1,2}[-/]\d{4}$').hasMatch(compact);
    final minusOnly = !RegExp(r'[+*/^]').hasMatch(compact) && !expr.contains(' ');
    if (dateLike && !intent) return null; // 2024-11-09, 12/05
    if (leftover > 0 && !intent && (leftover > 2 || minusOnly)) return null; // a sentence about something else

    final pretty = card['expr'] as String;
    final res = card['result'] as String;
    final only = leftover <= 1;
    final summary = only
        ? 'Exact result computed by the app: $pretty = $res. State this result; do not recompute.'
        : 'Exact result computed by the app: $pretty = $res. A calculator card with this result is already shown above '
            'your answer: do not repeat or recompute it, answer only the rest of the request.';
    return CardResult(card, summary, 'step_calc', '$pretty = $res', only: only);
  }

  // The AI can ask for the card itself with [[calc: 456+45]].
  static final _calcTag = RegExp(r'\[\[calc:\s*([^\]]*?)\s*\]\]', caseSensitive: false);

  /// Calculator cards asked by the AI in its answer (at most 3, no duplicates).
  static List<Map<String, dynamic>> calcTags(String raw) {
    final out = <Map<String, dynamic>>[];
    for (final m in _calcTag.allMatches(raw)) {
      final c = _evalExpr(_normalize(m.group(1) ?? ''));
      if (c != null && !out.any((o) => o['expr'] == c['expr'])) out.add(c);
      if (out.length == 3) break;
    }
    return out;
  }

  /// Removes the calc tags from the text shown, also while one is still being written.
  static String hideCalcTags(String s) {
    var out = s.replaceAll(_calcTag, '');
    final open = out.lastIndexOf('[[');
    if (open != -1) {
      final tail = out.substring(open).toLowerCase();
      if (!tail.contains(']]') && ('[[calc:'.startsWith(tail) || tail.startsWith('[[calc:'))) out = out.substring(0, open);
    }
    return out.trimRight();
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    var t = v.toStringAsPrecision(12);
    if (t.contains('e')) return t;
    t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    return t;
  }

  // ── Weather ────────────────────────────────────────────────────────────
  static String? _cityFrom(String q) {
    final clean = q.replaceAll(RegExp(r'[?!.,]'), ' ');
    final m = RegExp(r"(?:^|\s)(?:à|a|in|en|pour|for|de|im|para)\s+([\p{L}][\p{L}'\-]*(?:\s+[\p{L}][\p{L}'\-]*){0,2})", unicode: true, caseSensitive: false).firstMatch(clean);
    var c = m?.group(1)?.trim();
    if (c == null) return null;
    c = c.replaceAll(RegExp(r"\s+(aujourd'hui|demain|ce soir|maintenant|ce week-end|today|tomorrow|tonight|now|heute|morgen|hoy|ma[ñn]ana)\b.*$", caseSensitive: false), '').trim();
    return c.length < 2 ? null : c;
  }

  static Future<CardResult?> _weather(String q) async {
    var place = _cityFrom(q);
    if (place == null && locationEnabledNotifier.value) place = LocationService.instance.city;
    if (place == null || place.isEmpty) return null;
    final lang = localeNotifier.value;
    final g = await http
        .get(Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(place)}&count=1&language=$lang'))
        .timeout(const Duration(seconds: 8));
    final gr = (jsonDecode(g.body)['results'] as List?)?.firstOrNull as Map?;
    if (gr == null) return null;
    final name = '${gr['name']}${gr['country'] != null ? ', ${gr['country']}' : ''}';
    final f = await http
        .get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${gr['latitude']}&longitude=${gr['longitude']}'
            '&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day'
            '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=5'))
        .timeout(const Duration(seconds: 8));
    final j = jsonDecode(f.body) as Map<String, dynamic>;
    final cur = j['current'] as Map<String, dynamic>;
    final d = j['daily'] as Map<String, dynamic>;
    final days = <Map<String, dynamic>>[
      for (var i = 0; i < (d['time'] as List).length; i++)
        {
          'd': d['time'][i],
          'code': d['weather_code'][i],
          'max': (d['temperature_2m_max'][i] as num).round(),
          'min': (d['temperature_2m_min'][i] as num).round(),
          'rain': d['precipitation_probability_max'][i] ?? 0,
        }
    ];
    final card = {
      'type': 'weather',
      'place': name,
      'temp': (cur['temperature_2m'] as num).round(),
      'feels': (cur['apparent_temperature'] as num).round(),
      'code': cur['weather_code'],
      'day': cur['is_day'] == 1,
      'wind': (cur['wind_speed_10m'] as num).round(),
      'hum': cur['relative_humidity_2m'],
      'days': days,
    };
    final sum = StringBuffer('Exact weather data for $name (Open-Meteo): now ${card['temp']}°C (feels ${card['feels']}°C), '
        'WMO code ${card['code']}, wind ${card['wind']} km/h, humidity ${card['hum']}%. Next days: ');
    sum.write(days.map((e) => '${e['d']} ${e['min']}-${e['max']}°C rain ${e['rain']}%').join('; '));
    sum.write('. A weather card with all numbers is already shown above your answer: reply in 1-3 short sentences (advice, clothing, umbrella), do not list the numbers again.');
    return CardResult(card, sum.toString(), 'step_weather', name);
  }

  // ── Scores (ESPN public scoreboard) ───────────────────────────────────
  static const _leagues = [
    ['soccer/fra.1', 'Ligue 1'],
    ['soccer/eng.1', 'Premier League'],
    ['soccer/esp.1', 'LaLiga'],
    ['soccer/ita.1', 'Serie A'],
    ['soccer/ger.1', 'Bundesliga'],
    ['soccer/uefa.champions', 'Champions League'],
    ['soccer/uefa.europa', 'Europa League'],
    ['basketball/nba', 'NBA'],
    ['football/nfl', 'NFL'],
    ['hockey/nhl', 'NHL'],
    ['baseball/mlb', 'MLB'],
  ];
  static const _stop = {
    'score', 'resultat', 'resultats', 'match', 'matchs', 'gagne', 'won', 'resultado', 'ergebnis', 'spiel', 'les', 'des', 'the',
    'quel', 'quelle', 'est', 'fait', 'hier', 'aujourd', 'hui', 'ce', 'soir', 'last', 'night', 'today', 'dernier', 'derniere',
    'contre', 'versus', 'vs', 'live', 'direct', 'sur', 'pour', 'entre', 'dans', 'une', 'avec', 'about', 'what', 'did', 'how',
  };

  static String _norm(String s) {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyyo';
    final b = StringBuffer();
    for (final c in s.toLowerCase().split('')) {
      final i = from.indexOf(c);
      b.write(i >= 0 ? to[i] : c);
    }
    return b.toString();
  }

  static String _date(DateTime d) => '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  static Future<List<Map<String, dynamic>>> _fetchDay(List<String> tokens, DateTime day) async {
    final out = <Map<String, dynamic>>[];
    await Future.wait([
      for (final l in _leagues)
        () async {
          try {
            final r = await http
                .get(Uri.parse('https://site.api.espn.com/apis/site/v2/sports/${l[0]}/scoreboard?dates=${_date(day)}'))
                .timeout(const Duration(seconds: 7));
            final events = (jsonDecode(r.body)['events'] as List?) ?? [];
            for (final e in events) {
              final comp = (e['competitions'] as List).first as Map;
              final teams = comp['competitors'] as List;
              final names = teams.map((t) => _norm('${t['team']['displayName']} ${t['team']['shortDisplayName']} ${t['team']['location']}')).join(' ');
              final abbr = teams.map((t) => _norm('${t['team']['abbreviation']}')).toList();
              if (!tokens.any((t) => names.contains(t) || abbr.contains(t))) continue;
              Map<String, dynamic> side(String ha) {
                final t = teams.firstWhere((x) => x['homeAway'] == ha);
                return {'name': t['team']['displayName'], 'logo': t['team']['logo'], 'score': int.tryParse('${t['score']}') ?? 0};
              }
              final st = e['status'] as Map;
              out.add({
                'league': l[1],
                'home': side('home'),
                'away': side('away'),
                'state': st['type']['state'],
                'detail': st['type']['shortDetail'],
                'clock': st['displayClock'],
                'date': e['date'],
              });
            }
          } catch (_) {}
        }(),
    ]);
    return out;
  }

  static Future<CardResult?> _score(String q) async {
    final tokens = _norm(q)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= 3 && !_stop.contains(t))
        .toList();
    if (tokens.isEmpty) return null;
    final now = DateTime.now();
    var matches = await _fetchDay(tokens, now);
    if (matches.isEmpty) matches = await _fetchDay(tokens, now.subtract(const Duration(days: 1)));
    if (matches.isEmpty) return null;
    matches = matches.take(3).toList();
    final sum = StringBuffer('Exact scores (ESPN): ');
    for (final m in matches) {
      sum.write('${m['home']['name']} ${m['home']['score']} - ${m['away']['score']} ${m['away']['name']} (${m['league']}, ${m['detail']}); ');
    }
    sum.write('A score card is already shown above your answer: add at most one short sentence of context, do not repeat the numbers.');
    return CardResult({'type': 'score', 'matches': matches}, sum.toString(), 'step_score',
        matches.map((m) => '${m['home']['name']} – ${m['away']['name']}').join(', '));
  }
}

// Recursive descent parser for + - * / ^ and parentheses.
class _P {
  final String s;
  int i = 0;
  _P(this.s);
  bool get done => i >= s.length;
  bool _eat(String c) {
    if (i < s.length && s[i] == c) {
      i++;
      return true;
    }
    return false;
  }

  double expr() {
    var v = term();
    while (true) {
      if (_eat('+')) {
        v += term();
      } else if (_eat('-')) {
        v -= term();
      } else {
        return v;
      }
    }
  }

  double term() {
    var v = power();
    while (true) {
      if (_eat('*')) {
        v *= power();
      } else if (_eat('/')) {
        v /= power();
      } else {
        return v;
      }
    }
  }

  double power() {
    final b = unary();
    if (_eat('^')) return math.pow(b, power()).toDouble();
    return b;
  }

  double unary() {
    if (_eat('-')) return -unary();
    if (_eat('+')) return unary();
    if (_eat('(')) {
      final v = expr();
      _eat(')');
      return v;
    }
    final m = RegExp(r'\d+(\.\d+)?').matchAsPrefix(s, i);
    if (m == null) throw const FormatException('number');
    i = m.end;
    return double.parse(m.group(0)!);
  }
}
