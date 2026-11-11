// lib/services/sherpa_stt.dart
// Fast speech-to-text: a voice detector cuts the audio into phrases and a small
// Whisper model (ONNX) reads each phrase. Everything runs in a separate isolate.
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sh;

import 'sherpa_models.dart';

class _Init {
  final SendPort out;
  final String vad, enc, dec, tok, lang;
  _Init(this.out, this.vad, this.enc, this.dec, this.tok, this.lang);
}

void _main(_Init i) {
  sh.initBindings();
  final rc = ReceivePort();
  final vad = sh.VoiceActivityDetector(
    config: sh.VadModelConfig(
      sileroVad: sh.SileroVadModelConfig(
          model: i.vad, threshold: 0.5, minSilenceDuration: 0.4, minSpeechDuration: 0.2, windowSize: 512, maxSpeechDuration: 20),
      sampleRate: 16000,
      numThreads: 1,
      debug: false,
    ),
    bufferSizeInSeconds: 30,
  );
  final rec = sh.OfflineRecognizer(sh.OfflineRecognizerConfig(
    model: sh.OfflineModelConfig(
      whisper: sh.OfflineWhisperModelConfig(encoder: i.enc, decoder: i.dec, language: i.lang, task: 'transcribe', tailPaddings: 300),
      tokens: i.tok,
      modelType: 'whisper',
      numThreads: 2,
      debug: false,
    ),
  ));
  void drain() {
    while (!vad.isEmpty()) {
      final seg = vad.front();
      vad.pop();
      final st = rec.createStream();
      st.acceptWaveform(samples: seg.samples, sampleRate: 16000);
      rec.decode(st);
      final text = rec.getResult(st).text.trim();
      st.free();
      if (text.isNotEmpty) i.out.send(text);
    }
  }

  i.out.send(rc.sendPort); // ready
  rc.listen((m) {
    if (m is Uint8List) {
      final n = m.lengthInBytes ~/ 2;
      final bd = ByteData.sublistView(m);
      final f = Float32List(n);
      for (var k = 0; k < n; k++) {
        f[k] = bd.getInt16(k * 2, Endian.little) / 32768.0;
      }
      vad.acceptWaveform(f);
      drain();
    } else if (m == 'flush') {
      vad.flush();
      drain();
      i.out.send('<done>');
    } else if (m == 'reset') {
      vad.reset();
    }
  });
}

class SherpaStt {
  SherpaStt._();
  static final SherpaStt instance = SherpaStt._();

  Isolate? _iso;
  SendPort? _tx;
  String _lang = '';
  Completer<void>? _flushDone;
  void Function(String text)? onText;

  /// Starts (or reuses) the worker. Throws when models are missing.
  Future<void> open(String lang) async {
    if (_tx != null && _lang == lang) {
      _tx!.send('reset');
      return;
    }
    close();
    if (!await SherpaModels.hasAsr()) throw 'models missing';
    final d = await SherpaModels.dir(SherpaModels.asrName);
    final rp = ReceivePort();
    final ready = Completer<SendPort>();
    rp.listen((m) {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m == '<done>') {
        _flushDone?.complete();
      } else if (m is String) {
        onText?.call(m);
      }
    });
    _iso = await Isolate.spawn(
        _main,
        _Init(rp.sendPort, await SherpaModels.vadPath(), await SherpaModels.find(d, 'encoder.int8.onnx'),
            await SherpaModels.find(d, 'decoder.int8.onnx'), await SherpaModels.find(d, 'tokens.txt'), lang));
    _tx = await ready.future.timeout(const Duration(seconds: 30));
    _lang = lang;
  }

  void feed(Uint8List pcm16) => _tx?.send(pcm16);

  /// Decodes the last phrase and waits for it.
  Future<void> flush() async {
    if (_tx == null) return;
    _flushDone = Completer<void>();
    _tx!.send('flush');
    await _flushDone!.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  void close() {
    _iso?.kill(priority: Isolate.immediate);
    _iso = null;
    _tx = null;
    _lang = '';
  }
}
