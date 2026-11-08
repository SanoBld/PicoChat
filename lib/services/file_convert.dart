// lib/services/file_convert.dart
// Turns the text written by the AI into real docx / xlsx / pdf files.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class FileConvert {
  /// Real file bytes for docx / xlsx / pdf, null for everything else (saved as text).
  static Future<Uint8List?> build(String name, String content) async {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    try {
      switch (ext) {
        case 'docx':
          return _docx(content);
        case 'xlsx':
          return _xlsx(content);
        case 'pdf':
          return await _pdf(content);
      }
    } catch (_) {}
    return null;
  }

  // ── helpers ──
  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static Uint8List _zip(Map<String, String> files) {
    final a = Archive();
    files.forEach((n, c) => a.add(ArchiveFile.bytes(n, utf8.encode(c))));
    final List<int>? out = ZipEncoder().encode(a);
    return Uint8List.fromList(out ?? const []);
  }

  static String _plain(String s) => s.replaceAll(RegExp(r'\*\*|`'), '');

  static List<List<String>> parseCsv(String src) {
    final first = src.split('\n').first;
    final sep = first.contains('\t') ? '\t' : (first.contains(';') && !first.contains(',') ? ';' : ',');
    final rows = <List<String>>[];
    var row = <String>[];
    var cell = StringBuffer();
    var q = false;
    for (var i = 0; i < src.length; i++) {
      final c = src[i];
      if (q) {
        if (c == '"') {
          if (i + 1 < src.length && src[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            q = false;
          }
        } else {
          cell.write(c);
        }
      } else if (c == '"') {
        q = true;
      } else if (c == sep) {
        row.add(cell.toString());
        cell = StringBuffer();
      } else if (c == '\n') {
        row.add(cell.toString().replaceAll('\r', ''));
        cell = StringBuffer();
        if (row.any((e) => e.isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        cell.write(c);
      }
    }
    row.add(cell.toString());
    if (row.any((e) => e.isNotEmpty)) rows.add(row);
    return rows;
  }

  // ── docx ──
  static (int, String) _line(String l) {
    final t = l.trimRight();
    if (t.startsWith('### ')) return (1, t.substring(4));
    if (t.startsWith('## ')) return (2, t.substring(3));
    if (t.startsWith('# ')) return (3, t.substring(2));
    if (RegExp(r'^\s*[-*] ').hasMatch(t)) return (0, '• ${t.replaceFirst(RegExp(r'^\s*[-*] '), '')}');
    return (0, t);
  }

  static String _runs(String text, {bool bold = false, int size = 22}) {
    final parts = text.replaceAll('`', '').split('**');
    final b = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isB = bold || i.isOdd;
      b.write('<w:r><w:rPr>${isB ? '<w:b/>' : ''}<w:sz w:val="$size"/></w:rPr>'
          '<w:t xml:space="preserve">${_esc(parts[i])}</w:t></w:r>');
    }
    return b.toString();
  }

  static Uint8List _docx(String content) {
    final body = StringBuffer();
    for (final l in content.split('\n')) {
      if (l.trim().isEmpty) {
        body.write('<w:p/>');
        continue;
      }
      final (lvl, t) = _line(l);
      final size = switch (lvl) { 3 => 40, 2 => 32, 1 => 26, _ => 22 };
      body.write('<w:p><w:pPr><w:spacing w:after="${lvl > 0 ? 120 : 60}"/></w:pPr>${_runs(t, bold: lvl > 0, size: size)}</w:p>');
    }
    return _zip({
      '[Content_Types].xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
      '_rels/.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>',
      'word/document.xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body</w:body></w:document>',
    });
  }

  // ── xlsx ──
  static String _col(int i) {
    var s = '';
    var n = i + 1;
    while (n > 0) {
      final r = (n - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  static Uint8List _xlsx(String content) {
    final rows = parseCsv(content);
    final sheet = StringBuffer();
    for (final (r, row) in rows.indexed) {
      sheet.write('<row r="${r + 1}">');
      for (final (c, v) in row.indexed) {
        final ref = '${_col(c)}${r + 1}';
        final num = RegExp(r'^-?(0|[1-9]\d*)(\.\d+)?$').hasMatch(v.trim());
        sheet.write(num
            ? '<c r="$ref"><v>${v.trim()}</v></c>'
            : '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_esc(v)}</t></is></c>');
      }
      sheet.write('</row>');
    }
    return _zip({
      '[Content_Types].xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
      '_rels/.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
      'xl/workbook.xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
      'xl/worksheets/sheet1.xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>$sheet</sheetData></worksheet>',
    });
  }

  // ── pdf ── (standard fonts: Latin-1 only, other characters are replaced)
  static String _latin(String s) {
    const map = {
      '’': "'", '‘': "'", '“': '"', '”': '"', '–': '-', '—': '-', '…': '...', '€': 'EUR', 'œ': 'oe', 'Œ': 'OE', '•': '-', '→': '->', '✓': 'v',
    };
    final b = StringBuffer();
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      if (map.containsKey(c)) {
        b.write(map[c]);
      } else if (r < 256) {
        b.write(c);
      } else {
        b.write('?');
      }
    }
    return b.toString();
  }

  static Future<Uint8List> _pdf(String content) async {
    final doc = PdfDocument();
    doc.pageSettings.margins.all = 40;
    var page = doc.pages.add();
    var y = 0.0;
    for (final l in content.split('\n')) {
      if (l.trim().isEmpty) {
        y += 8;
        continue;
      }
      final (lvl, t) = _line(l);
      final size = switch (lvl) { 3 => 20.0, 2 => 16.0, 1 => 13.0, _ => 11.0 };
      final font = PdfStandardFont(PdfFontFamily.helvetica, size, style: lvl > 0 ? PdfFontStyle.bold : PdfFontStyle.regular);
      final el = PdfTextElement(text: _latin(_plain(t)), font: font);
      final res = el.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 0),
        format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
      );
      if (res != null) {
        page = res.page;
        y = res.bounds.bottom + (lvl > 0 ? 8 : 3);
      }
    }
    final bytes = await doc.save();
    doc.dispose();
    return Uint8List.fromList(bytes);
  }
}
