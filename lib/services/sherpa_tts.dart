// lib/services/sherpa_tts.dart
// Natural voice (Piper neural voices) running on the device, in a separate isolate.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sh;

import 'sherpa_models.dart';

class _Init {
  final SendPort out;
  final String model, tokens, data;
  _Init(this.out, this.model, this.tokens, this.data);
}

void _main(_Init i) {
  sh.initBindings();
  final tts = sh.OfflineTts(sh.OfflineTtsConfig(
    model: sh.OfflineTtsModelConfig(
      vits: sh.OfflineTtsVitsModelConfig(model: i.model, tokens: i.tokens, dataDir: i.data, lengthScale: 1.0),
      numThreads: 2,
      debug: false,
    ),
  ));
  final rc = ReceivePort();
  i.out.send(rc.sendPort);
  rc.listen((m) {
    final msg = m as List;
    try {
      final a = tts.generate(text: msg[1] as String, sid: 0, speed: 1.0);
      i.out.send([msg[0], a.samples, a.sampleRate]);
    } catch (_) {
      i.out.send([msg[0], Float32List(0), 22050]); // a bad sentence is skipped, the worker stays alive
    }
  });
}

class SherpaTts {
  SherpaTts._();
  static final SherpaTts instance = SherpaTts._();

  Isolate? _iso;
  SendPort? _tx;
  String _lang = '';
  int _n = 0;
  final Map<int, Completer<File?>> _wait = {};
  final AudioPlayer _player = AudioPlayer();
  Completer<void>? _playing;
  bool _stopped = false;

  Future<bool> open(String lang) async {
    if (_tx != null && _lang == lang) return true;
    close();
    if (!await SherpaModels.hasVoice(lang)) return false;
    final d = await SherpaModels.dir(SherpaModels.voiceName(lang));
    final rp = ReceivePort();
    final ready = Completer<SendPort>();
    rp.listen((m) async {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m is List) {
        final w = _wait.remove(m[0] as int);
        final smp = m[1] as Float32List;
        w?.complete(smp.isEmpty ? null : await _wav(smp, m[2] as int));
      }
    });
    _iso = await Isolate.spawn(
        _main, _Init(rp.sendPort, await SherpaModels.find(d, '.onnx'), '$d/tokens.txt', '$d/espeak-ng-data'));
    _tx = await ready.future.timeout(const Duration(seconds: 30));
    _lang = lang;
    return true;
  }

  Future<File> _wav(Float32List s, int rate) async {
    final pcm = ByteData(s.length * 2);
    for (var k = 0; k < s.length; k++) {
      pcm.setInt16(k * 2, (s[k].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    final h = ByteData(44);
    void str(int o, String t) {
      for (var k = 0; k < 4; k++) {
        h.setUint8(o + k, t.codeUnitAt(k));
      }
    }

    str(0, 'RIFF');
    h.setUint32(4, 36 + pcm.lengthInBytes, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);
    h.setUint16(22, 1, Endian.little);
    h.setUint32(24, rate, Endian.little);
    h.setUint32(28, rate * 2, Endian.little);
    h.setUint16(32, 2, Endian.little);
    h.setUint16(34, 16, Endian.little);
    str(36, 'data');
    h.setUint32(40, pcm.lengthInBytes, Endian.little);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/pico_tts_${_n++}.wav');
    await f.writeAsBytes([...h.buffer.asUint8List(), ...pcm.buffer.asUint8List()], flush: true);
    return f;
  }

  Future<File?> _make(String text) {
    final id = _n++;
    final c = Completer<File?>();
    _wait[id] = c;
    _tx?.send([id, text]);
    // A worker that never answers is restarted at the next call, not replaced by the system voice.
    return c.future.timeout(const Duration(seconds: 25), onTimeout: () {
      _wait.remove(id);
      close();
      return null;
    });
  }

  /// Says the sentences one after the other. The next one is made while the current one plays.
  /// [alive] tells when to stop (for example when another message starts).
  Future<void> speakAll(List<String> parts, bool Function() alive) async {
    _stopped = false;
    Future<File?>? next = parts.isEmpty ? null : _make(parts.first);
    for (var k = 0; k < parts.length; k++) {
      final f = await next;
      next = k + 1 < parts.length ? _make(parts[k + 1]) : null;
      if (_stopped || !alive()) break;
      if (f == null) continue; // skip this sentence
      _playing = Completer<void>();
      late StreamSubscription<void> sub;
      sub = _player.onPlayerComplete.listen((_) {
        _playing?.complete();
        sub.cancel();
      });
      await _player.play(DeviceFileSource(f.path));
      await _playing!.future;
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    _stopped = true;
    try {
      await _player.stop();
    } catch (_) {}
    if (_playing?.isCompleted == false) _playing!.complete();
  }

  void close() {
    _iso?.kill(priority: Isolate.immediate);
    _iso = null;
    _tx = null;
    _lang = '';
  }
}
