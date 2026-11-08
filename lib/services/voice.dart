// lib/services/voice.dart
// Reads answers out loud (text-to-speech).
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../app_state.dart';

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<String?> speakingId = ValueNotifier(null);
  bool _ready = false;

  static const _langs = {'en': 'en-US', 'fr': 'fr-FR', 'es': 'es-ES', 'de': 'de-DE'};

  Future<void> _setup() async {
    if (_ready) return;
    _ready = true;
    _tts.setCompletionHandler(() => speakingId.value = null);
    _tts.setCancelHandler(() => speakingId.value = null);
    _tts.setErrorHandler((_) => speakingId.value = null);
  }

  String _plain(String s) => s
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'[*#_`>~]'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '')
      .trim();

  Future<void> speak(String id, String text) async {
    try {
      await _setup();
      if (speakingId.value == id) return stop();
      await _tts.stop();
      await _tts.setLanguage(_langs[localeNotifier.value] ?? 'en-US');
      final clean = _plain(text);
      if (clean.isEmpty) return;
      speakingId.value = id;
      await _tts.speak(clean);
    } catch (e) {
      debugPrint('TTS failed: $e');
      speakingId.value = null;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speakingId.value = null;
  }
}
