// lib/services/attachments.dart
// Pick text-based files and read them as text.
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class Attachment {
  final String name;
  final String text;
  const Attachment(this.name, this.text);
}

class Attachments {
  static const _ext = [
    'txt', 'md', 'csv', 'json', 'xml', 'html', 'yaml', 'yml', 'log', 'ini',
    'dart', 'py', 'js', 'ts', 'java', 'kt', 'c', 'cpp', 'h', 'cs', 'go', 'rs', 'sql', 'css',
  ];

  static Future<List<Attachment>> pick() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _ext,
      withData: true,
    );
    if (res == null) return [];
    return [
      for (final f in res.files)
        if (f.bytes != null) Attachment(f.name, utf8.decode(f.bytes!, allowMalformed: true)),
    ];
  }
}
