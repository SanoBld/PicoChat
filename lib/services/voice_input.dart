// lib/services/voice_input.dart
// Live dictation. Default engine: Whisper (offline, on the device, via
// whisper.cpp). Fallback: the system speech recognizer.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../app_state.dart';

class VoiceInput {
  VoiceInput._();
  static final VoiceInput instance = VoiceInput._();

  final ValueNotifier<bool> listening = ValueNotifier(false);
  final ValueNotifier<bool> loading = ValueNotifier(false); // preparing the Whisper model
  final ValueNotifier<String> transcript = ValueNotifier(''); // words heard in this dictation
  final ValueNotifier<List<double>> levels = ValueNotifier(List.filled(28, 0.0));

  TextEditingController? _ctrl;
  String _original = ''; // field text before dictation
  String _acc = ''; // system engine: words of earlier sessions
  String _live = ''; // words of the current session

  // ── Whisper ────────────────────────────────────────────────────────────
  final AudioRecorder _rec = AudioRecorder();
  WhisperController? _wc;
  dynamic _session;
  StreamSubscription<Uint8List>? _pcmSub;
  StreamSubscription<String>? _partialSub;
  StreamController<Uint8List>? _pipe;
  bool _whisper = false;

  // ── System recognizer ──────────────────────────────────────────────────
  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  bool _wanted = false;
  String? _localeId;

  /// Returns false when no speech engine is available.
  Future<bool> start(TextEditingController ctrl) async {
    _ctrl = ctrl;
    _original = ctrl.text;
    _acc = '';
    _live = '';
    transcript.value = '';
    levels.value = List.filled(28, 0.0);
    if (voiceEngineNotifier.value == 'whisper') {
      try {
        if (await _startWhisper()) return true;
      } catch (e) {
        debugPrint('Whisper failed, using the system recognizer: $e');
      }
      await _teardownWhisper(finalize: false);
    }
    return _startSystem();
  }

  WhisperModel _model() => switch (voiceModelNotifier.value) {
        'tiny' => WhisperModel.tiny,
        'small' => WhisperModel.small,
        _ => WhisperModel.base,
      };

  void _level(Uint8List b) {
    final n = b.lengthInBytes ~/ 2;
    if (n == 0) return;
    final bd = ByteData.sublistView(b);
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final v = bd.getInt16(i * 2, Endian.little) / 32768.0;
      sum += v * v;
    }
    final rms = math.sqrt(sum / n);
    levels.value = [...levels.value.skip(1), (rms * 7).clamp(0.0, 1.0)];
  }

  Future<bool> _startWhisper() async {
    if (!await _rec.hasPermission()) return false;
    loading.value = true;
    listening.value = true; // show the panel while the model loads
    _pipe = StreamController<Uint8List>(); // buffers audio until Whisper is ready
    final pcm = await _rec.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
    _pcmSub = pcm.listen((bytes) {
      _pipe?.add(bytes);
      _level(bytes);
    });
    _wc = WhisperController();
    _session = await _wc!.transcribeLive(model: _model(), pcm16Stream: _pipe!.stream, lang: localeNotifier.value);
    _partialSub = (_session.partials as Stream<String>).listen((t) {
      loading.value = false;
      _live = t.trim();
      _write();
    });
    loading.value = false;
    _whisper = true;
    return true;
  }

  Future<void> _teardownWhisper({required bool finalize}) async {
    try {
      await _rec.stop();
    } catch (_) {}
    await _pcmSub?.cancel();
    _pcmSub = null;
    try {
      await _pipe?.close();
    } catch (_) {}
    _pipe = null;
    try {
      final t = await _session?.stop();
      if (finalize && t is String && t.trim().isNotEmpty) {
        _live = t.trim();
        _write();
      }
    } catch (_) {}
    await _partialSub?.cancel();
    _partialSub = null;
    _session = null;
    _whisper = false;
    loading.value = false;
    listening.value = false;
  }

  void _write() {
    final c = _ctrl;
    if (c == null) return;
    final spoken = '$_acc$_live'.trim();
    transcript.value = spoken;
    final base = _original.isEmpty ? '' : '${_original.trimRight()} ';
    final text = '$base$spoken';
    c.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  // ── System engine ──────────────────────────────────────────────────────
  Future<bool> _startSystem() async {
    try {
      if (!_ready) {
        _ready = await _stt.initialize(
          onStatus: (s) {
            if ((s == 'done' || s == 'notListening') && _wanted) _restart();
          },
          onError: (e) {
            if (_wanted && !e.permanent) {
              _restart();
            } else {
              _wanted = false;
              listening.value = false;
            }
          },
        );
      }
      if (!_ready) return false;
      _localeId = await _pickLocale();
      _wanted = true;
      listening.value = true;
      await _listen();
      return true;
    } catch (e) {
      debugPrint('Speech input failed: $e');
      _wanted = false;
      listening.value = false;
      return false;
    }
  }

  Future<String?> _pickLocale() async {
    try {
      final lang = localeNotifier.value;
      final all = await _stt.locales();
      final mine = all.where((l) => l.localeId.toLowerCase().replaceAll('-', '_').startsWith('${lang}_'));
      if (mine.isEmpty) return null;
      final sys = (await _stt.systemLocale())?.localeId.toLowerCase().replaceAll('-', '_');
      for (final l in mine) {
        if (l.localeId.toLowerCase().replaceAll('-', '_') == sys) return l.localeId;
      }
      return mine.first.localeId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _listen() async {
    _live = '';
    await _stt.listen(
      onResult: (r) {
        _live = r.recognizedWords;
        if (r.finalResult && _live.isNotEmpty) {
          _acc = '$_acc$_live ';
          _live = '';
        }
        _write();
      },
      onSoundLevelChange: (l) {
        final v = ((l + 2) / 12).clamp(0.0, 1.0);
        levels.value = [...levels.value.skip(1), v];
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        localeId: _localeId,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _restart() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!_wanted) return;
    try {
      if (!_stt.isListening) {
        if (_live.isNotEmpty) {
          _acc = '$_acc$_live ';
          _live = '';
        }
        await _listen();
      }
    } catch (_) {
      _wanted = false;
      listening.value = false;
    }
  }

  /// Validate: keep the text in the field.
  Future<void> stop() async {
    if (_whisper) {
      loading.value = true; // last words are being decoded
      await _teardownWhisper(finalize: true);
      return;
    }
    _wanted = false;
    try {
      await _stt.stop();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _write();
    listening.value = false;
  }

  /// Cancel: restore the field as it was.
  Future<void> cancel() async {
    if (_whisper) {
      await _teardownWhisper(finalize: false);
    } else {
      _wanted = false;
      try {
        await _stt.cancel();
      } catch (_) {}
    }
    final c = _ctrl;
    if (c != null) {
      c.value = TextEditingValue(text: _original, selection: TextSelection.collapsed(offset: _original.length));
    }
    transcript.value = '';
    listening.value = false;
  }
}
