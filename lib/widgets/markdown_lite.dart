// lib/widgets/markdown_lite.dart
//
// Minimal markdown renderer for short texts (release notes, news items).
// Supports: **bold**, *italic*/_italic_, `code`, "- " / "* " bullet lists,
// "# " / "## " headers, and auto-linked URLs. No external package needed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../app_state.dart';
import '../l10n/l10n.dart';
import '../services/image_lookup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pc_motion.dart';

class MarkdownLite extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color linkColor;

  const MarkdownLite({
    super.key,
    required this.text,
    required this.style,
    required this.linkColor,
  });

  static final RegExp _urlRegex =
      RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
  // Inline tokens, order matters (checked left to right per match position).
  static final RegExp _boldItalicRegex = RegExp(r'\*\*\*(.+?)\*\*\*');
  static final RegExp _strikeRegex = RegExp(r'~~(.+?)~~');
  static final RegExp _boldRegex   = RegExp(r'\*\*(.+?)\*\*');
  static final RegExp _italicRegex = RegExp(r'(?<!\*)\*(?!\*)(.+?)\*(?!\*)|_(.+?)_');
  static final RegExp _codeRegex   = RegExp(r'`([^`]+)`');
  static final RegExp _linkRegex   = RegExp(r'\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)');

  Future<void> _openUrl(String rawUrl) async {
    final cleaned = rawUrl.replaceAll(RegExp(r'[)\].,;!?]+$'), '');
    final uri = Uri.tryParse(cleaned);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Parses one line into inline spans (bold / italic / strike / code / links).
  // [nested]: inside bold/italic: no base style, so the outer style is kept.
  InlineSpan _parseInline(String line, {bool nested = false}) {
    line = line.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    final tokens = <_Token>[
      ..._linkRegex.allMatches(line).map((m) => _Token(m.start, m.end, _TokType.link, '${m.group(1)}\u0000${m.group(2)}')),
      ..._urlRegex.allMatches(line).map((m) => _Token(m.start, m.end, _TokType.url, m.group(0)!)),
      ..._boldItalicRegex.allMatches(line).map((m) => _Token(m.start, m.end, _TokType.boldItalic, m.group(1)!)),
      ..._boldRegex.allMatches(line).map((m) => _Token(m.start, m.end, _TokType.bold, m.group(1)!)),
      ..._strikeRegex.allMatches(line).map((m) => _Token(m.start, m.end, _TokType.strike, m.group(1)!)),
      ..._codeRegex.allMatches(line).map((m) => _Token(m.start, m.end, _TokType.code, m.group(1)!)),
      ..._italicRegex.allMatches(line).map((m) => _Token(m.start, m.end, _TokType.italic, m.group(1) ?? m.group(2) ?? '')),
    ]..sort((a, b) {
        final c = a.start.compareTo(b.start);
        return c != 0 ? c : b.end.compareTo(a.end);
      });

    // Remove overlaps, first (longest) match wins.
    final cleaned = <_Token>[];
    int lastEnd = 0;
    for (final t in tokens) {
      if (t.start < lastEnd) continue;
      cleaned.add(t);
      lastEnd = t.end;
    }

    if (cleaned.isEmpty) return TextSpan(text: line, style: nested ? null : style);

    InlineSpan link(String label, String url, {bool raw = false}) => WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: PcGesture(
              onTap: () => _openUrl(url),
              child: Text(label,
                  style: style?.copyWith(
                    color: linkColor,
                    fontWeight: raw ? FontWeight.w600 : FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: linkColor,
                  )),
            ),
          ),
        );

    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final t in cleaned) {
      if (t.start > cursor) spans.add(TextSpan(text: line.substring(cursor, t.start)));
      switch (t.type) {
        case _TokType.url:
          spans.add(link(t.text, t.text, raw: true));
        case _TokType.link:
          final parts = t.text.split('\u0000');
          spans.add(link(parts.first, parts.last));
        case _TokType.bold:
          spans.add(TextSpan(style: const TextStyle(fontWeight: FontWeight.w800), children: [_parseInline(t.text, nested: true)]));
        case _TokType.boldItalic:
          spans.add(TextSpan(
              style: const TextStyle(fontWeight: FontWeight.w800, fontStyle: FontStyle.italic),
              children: [_parseInline(t.text, nested: true)]));
        case _TokType.italic:
          spans.add(TextSpan(style: const TextStyle(fontStyle: FontStyle.italic), children: [_parseInline(t.text, nested: true)]));
        case _TokType.strike:
          spans.add(TextSpan(style: const TextStyle(decoration: TextDecoration.lineThrough), children: [_parseInline(t.text, nested: true)]));
        case _TokType.code:
          spans.add(TextSpan(
            text: ' ${t.text} ',
            style: TextStyle(fontFamily: 'monospace', fontSize: (style?.fontSize ?? 15) - 1, backgroundColor: _codeBg, color: _codeFg),
          ));
      }
      cursor = t.end;
    }
    if (cursor < line.length) spans.add(TextSpan(text: line.substring(cursor)));
    return TextSpan(style: nested ? null : style, children: spans);
  }

  // Set by build(): colours of the theme for inline code.
  static Color? _codeBg;
  static Color? _codeFg;

  // A line is a table row if it contains at least one '|' with content
  // around it (GitHub-flavored markdown style: "| a | b |").
  static bool _isTableRow(String line) =>
      line.trim().startsWith('|') || (line.contains('|') && line.trim().isNotEmpty);

  // A separator row looks like "|---|---|" or "|:--|--:|".
  static bool _isTableSeparator(String line) =>
      RegExp(r'^\s*\|?[\s:\-|]+\|?\s*$').hasMatch(line) && line.contains('-');

  static List<String> _splitRow(String line) {
    var l = line.trim();
    if (l.startsWith('|')) l = l.substring(1);
    if (l.endsWith('|')) l = l.substring(0, l.length - 1);
    return l.split('|').map((c) => c.trim()).toList();
  }

  Widget _buildTable(BuildContext context, List<String> header, List<List<String>> rows) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.5);
    final cellStyle = style?.copyWith(fontSize: (style?.fontSize ?? 13) - 1);

    Widget cell(String text, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text.rich(_parseInline(text),
              style: cellStyle?.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 0),
          child: Table(
            border: TableBorder.all(color: borderColor, width: 1, borderRadius: BorderRadius.circular(6)),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            children: [
              TableRow(
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
                children: header.map((h) => cell(h, bold: true)).toList(),
              ),
              for (final r in rows)
                TableRow(children: [
                  for (var i = 0; i < header.length; i++) cell(i < r.length ? r[i] : ''),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  static final RegExp _imgInline = RegExp(r'!\[([^\]]*)\]\((\S+?)(?:\s+"[^"]*")?\)');
  static final RegExp _imgUrl = RegExp(r'^https?://\S+\.(?:png|jpe?g|gif|webp|avif|bmp)(?:\?\S*)?$', caseSensitive: false);
  static final RegExp _wikiTag = RegExp(r'^\[\[image:\s*(.+?)\s*\]\]$', caseSensitive: false);
  static final RegExp _hrRe = RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$');
  static final RegExp _listRe = RegExp(r'^(\s*)([-*+•–])\s+(.*)$');
  static final RegExp _numRe = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$');
  static final RegExp _headRe = RegExp(r'^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$');

  static int _level(String indent) {
    final n = indent.replaceAll('\t', '    ').length;
    return n <= 1 ? 0 : (n <= 4 ? 1 : (n <= 7 ? 2 : 3));
  }

  // Coloured bullet: dot / ring / square, in the theme colours; task lists get a checkbox.
  Widget _bullet(ColorScheme sc, int level, String content) {
    final task = RegExp(r'^\[( |x|X)\]\s+(.*)$').firstMatch(content);
    final done = task != null && task.group(1) != ' ';
    final body = task?.group(2) ?? content;
    final color = [sc.primary, sc.secondary, sc.tertiary][level % 3];
    final h = (style?.fontSize ?? 15) * 1.45;
    Widget mark;
    if (task != null) {
      mark = Icon(done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 19, color: sc.primary);
    } else {
      mark = switch (level % 3) {
        0 => Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        1 => Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2))),
        _ => Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      };
    }
    return Padding(
      padding: EdgeInsets.only(left: 2 + level * 20.0, bottom: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 22, height: h, child: Center(child: mark)),
        Expanded(
          child: Text.rich(_parseInline(body),
              style: done ? style?.copyWith(color: sc.onSurfaceVariant, decoration: TextDecoration.lineThrough) : style),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    _codeBg = scheme.surfaceContainerHighest;
    _codeFg = scheme.tertiary;
    final lines = text.split('\n');
    final widgets = <Widget>[];
    int i = 0;

    while (i < lines.length) {
      final raw = lines[i];
      final line = raw.trimRight();
      final t = line.trim();

      // ── Fenced code block ```lang ... ``` ───────────────────────────────
      if (t.startsWith('```')) {
        final lang = t.substring(3).trim();
        final buf = <String>[];
        var j = i + 1;
        while (j < lines.length && !lines[j].trimLeft().startsWith('```')) {
          buf.add(lines[j]);
          j++;
        }
        widgets.add(_CodeBlock(lang: lang, code: buf.join('\n')));
        i = j + 1;
        continue;
      }

      // ── Images: [[image: subject]], bare image URL, ![alt](url) ─────────
      final wiki = _wikiTag.firstMatch(t);
      if (wiki != null) {
        widgets.add(_WikiImage(query: wiki.group(1)!));
        i++;
        continue;
      }
      if (_imgUrl.hasMatch(t)) {
        widgets.add(_MarkdownImage(url: t, alt: ''));
        i++;
        continue;
      }
      if (_imgInline.hasMatch(line)) {
        var cursor = 0;
        for (final m in _imgInline.allMatches(line)) {
          final before = line.substring(cursor, m.start).trim();
          if (before.isNotEmpty) widgets.add(Text.rich(_parseInline(before), style: style));
          widgets.add(_MarkdownImage(url: m.group(2)!, alt: m.group(1) ?? ''));
          cursor = m.end;
        }
        final after = line.substring(cursor).trim();
        if (after.isNotEmpty) widgets.add(Text.rich(_parseInline(after), style: style));
        i++;
        continue;
      }

      // ── Table block: header row + separator row + data rows ────────────
      if (i + 1 < lines.length && _isTableRow(line) && _isTableSeparator(lines[i + 1])) {
        final header = _splitRow(line);
        var j = i + 2;
        final rows = <List<String>>[];
        while (j < lines.length && _isTableRow(lines[j]) && lines[j].trim().isNotEmpty) {
          rows.add(_splitRow(lines[j]));
          j++;
        }
        widgets.add(_buildTable(context, header, rows));
        i = j;
        continue;
      }

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        i++;
        continue;
      }

      // Horizontal rule (before lists: "- - -" and "***")
      if (_hrRe.hasMatch(line)) {
        widgets.add(Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: scheme.outlineVariant)));
        i++;
        continue;
      }

      // Headings # … ######
      final hm = _headRe.firstMatch(line);
      if (hm != null) {
        final level = hm.group(1)!.length;
        final base = style?.fontSize ?? 15;
        final size = base + const [7.0, 5.0, 3.0, 1.5, 0.0, 0.0][level - 1];
        widgets.add(Padding(
          padding: EdgeInsets.only(top: level <= 2 ? 12 : 8, bottom: 3),
          child: Text.rich(_parseInline(hm.group(2)!),
              style: style?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: size,
                height: 1.25,
                color: level <= 2 ? null : (level <= 4 ? scheme.primary : scheme.onSurfaceVariant),
              )),
        ));
        i++;
        continue;
      }

      // Block quote: consecutive "> " lines form one block
      if (t.startsWith('>')) {
        final q = <String>[];
        var j = i;
        while (j < lines.length && lines[j].trim().startsWith('>')) {
          q.add(lines[j].trim().replaceFirst(RegExp(r'^>+\s?'), ''));
          j++;
        }
        widgets.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: scheme.primary, width: 4)),
          ),
          child: Text.rich(_parseInline(q.join('\n')), style: style),
        ));
        i = j;
        continue;
      }

      // Numbered lists (with indent levels)
      final nm = _numRe.firstMatch(line);
      if (nm != null) {
        final lvl = _level(nm.group(1)!);
        widgets.add(Padding(
          padding: EdgeInsets.only(left: 2 + lvl * 20.0, bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 10, top: 1),
              alignment: Alignment.center,
              decoration: ShapeDecoration(color: lvl == 0 ? scheme.primaryContainer : scheme.secondaryContainer, shape: const StadiumBorder()),
              child: Text(nm.group(2)!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: lvl == 0 ? scheme.onPrimaryContainer : scheme.onSecondaryContainer)),
            ),
            Expanded(child: Text.rich(_parseInline(nm.group(3)!), style: style)),
          ]),
        ));
        i++;
        continue;
      }

      // Bullet lists (- * + •), nested, task lists
      final lm = _listRe.firstMatch(line);
      if (lm != null) {
        widgets.add(_bullet(scheme, _level(lm.group(1)!), lm.group(3)!));
        i++;
        continue;
      }

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text.rich(_parseInline(line), style: style),
      ));
      i++;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}

