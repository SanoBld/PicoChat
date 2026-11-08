// lib/services/chat_service.dart
// Runs one answer at a time: adds the messages, loads the model if needed,
// streams the engine output into the assistant message, handles stop,
// errors and automatic titles.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../models/chat_models.dart';
import 'attachments.dart';
import 'auto_commands.dart';
import 'cards.dart';
import 'chat_store.dart';
import 'file_output.dart';
import 'core_prompt.dart';
import 'inference_engine.dart';
import 'memory_store.dart';
import 'model_manager.dart';
import 'voice.dart';
import 'web_intent.dart';
import 'web_search.dart';

class ChatService extends ChangeNotifier {
  ChatService._();
  static final ChatService instance = ChatService._();

  bool _generating = false;
  bool _loadingModel = false;
  bool _stopRequested = false;
  bool _searching = false;
  int _loadedCtx = 0;
  String? _chatId;

  bool get isGenerating => _generating;
  bool get isLoadingModel => _loadingModel;
  bool get isSearching => _searching;
  bool isGeneratingIn(Conversation c) => _generating && _chatId == c.id;

  /// True when a model is installed and selected.
  bool get canChat => ModelManager.instance.active != null;

  Future<void> send(Conversation chat, String text,
      {List<Attachment> files = const [], bool web = false}) async {
    final clean = text.trim();
    if (clean.isEmpty || _generating || !canChat) return;
    final first = chat.messages.isEmpty;
    chat.modelId = ModelManager.instance.active!.id;
    VoiceService.instance.stop();
    final msg = ChatMessage(role: ChatRole.user, text: clean, files: [for (final f in files) f.name]);
    ChatStore.instance.addMessage(chat, msg);
    if (first && autoTitleNotifier.value) {
      ChatStore.instance.setAutoTitle(chat, _titleFrom(clean));
    }
    String? remembered;
    if (memoryEnabledNotifier.value) {
      remembered = MemoryStore.intentFact(clean);
      if (remembered != null) await MemoryStore.instance.add(remembered);
    }
    final command = await AutoCommands.apply(clean);
    await _answer(chat, files: files, web: web, query: clean, remembered: remembered, command: command);
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

  /// Three short search queries written by the model (Ultra mode).
  Future<List<String>> _plan(InferenceEngine engine, String q) async {
    final b = StringBuffer();
    final msg = ChatMessage(
      role: ChatRole.user,
      text: 'Write 3 different short web search queries (max 8 words each) that together best answer this request. '
          'One per line, no numbering, no quotes, no comments.\nRequest: $q',
    );
    await for (final piece in engine.generate(
        [msg], GenerationOptions(systemPrompt: 'You only write web search queries.', temperature: 0.2, maxTokens: 90))) {
      b.write(piece);
      if (_stopRequested) break;
    }
    final lines = b
        .toString()
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'^[\s\-*\d.)]+'), '').replaceAll('"', '').trim())
        .where((l) => l.length >= 3 && l.length <= 90)
        .toList();
    return lines.take(3).toList();
  }

  /// Same conversation, with the last user message replaced.
  List<ChatMessage> _withLast(List<ChatMessage> h, String text) {
    final out = List<ChatMessage>.of(h);
    for (var i = out.length - 1; i >= 0; i--) {
      if (out[i].role == ChatRole.user) {
        out[i] = ChatMessage(role: ChatRole.user, text: text, context: out[i].context);
        break;
      }
    }
    return out;
  }

  Future<void> _answer(Conversation chat,
      {List<Attachment> files = const [], bool web = false, String query = '', String? remembered, String? command}) async {
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

    final ultra = ultraModeNotifier.value;
    final rm = reasoningModeNotifier.value;
    final thinking = rm == 'on' || (rm == 'auto' && (ultra || maxTokensNotifier.value >= 3072));
    void push() => store.messageChanged(chat);
    void step(String title, [String detail = '']) {
      if (reply.steps.isNotEmpty) reply.steps.last['state'] = 'done';
      reply.steps.add({'title': title, 'detail': detail, 'state': 'run'});
      push();
    }

    final lastUser =
        history.lastWhere((m) => m.role == ChatRole.user, orElse: () => ChatMessage(role: ChatRole.user, text: '')).text;
    final wantsFile = FileOutput.requested(lastUser);
    String shown(String t) {
      final v = MemoryStore.visible(
          t.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').replaceAll(RegExp(r'<think>[\s\S]*$'), ''));
      return wantsFile ? v : FileOutput.strip(v);
    }

    final buffer = StringBuffer();
    var lastPush = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      step('step_analyze', lastUser.length > 120 ? '${lastUser.substring(0, 120)}…' : lastUser);
      final ctx = StringBuffer();
      if (command != null) {
        step('step_command', command);
        ctx.writeln('--- App action ---\nThe app just did this because the user asked: $command. '
            'Confirm it in one short sentence, then answer the rest of the request if there is one.\n');
      }

      // Files
      if (files.isNotEmpty) {
        final budget = ((contextSizeNotifier.value - maxTokensNotifier.value - 500) * 3).clamp(1500, 60000);
        for (final f in files) {
          final cut = budget ~/ files.length;
          final t = f.text.length > cut ? f.text.substring(0, cut) : f.text;
          ctx.writeln('--- File: ${f.name} ---\n$t\n');
        }
        step('step_files', files.map((f) => f.name).join(', '));
      }

      // Exact data: calculator, weather, scores
      CardResult? card;
      if (query.isNotEmpty) {
        _searching = true;
        notifyListeners();
        card = await CardService.build(query);
        _searching = false;
        if (card != null) {
          step(card.step, card.detail);
          reply.cards.add(card.card);
          ctx.writeln('--- Verified data ---\n${card.summary}\n');
        }
      }

      // A single calculation is answered by the built-in calculator only.
      if (card != null && card.card['type'] == 'calc' && files.isEmpty) {
        reply.text = '';
        return;
      }

      // Model
      if (engine.loadedModelId != model.id || _loadedCtx != contextSizeNotifier.value) {
        step('step_load', model.displayName);
        _loadingModel = true;
        notifyListeners();
        await engine.load(model, contextSize: contextSizeNotifier.value);
        _loadedCtx = contextSizeNotifier.value;
        _loadingModel = false;
        notifyListeners();
      }

      // Web
      final doWeb = (web || ultra) && query.isNotEmpty && (card == null || ultra);
      if (doWeb) {
        var queries = [WebIntent.augment(query)];
        if (ultra) {
          step('step_plan');
          _searching = true;
          notifyListeners();
          final plan = await _plan(engine, query);
          queries = [...queries, ...plan];
          reply.steps.last['detail'] = queries.join('\n');
        }
        step('step_search', queries.join('\n'));
        _searching = true;
        notifyListeners();
        final per = ultra ? 8 : webMaxSourcesNotifier.value;
        final batches = await Future.wait([for (final q in queries) WebSearch.run(q, max: per)]);
        _searching = false;
        final seen = <String>{};
        final found = <WebResult>[];
        for (final bt in batches) {
          for (final r in bt) {
            if (seen.add(r.url)) found.add(r);
          }
        }
        final list = found.take(ultra ? 20 : (per == 0 ? 40 : per)).toList();
        if (list.isNotEmpty) {
          final budget = ((contextSizeNotifier.value - maxTokensNotifier.value - 500) * 3).clamp(1500, 60000);
          reply.sources = [for (final w in list) {'title': w.title, 'url': w.url, 'domain': w.domain}];
          step('step_read', '${list.length} · ${list.map((w) => w.domain).toSet().take(6).join(', ')}');
          ctx.writeln('--- Web results (use them and cite the URLs) ---\n${WebSearch.format(list, budget ~/ 2)}\n');
        }
      }

      if (ctx.isNotEmpty) {
        for (var i = history.length - 1; i >= 0; i--) {
          if (history[i].role == ChatRole.user) {
            history[i].context = ctx.toString();
            break;
          }
        }
      }

      // Ultra: a first private pass that analyses the request and the data.
      if (thinking && !_stopRequested) {
        step('step_reason');
        final analysis = StringBuffer();
        final h2 = _withLast(
            history,
            '$lastUser\n\n[Task] Do NOT answer yet. Think step by step: 1) what exactly is asked and every constraint, '
            '2) the key facts you can rely on (only from the provided data), 3) contradictions or missing information, '
            '4) the structure of the best answer. Be concise (max 200 words).');
        await for (final piece in engine.generate(
            h2,
            GenerationOptions(
                systemPrompt: CorePrompt.build(fileRequested: false),
                temperature: 0.3,
                maxTokens: math.min(maxTokensNotifier.value, ultra ? 700 : 350)))) {
          analysis.write(piece);
          if (_stopRequested) break;
        }
        final a = analysis.toString().replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
        reply.steps.last['detail'] = a;
        if (a.isNotEmpty) {
          for (var i = history.length - 1; i >= 0; i--) {
            if (history[i].role == ChatRole.user) {
              history[i].context =
                  '${history[i].context}\n--- Your private analysis (verify it, then write the final answer: complete, precise, well structured) ---\n$a\n';
              break;
            }
          }
        }
      }

      step('step_write');
      final options = GenerationOptions(
        systemPrompt: CorePrompt.build(fileRequested: wantsFile),
        temperature: temperatureNotifier.value,
        maxTokens: maxTokensNotifier.value,
      );
      await for (final piece in engine.generate(history, options)) {
        buffer.write(piece);
        if (streamResponsesNotifier.value) {
          reply.text = shown(buffer.toString());
          final now = DateTime.now();
          if (now.difference(lastPush).inMilliseconds > 40) {
            lastPush = now;
            store.messageChanged(chat);
          }
        }
      }
      if (remembered != null) {
        reply.memories = [remembered];
      } else if (memoryEnabledNotifier.value) {
        reply.memories = await MemoryStore.instance.harvest(buffer.toString());
      }
      reply.text = shown(buffer.toString());
      reply.stopped = _stopRequested;
      if (autoSpeakNotifier.value && !_stopRequested && reply.text.isNotEmpty) {
        VoiceService.instance.speak(reply.id, reply.text);
      }
    } catch (e) {
      debugPrint('Generation failed: $e');
      reply.text = shown(buffer.toString());
      reply.failed = true;
    } finally {
      for (final s in reply.steps) {
        s['state'] = 'done';
      }
      _loadingModel = false;
      _searching = false;
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
