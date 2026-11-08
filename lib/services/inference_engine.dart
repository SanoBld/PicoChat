// lib/services/inference_engine.dart
// ══════════════════════════════════════════════════════════════════════════
//  The seam between the chat UI and the code that runs a model.
//
//  This base project ships a PlaceholderEngine (no AI: it streams a notice)
//  so the whole app can be built and tested. For real answers, implement
//  [InferenceEngine] on top of an on-device GGUF runtime (llama.cpp via FFI
//  or a Flutter plugin) and set, in main.dart:
//
//      InferenceService.engine = MyLlamaEngine();
//
//  Nothing else in the app has to change.
// ══════════════════════════════════════════════════════════════════════════

import 'dart:async';

import '../l10n/l10n.dart';
import '../models/chat_models.dart';
import '../models/model_models.dart';

/// Sampling settings sent with every request (Settings > Chat).
class GenerationOptions {
  final String systemPrompt;
  final double temperature;
  final int maxTokens;
  const GenerationOptions({
    required this.systemPrompt,
    required this.temperature,
    required this.maxTokens,
  });
}

abstract class InferenceEngine {
  String get name;

  /// True for the demo engine that doesn't run a real model.
  bool get isPlaceholder;

  /// Id of the model currently in memory, or null.
  String? get loadedModelId;

  Future<void> load(InstalledModel model, {required int contextSize});

  /// Streams the answer piece by piece. [history] ends with the person's
  /// message. The stream must end after [stop] is called.
  Stream<String> generate(List<ChatMessage> history, GenerationOptions options);

  void stop();

  Future<void> unload();
}

/// Holds the engine the app uses.
class InferenceService {
  InferenceService._();
  static InferenceEngine engine = PlaceholderEngine();
}

/// Demo engine: streams a short explanation word by word, so typing, stop
/// and history behave like the real thing.
class PlaceholderEngine implements InferenceEngine {
  String? _loaded;
  bool _stopped = false;

  @override
  String get name => 'Placeholder';

  @override
  bool get isPlaceholder => true;

  @override
  String? get loadedModelId => _loaded;

  @override
  Future<void> load(InstalledModel model, {required int contextSize}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _loaded = model.id;
  }

  @override
  Stream<String> generate(List<ChatMessage> history, GenerationOptions options) async* {
    _stopped = false;
    final last = history.isEmpty ? '' : history.last.text.trim();
    final short = last.length > 80 ? '${last.substring(0, 80)}…' : last;
    final words = tr('demo_reply', {'msg': short}).split(' ');
    for (var i = 0; i < words.length; i++) {
      if (_stopped) return;
      await Future<void>.delayed(const Duration(milliseconds: 45));
      yield i == 0 ? words[i] : ' ${words[i]}';
    }
  }

  @override
  void stop() => _stopped = true;

  @override
  Future<void> unload() async => _loaded = null;
}
