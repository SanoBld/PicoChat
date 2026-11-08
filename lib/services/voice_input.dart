// lib/services/voice_input.dart
// Live dictation: words appear in the message field while you speak.
// Recognition restarts by itself after pauses until you press stop.
import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import 'package:flutter/widgets.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../app_state.dart';

class VoiceInput {
  VoiceInput._();
  static final VoiceInput instance = VoiceInput._();

  final SpeechToText _stt = SpeechToText();
  final ValueNotifier<bool> listening = ValueNotifier(false);
  bool _ready = false;
  bool _wanted = false;
  TextEditingController? _ctrl;
  String _base = '';

  static const _langs = {'en': 'en_US', 'fr': 'fr_FR', 'es': 'es_ES', 'de': 'de_DE'};

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
      _ctrl = ctrl;
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

  Future<void> _listen() async {
    final c = _ctrl;
    if (c == null) return;
    _base = c.text.isEmpty ? '' : '${c.text.trimRight()} ';
    await _stt.listen(
      onResult: (r) {
        final text = '$_base${r.recognizedWords}';
        c.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        localeId: _langs[localeNotifier.value],
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _restart() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!_wanted) return;
    try {
      if (!_stt.isListening) await _listen();
    } catch (_) {
      _wanted = false;
      listening.value = false;
    }
  }

  Future<void> stop() async {
    _wanted = false;
    try {
      await _stt.stop();
    } catch (_) {}
    listening.value = false;
  }
}
