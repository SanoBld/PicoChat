// lib/services/voice.dart
// Reads answers out loud (text-to-speech) with the most natural voice installed.
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../app_state.dart';
import 'sherpa_tts.dart';

class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  /// Natural offline voice (pref pc_voice_neural). Used when its voice file is downloaded.
  static final neural = ValueNotifier<bool>(true);

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<String?> speakingId = ValueNotifier(null);
  bool _ready = false;
  String _voiceLang = '';

  static const _langs = {'en': 'en-US', 'fr': 'fr-FR', 'es': 'es-ES', 'de': 'de-DE'};

  Future<void> _setup() async {
    if (_ready) return;
    _ready = true;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _tts.setCancelHandler(() => speakingId.value = null);
    _tts.setErrorHandler((_) => speakingId.value = null);
  }

  // Best installed voice for the language: network / neural / premium / enhanced first.
  Future<void> _pickVoice(String lang) async {
    final code = _langs[lang] ?? 'en-US';
    await _tts.setLanguage(code);
    if (_voiceLang == lang) return;
    _voiceLang = lang;
    try {
      final all = await _tts.getVoices;
      if (all is! List) return;
      Map? best;
      var bestScore = -999;
      for (final v in all) {
        if (v is! Map) continue;
        final loc = '${v['locale']}'.replaceAll('_', '-').toLowerCase();
        if (!loc.startsWith(lang)) continue;
        final n = '${v['name']}'.toLowerCase();
        var sc = loc == code.toLowerCase() ? 2 : 0;
        if (n.contains('neural') || n.contains('wavenet') || n.contains('studio')) sc += 5;
        if (n.contains('network')) sc += 4;
        if (n.contains('premium')) sc += 5;
        if (n.contains('enhanced')) sc += 3;
        if (n.contains('compact') || n.contains('lite') || n.contains('espeak')) sc -= 4;
        if (v['quality'] != null && '${v['quality']}'.toLowerCase().contains('high')) sc += 3;
        if (sc > bestScore) {
          bestScore = sc;
          best = v;
        }
      }
      if (best != null) await _tts.setVoice({'name': '${best['name']}', 'locale': '${best['locale']}'});
    } catch (e) {
      debugPrint('TTS voice pick failed: $e');
    }
  }

  String _plain(String s) => s
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'\[\[image:[^\]]*\]\]'), ' ')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '')
      .replaceAll(RegExp(r'https?://\S+'), ' ')
      .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true), '')
      .replaceAll(RegExp(r'[*#_`>~|]'), '')
      .replaceAll(RegExp(r'\n{2,}'), '. ')
      .trim();

  // Sentence groups: natural pauses, and under Android's 4000-character limit.
  List<String> _chunks(String s, [int max = 400]) {
    final out = <String>[];
    var cur = StringBuffer();
    for (final part in s.split(RegExp(r'(?<=[.!?…])\s+'))) {
      if (cur.length + part.length > max && cur.isNotEmpty) {
        out.add(cur.toString());
        cur = StringBuffer();
      }
      cur.write('$part ');
    }
    if (cur.toString().trim().isNotEmpty) out.add(cur.toString());
    return out;
  }

  Future<void> speak(String id, String text) async {
    try {
      await _setup();
      if (speakingId.value == id) return stop();
      speakingId.value = null;
      await _tts.stop();
      await SherpaTts.instance.stop();
      final clean = _plain(text);
      if (clean.isEmpty) return;
      if (neural.value) {
        try {
          if (await SherpaTts.instance.open(localeNotifier.value)) {
            speakingId.value = id;
            await SherpaTts.instance.speakAll(_chunks(clean, 180), () => speakingId.value == id);
            if (speakingId.value == id) speakingId.value = null;
            return;
          }
        } catch (e) {
          debugPrint('Neural voice failed, using the system voice: $e');
        }
      }
      await _pickVoice(localeNotifier.value);
      speakingId.value = id;
      for (final c in _chunks(clean)) {
        if (speakingId.value != id) break;
        await _tts.speak(c);
      }
      if (speakingId.value == id) speakingId.value = null;
    } catch (e) {
      debugPrint('TTS failed: $e');
      speakingId.value = null;
    }
  }

  Future<void> stop() async {
    speakingId.value = null; // first: the reading loop must not start the next sentence
    try {
      await _tts.stop();
    } catch (_) {}
    await SherpaTts.instance.stop();
  }
}
