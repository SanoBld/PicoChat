// lib/services/file_output.dart
// Files written by the AI: ```file:name.ext ... ``` blocks.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'file_convert.dart';

class GeneratedFile {
  final String name;
  final String content;
  const GeneratedFile(this.name, this.content);
}

class FileOutput {
  static final _re = RegExp(r'```file:([^\s`]+)[ \t]*\n([\s\S]*?)```');

  static final _ask = RegExp(
      r'fichier|file|télécharg|telecharg|download|export|datei|archivo|descarg|\.(txt|csv|json|md|xlsx?|docx?|pdf|py|js|html|xml)\b|excel|tableur|spreadsheet|tabelle|hoja de c',
      caseSensitive: false);

  static String hide(String text) => text.replaceAll(_re, '').trim();

  // "make me a CV / a budget table / a report": a file even without the word "file".
  static final _make = RegExp(
      r'\b(cr[ée]+(?:e|er|ez)?|fais|faire|fait|g[ée]n[èe]re[rz]?|[ée]cris|r[ée]dige[rz]?|pr[ée]pare[rz]?|make|create|generate|write|draft|prepare|erstelle|schreibe|crea|genera|escribe)\b'
      r'[^.\n]{0,45}\b(tableau|table|cv|r[ée]sum[ée]|lettre|letter|rapport|report|planning|budget|document|facture|invoice|contrat|contract|devis|tabelle|bericht|brief|informe|carta|hoja)\b',
      caseSensitive: false);
  static final _edit = RegExp(
      r'\b(modifie|change|ajoute|corrige|mets|remplace|supprime|update|edit|modify|add|fix|replace|remove|[äa]ndere|cambia|a[ñn]ade)\b',
      caseSensitive: false);

  static bool requested(String userText, {bool prevHadFile = false}) =>
      _ask.hasMatch(userText) || _make.hasMatch(userText) || (prevHadFile && _edit.hasMatch(userText));

  /// Turns file blocks into normal code blocks (used when no file was asked for).
  static String strip(String text) =>
      text.replaceAll(RegExp(r'```file:[^\s`]+[ \t]*\n?'), '```\n');

  static List<GeneratedFile> extract(String text) => [
        for (final m in _re.allMatches(text))
          GeneratedFile(m.group(1)!.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_'), m.group(2)!),
      ];

  // Returns true when saved.
  static Future<bool> save(GeneratedFile f) async {
    final bytes = await FileConvert.build(f.name, f.content) ?? Uint8List.fromList(utf8.encode(f.content));
    final path = await FilePicker.platform.saveFile(fileName: f.name, bytes: bytes);
    if (path == null) return false;
    // Desktop: the picker only gives a path, so write the file ourselves.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await File(path).writeAsBytes(bytes);
    }
    return true;
  }
}
