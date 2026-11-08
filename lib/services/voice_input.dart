// lib/services/voice_input.dart
// Live dictation: words appear while you speak (transcript + sound levels).
// Recognition restarts by itself after pauses until you validate or cancel.
import 'package:flutter/widgets.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../app_state.dart';

class VoiceInput {
  VoiceInput._();
  static final VoiceInput instance = VoiceInput._();

  final SpeechToText _stt = SpeechToText();
  final ValueNotifier<bool> listening = ValueNotifier(false);
  final ValueNotifier<String> transcript = ValueNotifier(''); // words heard in this dictation
  final ValueNotifier<List<double>> levels = ValueNotifier(List.filled(28, 0.0));
  bool _ready = false;
  bool _wanted = false;
  TextEditingController? _ctrl;
  String _original = ''; // field text before dictation
  String _acc = ''; // words of earlier recognition sessions
  String _live = ''; // words of the current session
  String? _localeId;

  // Returns false when speech recognition is not available.
  Future<bool> start(TextEditingController ctrl) async {
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
      _ctrl = ctrl;
      _original = ctrl.text;
      _acc = '';
      _live = '';
      transcript.value = '';
      levels.value = List.filled(28, 0.0);
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

  // The recognizer expects its own locale id format (fr_FR, fr-FR…): ask it.
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

  void _write() {
    final c = _ctrl;
    if (c == null) return;
    final spoken = '$_acc$_live'.trim();
    transcript.value = spoken;
    final base = _original.isEmpty ? '' : '${_original.trimRight()} ';
    final text = '$base$spoken';
    c.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
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
    _wanted = false;
    try {
      await _stt.stop();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 350)); // last words
    _write();
    listening.value = false;
  }

  /// Cancel: restore the field as it was.
  Future<void> cancel() async {
    _wanted = false;
    try {
      await _stt.cancel();
    } catch (_) {}
    final c = _ctrl;
    if (c != null) {
      c.value = TextEditingValue(text: _original, selection: TextSelection.collapsed(offset: _original.length));
    }
    transcript.value = '';
    listening.value = false;
  }
}
