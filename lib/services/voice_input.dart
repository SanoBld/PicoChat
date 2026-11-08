// lib/services/voice_input.dart
// Dictation: speech to text into the message field.
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../app_state.dart';

class VoiceInput {
  VoiceInput._();
  static final VoiceInput instance = VoiceInput._();

  final SpeechToText _stt = SpeechToText();
  final ValueNotifier<bool> listening = ValueNotifier(false);
  bool _ready = false;

  static const _langs = {'en': 'en_US', 'fr': 'fr_FR', 'es': 'es_ES', 'de': 'de_DE'};

  // Returns false when speech recognition is not available.
  Future<bool> start(void Function(String words) onWords) async {
    try {
      if (!_ready) {
        _ready = await _stt.initialize(
          onStatus: (s) {
            if (s == 'done' || s == 'notListening') listening.value = false;
          },
          onError: (_) => listening.value = false,
        );
      }
      if (!_ready) return false;
      listening.value = true;
      await _stt.listen(
        onResult: (r) => onWords(r.recognizedWords),
        localeId: _langs[localeNotifier.value],
        listenOptions: SpeechListenOptions(partialResults: true),
      );
      return true;
    } catch (e) {
      debugPrint('Speech input failed: $e');
      listening.value = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
    listening.value = false;
  }
}
