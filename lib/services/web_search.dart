// lib/services/web_search.dart
// Simple web search (DuckDuckGo HTML).
import 'package:http/http.dart' as http;

class WebResult {
  final String title, snippet, url;
  const WebResult(this.title, this.snippet, this.url);
  String get domain => Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
}

class WebSearch {
  static String _clean(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();

  // [max] = 0 means no limit (every result found on the page).
  static Future<List<WebResult>> run(String query, {int max = 8}) async {
    try {
      final r = await http
          .post(
            Uri.parse('https://html.duckduckgo.com/html/'),
            headers: {'User-Agent': 'Mozilla/5.0'},
            body: {'q': query},
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return [];
      final re = RegExp(
        r'class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</a>',
        dotAll: true,
      );
      final out = <WebResult>[];
      for (final m in re.allMatches(r.body)) {
        var url = m.group(1)!;
        if (url.startsWith('//')) url = 'https:$url';
        final real = Uri.tryParse(url)?.queryParameters['uddg'];
        if (real != null) url = real;
        out.add(WebResult(_clean(m.group(2)!), _clean(m.group(3)!), url));
        if (max > 0 && out.length >= max) break;
      }
      return out;
    } catch (_) {
      return [];
    }
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
}