enum _TokType { url, link, bold, boldItalic, italic, strike, code }

class _Token {
  final int start, end;
  final _TokType type;
  final String text;
  _Token(this.start, this.end, this.type, this.text);
}

// Picture in an answer: rounded, fades in, tap = full screen with pinch to zoom.
class _MarkdownImage extends StatefulWidget {
  final String url;
  final String alt;
  const _MarkdownImage({required this.url, required this.alt});

  @override
  State<_MarkdownImage> createState() => _MarkdownImageState();
}

class _MarkdownImageState extends State<_MarkdownImage> {
  final Object _tag = Object();

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    Widget box(Widget child) => Container(
          height: 230,
          width: double.infinity,
          color: sc.surfaceContainerHigh,
          alignment: Alignment.center,
          child: child,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PcGesture(
            onTap: () => Navigator.of(context).push(PageRouteBuilder<void>(
              opaque: false,
              barrierColor: Colors.black87,
              pageBuilder: (_, _, _) => _FullscreenImage(url: widget.url, tag: _tag),
              transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 220),
              reverseTransitionDuration: const Duration(milliseconds: 180),
            )),
            child: Hero(
              tag: _tag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: 230,
                  width: double.infinity,
                  child: Stack(fit: StackFit.expand, children: [
                    box(SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: sc.primary))),
                    Image.network(
                      widget.url,
                      fit: BoxFit.cover,
                      frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
                        opacity: frame == null && !sync ? 0 : 1,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        child: child,
                      ),
                      errorBuilder: (_, _, _) => box(Icon(Icons.broken_image_outlined, color: sc.onSurfaceVariant, size: 32)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          if (widget.alt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
              child: Text(widget.alt, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: sc.onSurfaceVariant)),
            ),
        ]),
      ),
    );
  }
}

