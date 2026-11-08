// lib/services/web_search.dart
// Simple web search (DuckDuckGo HTML). Returns a short text block, or ''.
import 'package:http/http.dart' as http;

class WebSearch {
  static String _clean(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();

  static Future<String> run(String query) async {
    try {
      final r = await http
          .post(
            Uri.parse('https://html.duckduckgo.com/html/'),
            headers: {'User-Agent': 'Mozilla/5.0'},
            body: {'q': query},
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return '';
      final re = RegExp(
        r'class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</a>',
        dotAll: true,
      );
      final out = StringBuffer();
      var n = 0;
      for (final m in re.allMatches(r.body)) {
        var url = m.group(1)!;
        if (url.startsWith('//')) url = 'https:$url';
        final real = Uri.tryParse(url)?.queryParameters['uddg'];
        if (real != null) url = real;
        n++;
        out.writeln('[$n] ${_clean(m.group(2)!)}\n${_clean(m.group(3)!)}\n$url\n');
        if (n >= 5) break;
      }
      return out.toString().trim();
    } catch (_) {
      return '';
    }
  }
}
