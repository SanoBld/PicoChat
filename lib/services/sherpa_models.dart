// lib/services/sherpa_models.dart
// Downloads and unpacks the voice models (speech-to-text and voices).
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class SherpaModels {
  SherpaModels._();

  static const _base = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/';
  static const vadUrl = '${_base}asr-models/silero_vad.onnx';
  static const asrName = 'sherpa-onnx-whisper-tiny';
  static const _voices = {
    'fr': 'vits-piper-fr_FR-siwis-medium',
    'en': 'vits-piper-en_US-lessac-medium',
    'es': 'vits-piper-es_ES-davefx-medium',
    'de': 'vits-piper-de_DE-thorsten-medium',
  };

  /// 0..1 while downloading, null when idle.
  static final progress = ValueNotifier<double?>(null);
  static final label = ValueNotifier<String>('');

  static Future<Directory> _root() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/sherpa');
    await d.create(recursive: true);
    return d;
  }

  static String voiceName(String lang) => _voices[lang] ?? _voices['en']!;

  static Future<bool> hasAsr() async {
    final r = await _root();
    return File('${r.path}/silero_vad.onnx').existsSync() && File('${r.path}/$asrName/.ok').existsSync();
  }

  static Future<bool> hasVoice(String lang) async {
    final r = await _root();
    return File('${r.path}/${voiceName(lang)}/.ok').existsSync();
  }

  static Future<String> vadPath() async => '${(await _root()).path}/silero_vad.onnx';
  static Future<String> dir(String name) async => '${(await _root()).path}/$name';

  /// First file in a folder that ends with the given text.
  static Future<String> find(String folder, String ending) async {
    final f = Directory(folder).listSync().whereType<File>().firstWhere((x) => x.path.endsWith(ending));
    return f.path;
  }

  static Future<void> ensureAsr() async {
    final r = await _root();
    final vad = File('${r.path}/silero_vad.onnx');
    if (!vad.existsSync()) {
      label.value = 'VAD';
      await _download(vadUrl, vad.path, 0, 0.05);
    }
    await _pack('${_base}asr-models/$asrName.tar.bz2', asrName, 0.05, 1);
  }

  static Future<void> ensureVoice(String lang) async {
    final n = voiceName(lang);
    await _pack('${_base}tts-models/$n.tar.bz2', n, 0, 1);
  }

  static Future<void> _pack(String url, String name, double from, double to) async {
    final r = await _root();
    final out = Directory('${r.path}/$name');
    if (File('${out.path}/.ok').existsSync()) return;
    label.value = name;
    final tmp = '${r.path}/$name.tar.bz2';
    try {
      await _download(url, tmp, from, from + (to - from) * 0.8);
      progress.value = from + (to - from) * 0.85;
      final bytes = await File(tmp).readAsBytes();
      // Unpack in another isolate so the screen stays smooth.
      final files = await compute(_unpack, bytes);
      if (out.existsSync()) await out.delete(recursive: true);
      for (final e in files.entries) {
        // Remove the first folder of the archive.
        final parts = e.key.split('/')..removeAt(0);
        if (parts.isEmpty) continue;
        final f = File('${out.path}/${parts.join('/')}');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(e.value);
      }
      await File('${out.path}/.ok').writeAsString('1');
    } finally {
      try {
        await File(tmp).delete();
      } catch (_) {}
      progress.value = null;
    }
  }

  static Future<void> _download(String url, String path, double from, double to) async {
    final c = http.Client();
    try {
      final res = await c.send(http.Request('GET', Uri.parse(url)));
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final total = res.contentLength ?? 0;
      var got = 0;
      final sink = File(path).openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) progress.value = from + (to - from) * got / total;
      }
      await sink.close();
    } finally {
      c.close();
    }
  }
}

Map<String, List<int>> _unpack(Uint8List bytes) {
  final tar = TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
  return {for (final f in tar.files) if (f.isFile) f.name: f.content as List<int>};
}
