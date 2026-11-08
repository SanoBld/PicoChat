// lib/services/attachments.dart
// Pick / drop / paste files. Text, code, pdf, docx, xlsx, pptx, odt, ods are read as text; images go to vision models.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class Attachment {
  final String name;
  final String text;
  final String? imagePath; // set for images: the file the vision model reads
  const Attachment(this.name, this.text, {this.imagePath});
  bool get isImage => imagePath != null;
}

class Attachments {
  static const _text = [
    'txt', 'md', 'csv', 'tsv', 'json', 'xml', 'html', 'htm', 'yaml', 'yml', 'toml', 'log', 'ini', 'cfg', 'conf',
    'env', 'sh', 'bat', 'ps1', 'dart', 'py', 'js', 'jsx', 'ts', 'tsx', 'java', 'kt', 'swift', 'c', 'cpp', 'cc',
    'h', 'hpp', 'cs', 'go', 'rs', 'rb', 'php', 'lua', 'r', 'sql', 'css', 'scss', 'vue', 'svelte', 'gradle',
    'tex', 'rtf', 'srt', 'gitignore',
  ];
  static const _zip = ['docx', 'xlsx', 'pptx', 'odt', 'ods', 'odp'];
  static const _img = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'];
  static final all = [..._text, ..._zip, 'pdf', ..._img];

  static Future<List<Attachment>> pick() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: all,
      withData: true,
    );
    if (res == null) return [];
    return [
      for (final f in res.files)
        if (f.bytes != null && fromBytes(f.name, f.bytes!) != null) fromBytes(f.name, f.bytes!)!,
    ];
  }

  /// Reads one file. Returns null when the format is not supported.
  static Attachment? fromBytes(String name, Uint8List bytes) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? name.toLowerCase() : name.substring(dot + 1).toLowerCase();
    try {
      if (_img.contains(ext)) {
        if (kIsWeb) return null;
        // Save a copy in the temp folder: the engine reads images from a path.
        final f = File('${Directory.systemTemp.path}${Platform.pathSeparator}pc_${DateTime.now().microsecondsSinceEpoch}.$ext');
        f.writeAsBytesSync(bytes);
        return Attachment(name, '', imagePath: f.path);
      }
      if (ext == 'pdf') {
        final doc = PdfDocument(inputBytes: bytes);
        final t = PdfTextExtractor(doc).extractText();
        doc.dispose();
        // A scanned PDF has no text layer: nothing to read.
        return t.trim().isEmpty ? null : Attachment(name, t);
      }
      if (_zip.contains(ext)) {
        final t = _readZip(ext, bytes);
        return t.trim().isEmpty ? null : Attachment(name, t);
      }
      if (_text.contains(ext) || dot < 0) return Attachment(name, utf8.decode(bytes, allowMalformed: true));
    } catch (_) {}
    return null;
  }

  static String _str(ArchiveFile f) => utf8.decode(f.content as List<int>, allowMalformed: true);

  static String _unxml(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  static int _num(String n) => int.tryParse(RegExp(r'\d+').firstMatch(n)?.group(0) ?? '') ?? 0;

  static String _readZip(String ext, Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? file(String path) {
      for (final f in zip.files) {
        if (f.name == path) return f;
      }
      return null;
    }

    switch (ext) {
      case 'docx':
        final d = file('word/document.xml');
        if (d == null) return '';
        return _unxml(_str(d)
            .replaceAll(RegExp(r'</w:p>'), '\n')
            .replaceAll(RegExp(r'<w:tab/>'), '\t')
            .replaceAll(RegExp(r'<[^>]+>'), ''));
      case 'pptx':
        final slides = zip.files.where((f) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name)).toList()
          ..sort((a, b) => _num(a.name).compareTo(_num(b.name)));
        final out = StringBuffer();
        for (final (i, f) in slides.indexed) {
          out.writeln('# Slide ${i + 1}');
          for (final m in RegExp(r'<a:t>([\s\S]*?)</a:t>').allMatches(_str(f))) {
            out.writeln(_unxml(m.group(1)!));
          }
        }
        return out.toString();
      case 'odt':
      case 'ods':
      case 'odp':
        final c = file('content.xml');
        if (c == null) return '';
        return _unxml(_str(c)
            .replaceAll(RegExp(r'</text:p>|</table:table-row>'), '\n')
            .replaceAll(RegExp(r'</table:table-cell>'), '\t')
            .replaceAll(RegExp(r'<[^>]+>'), ''));
      case 'xlsx':
        return _readXlsx(zip, file);
    }
    return '';
  }

  static String _colName(String ref) => RegExp(r'[A-Z]+').firstMatch(ref)?.group(0) ?? '';
  static int _colIndex(String col) {
    var n = 0;
    for (final c in col.codeUnits) {
      n = n * 26 + (c - 64);
    }
    return n;
  }

  static String _readXlsx(Archive zip, ArchiveFile? Function(String) file) {
    final shared = <String>[];
    final ss = file('xl/sharedStrings.xml');
    if (ss != null) {
      for (final si in RegExp(r'<si>([\s\S]*?)</si>').allMatches(_str(ss))) {
        final t = RegExp(r'<t[^>]*>([\s\S]*?)</t>').allMatches(si.group(1)!).map((m) => m.group(1)!).join();
        shared.add(_unxml(t));
      }
    }
    final names = <String, String>{};
    final wb = file('xl/workbook.xml');
    if (wb != null) {
      var i = 1;
      for (final m in RegExp(r'<sheet [^>]*name="([^"]*)"').allMatches(_str(wb))) {
        names['xl/worksheets/sheet$i.xml'] = _unxml(m.group(1)!);
        i++;
      }
    }
    final sheets = zip.files.where((f) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name)).toList()
      ..sort((a, b) => _num(a.name).compareTo(_num(b.name)));
    final out = StringBuffer();
    for (final sh in sheets) {
      out.writeln('# Sheet: ${names[sh.name] ?? sh.name}');
      for (final row in RegExp(r'<row[^>]*>([\s\S]*?)</row>').allMatches(_str(sh))) {
        final cells = <String>[];
        for (final c in RegExp(r'<c ([^>]*?)(?:/>|>([\s\S]*?)</c>)').allMatches(row.group(1)!)) {
          final attrs = c.group(1)!;
          final body = c.group(2) ?? '';
          final ref = RegExp(r'r="([A-Z]+\d+)"').firstMatch(attrs)?.group(1) ?? '';
          final type = RegExp(r't="(\w+)"').firstMatch(attrs)?.group(1);
          final v = RegExp(r'<v>([\s\S]*?)</v>').firstMatch(body)?.group(1);
          final f = RegExp(r'<f[^>]*>([\s\S]*?)</f>').firstMatch(body)?.group(1);
          var val = '';
          if (type == 's' && v != null) {
            final k = int.tryParse(v) ?? 0;
            val = k < shared.length ? shared[k] : '';
          } else if (type == 'inlineStr') {
            val = _unxml(RegExp(r'<t[^>]*>([\s\S]*?)</t>').firstMatch(body)?.group(1) ?? '');
          } else {
            val = _unxml(v ?? '');
          }
          if (f != null) val = '$val (=${_unxml(f)})';
          final idx = ref.isEmpty ? cells.length + 1 : _colIndex(_colName(ref));
          while (cells.length < idx - 1) {
            cells.add('');
          }
          cells.add(val.replaceAll('\t', ' ').replaceAll('\n', ' '));
        }
        out.writeln(cells.join('\t'));
      }
    }
    return out.toString();
  }
}
