// lib/services/llama_engine.dart
// ══════════════════════════════════════════════════════════════════════════
//  Real on-device engine: runs GGUF models with llama.cpp through the
//  `llamadart` package (Android, iOS, macOS, Linux, Windows).
//
//  It implements the same [InferenceEngine] interface as the demo engine,
//  so the chat UI does not change.
// ══════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:llamadart/llamadart.dart';

import '../models/chat_models.dart';
import '../models/model_models.dart';
import 'inference_engine.dart';

class LlamaDartEngine implements InferenceEngine {
  LlamaEngine? _engine;
  String? _loaded;
  bool _stopped = false;

  @override
  String get name => 'llama.cpp';

  @override
  bool get isPlaceholder => false;

  @override
  String? get loadedModelId => _loaded;

  @override
  Future<void> load(InstalledModel model, {required int contextSize}) async {
    await unload();
    // Throws when the file is missing or is not a valid GGUF model; the
    // chat service shows that as a failed answer.
    final engine = await LlamaEngine.load(
      LlamaModel(ModelSource.path(model.path)),
      params: ModelParams(contextSize: contextSize),
    );
    _engine = engine;
    _loaded = model.id;
  }

  @override
  Stream<String> generate(List<ChatMessage> history, GenerationOptions options) async* {
    final engine = _engine;
    if (engine == null) throw StateError('No model loaded');
    _stopped = false;

    // The engine is stateless: send the whole conversation every time.
    final messages = <LlamaChatMessage>[
      if (options.systemPrompt.trim().isNotEmpty)
        LlamaChatMessage.fromText(role: LlamaChatRole.system, text: options.systemPrompt.trim()),
      for (final m in history)
        if (m.role != ChatRole.system && m.text.trim().isNotEmpty && !m.failed)
          LlamaChatMessage.fromText(
            role: m.role == ChatRole.user ? LlamaChatRole.user : LlamaChatRole.assistant,
            text: m.text,
          ),
    ];

    final stream = engine.create(
      messages,
      params: GenerationParams(
        temp: options.temperature,
        maxTokens: options.maxTokens,
      ),
      enableThinking: false, // keep the reasoning of "thinking" models out of the chat
    );

    await for (final chunk in stream) {
      if (_stopped) break;
      final Object? raw = chunk.text;
      final piece = raw?.toString() ?? '';
      if (piece.isNotEmpty) yield piece;
    }
  }

  @override
  void stop() {
    _stopped = true;
    _engine?.cancelGeneration();
  }

  @override
  Future<void> unload() async {
    final engine = _engine;
    _engine = null;
    _loaded = null;
    if (engine != null) await engine.dispose();
  }
}
