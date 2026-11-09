// lib/services/web_search.dart
// Web search through the engine chosen in the settings (DuckDuckGo, Bing,
// Google, Mojeek). Falls back to DuckDuckGo when the chosen one returns nothing.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_state.dart';

class WebResult {
  final String title, snippet, url;
  const WebResult(this.title, this.snippet, this.url);
  String get domain => Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
}

class WebSearch {
  static const engines = {
    'duckduckgo': 'DuckDuckGo',
    'bing': 'Bing',
    'google': 'Google',
    'mojeek': 'Mojeek',
  };

  static String _clean(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .trim();

  static const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  // [max] = 0 means no limit (every result found on the page).
  static Future<List<WebResult>> run(String query, {int max = 8}) async {
    final chosen = searchEngineNotifier.value;
    var out = await _one(chosen, query);
    if (out.isEmpty && chosen != 'duckduckgo') out = await _one('duckduckgo', query);
    if (max > 0 && out.length > max) out = out.sublist(0, max);
    return out;
  }

  static Future<List<WebResult>> _one(String engine, String q) async {
    try {
      final lang = localeNotifier.value;
      switch (engine) {
        case 'bing':
          return _bing(await _get('https://www.bing.com/search?q=${Uri.encodeQueryComponent(q)}&setlang=$lang'));
        case 'google':
          return _google(await _get('https://www.google.com/search?q=${Uri.encodeQueryComponent(q)}&hl=$lang&num=10',
              ua: 'Lynx/2.8.9rel.1 libwww-FM/2.14'));
        case 'mojeek':
          return _mojeek(await _get('https://www.mojeek.com/search?q=${Uri.encodeQueryComponent(q)}'));
        default:
          final r = await http
              .post(Uri.parse('https://html.duckduckgo.com/html/'), headers: {'User-Agent': _ua}, body: {'q': q})
              .timeout(const Duration(seconds: 12));
          return r.statusCode == 200 ? _ddg(r.body) : [];
      }
    } catch (_) {
      return [];
    }
  }

  static Future<String> _get(String url, {String ua = _ua}) async {
    final r = await http.get(Uri.parse(url), headers: {'User-Agent': ua, 'Accept-Language': localeNotifier.value}).timeout(const Duration(seconds: 12));
    return r.statusCode == 200 ? r.body : '';
  }

  static List<WebResult> _ddg(String body) {
    final re = RegExp(
      r'class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</a>',
      dotAll: true,
    );
    final out = <WebResult>[];
    for (final m in re.allMatches(body)) {
      var url = m.group(1)!;
      if (url.startsWith('//')) url = 'https:$url';
      final real = Uri.tryParse(url)?.queryParameters['uddg'];
      if (real != null) url = real;
      out.add(WebResult(_clean(m.group(2)!), _clean(m.group(3)!), url));
    }
    return out;
  }

  static List<WebResult> _bing(String body) {
    final re = RegExp(r'<li class="b_algo"[^>]*>.*?<h2[^>]*><a[^>]*href="([^"]+)"[^>]*>(.*?)</a>.*?(?:<p[^>]*>(.*?)</p>)?\s*</li>', dotAll: true);
    final out = <WebResult>[];
    for (final m in re.allMatches(body)) {
      var url = m.group(1)!.replaceAll('&amp;', '&');
      final u = Uri.tryParse(url)?.queryParameters['u'];
      if (u != null && u.startsWith('a1')) {
        try {
          var b = u.substring(2).replaceAll('-', '+').replaceAll('_', '/');
          while (b.length % 4 != 0) {
            b += '=';
          }
          url = utf8.decode(base64.decode(b));
        } catch (_) {}
      }
      if (!url.startsWith('http')) continue;
      out.add(WebResult(_clean(m.group(2)!), _clean(m.group(3) ?? ''), url));
    }
    return out;
  }

  static List<WebResult> _google(String body) {
    final re = RegExp(r'<a href="/url\?q=([^"&]+)[^"]*"[^>]*>(.*?)</a>', dotAll: true);
    final out = <WebResult>[];
    final seen = <String>{};
    for (final m in re.allMatches(body)) {
      final url = Uri.decodeComponent(m.group(1)!);
      final title = _clean(m.group(2)!);
      if (!url.startsWith('http') || url.contains('google.com') || title.length < 3 || !seen.add(url)) continue;
      out.add(WebResult(title, '', url));
    }
    return out.length < 2 ? [] : out;
  }

  static List<WebResult> _mojeek(String body) {
    final re = RegExp(r'<a class="title" href="([^"]+)"[^>]*>(.*?)</a>.*?<p class="s">(.*?)</p>', dotAll: true);
    return [for (final m in re.allMatches(body)) WebResult(_clean(m.group(2)!), _clean(m.group(3)!), m.group(1)!.replaceAll('&amp;', '&'))];
  }

  // Text for the AI, cut to [maxChars] so it fits the context.
  static String format(List<WebResult> list, int maxChars) {
    final b = StringBuffer();
    for (var i = 0; i < list.length; i++) {
      final e = '[${i + 1}] ${list[i].title}\n${list[i].snippet}\n${list[i].url}\n\n';
      if (b.length + e.length > maxChars) break;
      b.write(e);
    }
    return b.toString().trim();
  }

  // Preview picture of a result page (og:image). Cached; null when there is none.
  static final Map<String, Future<String?>> _thumbs = {};

  static Future<String?> thumb(String url) => _thumbs.putIfAbsent(url, () async {
        try {
          final r = await http.get(Uri.parse(url), headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 6));
          final body = utf8.decode(r.bodyBytes.take(200000).toList(), allowMalformed: true);
          final m = RegExp(r'<meta[^>]+(?:property|name)=["\x27](?:og:image|twitter:image)(?::secure_url)?["\x27][^>]*?content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(body) ??
              RegExp(r'<meta[^>]+content=["\x27]([^"\x27]+)["\x27][^>]*?(?:property|name)=["\x27](?:og:image|twitter:image)["\x27]', caseSensitive: false).firstMatch(body);
          final raw = m?.group(1)?.replaceAll('&amp;', '&');
          if (raw == null) return null;
          final abs = Uri.parse(url).resolve(raw).toString();
          return abs.startsWith('http') ? abs : null;
        } catch (_) {
          return null;
        }
      });
}
