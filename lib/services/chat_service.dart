// lib/services/chat_service.dart
// Runs one answer at a time: adds the messages, loads the model if needed,
// streams the engine output into the assistant message, handles stop,
// errors and automatic titles.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../models/chat_models.dart';
import 'chat_store.dart';
import 'inference_engine.dart';
import 'model_manager.dart';

class ChatService extends ChangeNotifier {
  ChatService._();
  static final ChatService instance = ChatService._();

  bool _generating = false;
  bool _loadingModel = false;
  bool _stopRequested = false;
  String? _chatId;

  bool get isGenerating => _generating;
  bool get isLoadingModel => _loadingModel;
  bool isGeneratingIn(Conversation c) => _generating && _chatId == c.id;

  /// True when a model is installed and selected.
  bool get canChat => ModelManager.instance.active != null;

  /// Sends [text] as a new user message and streams the answer.
  Future<void> send(Conversation chat, String text) async {
    final clean = text.trim();
    if (clean.isEmpty || _generating || !canChat) return;
    final first = chat.messages.isEmpty;
    chat.modelId = ModelManager.instance.active!.id;
    ChatStore.instance.addMessage(chat, ChatMessage(role: ChatRole.user, text: clean));
    if (first && autoTitleNotifier.value) {
      ChatStore.instance.setAutoTitle(chat, _titleFrom(clean));
    }
    await _answer(chat);
  }

  /// Deletes the last assistant answer and writes a new one.
  Future<void> regenerate(Conversation chat) async {
    if (_generating || !canChat) return;
    if (chat.messages.isNotEmpty && chat.messages.last.role == ChatRole.assistant) {
      ChatStore.instance.removeMessage(chat, chat.messages.last);
    }
    if (chat.messages.isEmpty || chat.messages.last.role != ChatRole.user) return;
    await _answer(chat);
  }

  /// Called by the stop button.
  void requestStop() {
    if (!_generating) return;
    _stopRequested = true;
    InferenceService.engine.stop();
  }

  Future<void> _answer(Conversation chat) async {
    final store = ChatStore.instance;
    final engine = InferenceService.engine;
    final model = ModelManager.instance.active;
    if (model == null) return;

    final history = List<ChatMessage>.of(chat.messages); // ends with the user message
    final reply = ChatMessage(role: ChatRole.assistant, text: '');
    store.addMessage(chat, reply);

    _generating = true;
    _chatId = chat.id;
    _stopRequested = false;
    notifyListeners();

    final buffer = StringBuffer();
    var lastPush = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      if (engine.loadedModelId != model.id) {
        _loadingModel = true;
        notifyListeners();
        await engine.load(model, contextSize: contextSizeNotifier.value);
        _loadingModel = false;
        notifyListeners();
      }
      final options = GenerationOptions(
        systemPrompt: systemPromptNotifier.value,
        temperature: temperatureNotifier.value,
        maxTokens: maxTokensNotifier.value,
      );
      await for (final piece in engine.generate(history, options)) {
        buffer.write(piece);
        if (streamResponsesNotifier.value) {
          reply.text = buffer.toString();
          final now = DateTime.now();
          if (now.difference(lastPush).inMilliseconds > 40) {
            lastPush = now;
            store.messageChanged(chat);
          }
        }
      }
      reply.text = buffer.toString();
      reply.stopped = _stopRequested;
    } catch (e) {
      debugPrint('Generation failed: $e');
      reply.text = buffer.toString();
      reply.failed = true;
    } finally {
      _loadingModel = false;
      _generating = false;
      _chatId = null;
      _stopRequested = false;
      store.messageChanged(chat);
      notifyListeners();
    }
  }

  /// First line of the message, cut to a readable length.
  String _titleFrom(String text) {
    final line = text.split('\n').first.trim();
    return line.length <= 44 ? line : '${line.substring(0, 44).trimRight()}…';
  }
}