// [[image: subject]]: the app looks the picture up (Wikipedia) and shows it.
class _WikiImage extends StatefulWidget {
  final String query;
  const _WikiImage({required this.query});

  @override
  State<_WikiImage> createState() => _WikiImageState();
}

class _WikiImageState extends State<_WikiImage> {
  late final Future<String?> _f = ImageLookup.find(widget.query);

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return FutureBuilder<String?>(
      future: _f,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                height: 230,
                decoration: BoxDecoration(color: sc.surfaceContainerHigh, borderRadius: BorderRadius.circular(22)),
                alignment: Alignment.center,
                child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: sc.primary)),
              ),
            ),
          );
        }
        final u = snap.data;
        return u == null ? const SizedBox.shrink() : _MarkdownImage(url: u, alt: widget.query);
      },
    );
  }
}

// Full-screen, pinch-to-zoom viewer.
class _FullscreenImage extends StatelessWidget {
  final String url;
  final Object tag;
  const _FullscreenImage({required this.url, required this.tag});

  @override
  Widget build(BuildContext context) => PcGesture(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Hero(
              tag: tag,
              child: InteractiveViewer(minScale: 1, maxScale: 5, child: Image.network(url, fit: BoxFit.contain)),
            ),
          ),
        ),
      );
}

class _CodeBlock extends StatelessWidget {
  final String lang;
  final String code;
  const _CodeBlock({required this.lang, required this.code});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shaped = materialShapesNotifier.value;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(shaped ? 24 : 8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(children: [
            Text(lang.isEmpty ? 'code' : lang,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              tooltip: tr('copy'),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.copy_rounded, size: 16, color: scheme.onSurfaceVariant),
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Text(code, style: TextStyle(fontFamily: 'SpaceMono', fontSize: 13, color: scheme.onSurface, height: 1.4)),
        ),
      ]),
    );
  }
}
