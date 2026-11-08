// lib/services/chat_service.dart
// Runs one answer at a time: adds the messages, loads the model if needed,
// streams the engine output into the assistant message, handles stop,
// errors and automatic titles.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../widgets/net_consent.dart';
import '../l10n/l10n.dart';

import '../app_state.dart';
import '../models/chat_models.dart';
import '../models/model_models.dart';
import 'attachments.dart';
import 'device_data.dart';
import 'map_service.dart';
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

  final Map<String, bool> _netAsked = {}; // answers of this message, per kind of request

  /// Asks the person before using the internet. Once per kind per message.
  Future<bool> _netOk(String kind, String what) async {
    if (!webAskNotifier.value) return true;
    final known = _netAsked[kind];
    if (known != null) return known;
    final ok = await askNetConsent(what);
    _netAsked[kind] = ok;
    return ok;
  }

  List<String> _pendingMem = []; // memory changes made by the app for the current message

  bool get isGenerating => _generating;
  bool get isLoadingModel => _loadingModel;
  bool get isSearching => _searching;
  bool isGeneratingIn(Conversation c) => _generating && _chatId == c.id;

  /// True when a model is installed and selected.
  /// Model chosen by the assistant card (null = the model of the app).
  InstalledModel? modelOverride;
  InstalledModel? get currentModel => modelOverride ?? ModelManager.instance.active;

  bool get canChat => currentModel != null;

  Future<void> send(Conversation chat, String text,
      {List<Attachment> files = const [], bool web = false}) async {
    final clean = text.trim();
    if (clean.isEmpty || _generating || !canChat) return;
    final first = chat.messages.isEmpty;
    chat.modelId = currentModel!.id;
    VoiceService.instance.stop();
    final msg = ChatMessage(
      role: ChatRole.user,
      text: clean,
      files: [for (final f in files) f.name],
      images: [for (final f in files) if (f.imagePath != null) f.imagePath!],
    );
    ChatStore.instance.addMessage(chat, msg);
    if (first && autoTitleNotifier.value) {
      ChatStore.instance.setAutoTitle(chat, _titleFrom(clean));
    }
    String? remembered;
    if (memoryEnabledNotifier.value) {
      remembered = MemoryStore.intentFact(clean);
      if (remembered != null) await MemoryStore.instance.add(remembered);
    }
    _pendingMem = [if (remembered != null) '+ $remembered'];
    if (memoryEnabledNotifier.value) {
      final f = MemoryStore.forgetIntent(clean);
      if (f != null) _pendingMem.addAll([for (final r in await MemoryStore.instance.forget(f)) '− $r']);
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
        out[i] = ChatMessage(role: ChatRole.user, text: text, context: out[i].context, images: out[i].images);
        break;
      }
    }
    return out;
  }

  Future<void> _answer(Conversation chat,
      {List<Attachment> files = const [], bool web = false, String query = '', String? remembered, String? command}) async {
    final store = ChatStore.instance;
    final engine = InferenceService.engine;
    final model = currentModel;
    if (model == null) return;

    final history = List<ChatMessage>.of(chat.messages); // ends with the user message
    final reply = ChatMessage(role: ChatRole.assistant, text: '');
    store.addMessage(chat, reply);

    _generating = true;
    _chatId = chat.id;
    _stopRequested = false;
    _netAsked.clear();
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
    final prevAssistant =
        history.lastWhere((m) => m.role == ChatRole.assistant, orElse: () => ChatMessage(role: ChatRole.assistant, text: '')).text;
    final wantsFile = FileOutput.requested(lastUser, prevHadFile: prevAssistant.contains('```file:'));
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
        for (final f in files.where((f) => !f.isImage)) {
          final cut = budget ~/ files.length;
          final t = f.text.length > cut ? f.text.substring(0, cut) : f.text;
          ctx.writeln('--- File: ${f.name} ---\n$t\n');
        }
        step('step_files', files.map((f) => f.name).join(', '));
      }

      // Exact data: calculator, weather, scores
      CardResult? card;
      if (query.isNotEmpty) {
        final mapNet = MapService.needsNetwork(query);
        final dataNet = CardService.needsNetwork(query);
        final allowed = (!mapNet && !dataNet) ||
            await _netOk('cards', mapNet ? tr('net_what_map') : '${tr('net_what_data')}\n“$query”');
        if (allowed) {
          _searching = true;
          notifyListeners();
          card = await MapService.build(query) ?? await CardService.build(query);
          _searching = false;
        } else {
          ctx.writeln('--- Note ---\nThe user refused internet access for this request. Say it in one short sentence and '
              'answer only with what you already know, stating that it may be outdated.\n');
        }
        if (MapService.mapIntent(query)) ctx.writeln('--- Map control ---\n${MapService.hint}\n');
        if (card != null) {
          step(card.step, card.detail);
          reply.cards.add(card.card);
          ctx.writeln('--- Verified data ---\n${card.summary}\n');
        }
      }

      // Phone data (contacts, messages, notifications, calendar): only if asked AND allowed.
      if (query.isNotEmpty) {
        final dv = await DeviceData.build(query);
        if (dv != null) {
          step(dv.step, dv.detail);
          ctx.writeln('--- Phone data (read from the user\'s device) ---\n${dv.text}\n');
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
        await engine.load(model,
            contextSize: contextSizeNotifier.value, projectorPath: ModelManager.instance.projectorFor(model));
        _loadedCtx = contextSizeNotifier.value;
        _loadingModel = false;
        notifyListeners();
      }

      // An image was sent but the model cannot see: tell the person how to fix it.
      if (history.last.images.isNotEmpty && !engine.supportsVision) {
        ctx.writeln('--- Note ---\nThe user attached an image, but the current model cannot see images. '
            'Say it in one short sentence and suggest installing a model with the Vision tag from the Models store.\n');
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
        if (!await _netOk('web', '${tr('net_what_web')}\n${queries.map((q) => '• $q').join('\n')}')) {
          _searching = false;
          ctx.writeln('--- Note ---\nThe user refused web search. Answer only with what you already know and say it may be outdated.\n');
        } else {
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
        maxTokens: switch (answerLengthNotifier.value) {
          'short' => math.min(maxTokensNotifier.value, 400),
          'medium' => math.min(maxTokensNotifier.value, 900),
          _ => maxTokensNotifier.value,
        },
      );
      final dev = devModeNotifier.value;
      final sw = Stopwatch()..start();
      int? firstMs;
      var pieces = 0;
      if (dev) reply.prompt = _promptDump(options.systemPrompt, history);
      await for (final piece in engine.generate(history, options)) {
        pieces++;
        firstMs ??= sw.elapsedMilliseconds;
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
      if (dev && pieces > 0) {
        // One streamed piece is about one token.
        final genMs = (sw.elapsedMilliseconds - (firstMs ?? 0)).clamp(1, 1 << 30);
        reply.stats = {
          'tps': pieces > 1 ? (pieces - 1) * 1000 / genMs : 0.0,
          'tokens': pieces,
          'firstMs': firstMs ?? 0,
          'totalMs': sw.elapsedMilliseconds,
          'model': model.fileName,
          'ctx': contextSizeNotifier.value,
          'promptTok': (reply.prompt.length / 3.5).round(),
        };
      }
      // The AI controls the map with hidden tags (markers, routes).
      final raw = buffer.toString();
      if (MapService.hasTags(raw) && await _netOk('maptags', tr('net_what_map'))) {
        await MapService.applyTags(reply, raw);
      }
      final mem = <String>[..._pendingMem];
      _pendingMem = [];
      if (memoryEnabledNotifier.value) {
        mem.addAll(await MemoryStore.instance.harvest(buffer.toString(), userText: lastUser, hadFiles: files.isNotEmpty));
      }
      reply.memories = mem;
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

  /// Everything sent to the model, for developer mode.
  String _promptDump(String system, List<ChatMessage> h) {
    final b = StringBuffer('### SYSTEM\n$system\n');
    for (final m in h) {
      if (m.role == ChatRole.system || m.failed || m.text.trim().isEmpty) continue;
      b.writeln('\n### ${m.role.name.toUpperCase()}');
      if (m.role == ChatRole.user && m.context.isNotEmpty) b.writeln(m.context);
      b.writeln(m.text);
      if (m.images.isNotEmpty) b.writeln('[${m.images.length} image(s)]');
    }
    return b.toString();
  }

  /// First line of the message, cut to a readable length.
  String _titleFrom(String text) {
    final line = text.split('\n').first.trim();
    return line.length <= 44 ? line : '${line.substring(0, 44).trimRight()}…';
  }
}
