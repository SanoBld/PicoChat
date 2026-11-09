// lib/services/cloud/cloud_engine.dart
// ══════════════════════════════════════════════════════════════════════════
//  Network side of the optional cloud AI: streams an answer from Claude,
//  Gemini, ChatGPT or an OpenAI-compatible server.
//
//  CloudEngine implements the same [InferenceEngine] interface as the
//  llama.cpp engine, so ChatService (files, memory, web results, steps,
//  stop button…) works unchanged: the app builds all the context before the
//  call, and it arrives here inside the history and the system prompt.
//
//  Requests and answers are built / parsed in cloud_protocol.dart (tested).
// ══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../app_state.dart';
import '../../l10n/l10n.dart';
import '../../models/chat_models.dart';
import '../../models/model_models.dart';
import '../inference_engine.dart';
import 'cloud_protocol.dart';
import 'cloud_store.dart';

class CloudEngine implements InferenceEngine {
  CloudEngine._();
  static final CloudEngine instance = CloudEngine._();

  CloudModel? _model;
  http.Client? _client;
  bool _stopped = false;

  /// Chooses the cloud model used by the next [generate]. Returns this engine.
  CloudEngine bind(CloudModel model) {
    _model = model;
    return this;
  }

  @override
  String get name => _model?.provider.label ?? 'Cloud';

  @override
  bool get isPlaceholder => false;

  @override
  String? get loadedModelId => _model?.id;

  @override
  bool get supportsVision => _model?.info.vision ?? false;

  /// Nothing to load: the model lives on the provider's servers.
  @override
  Future<void> load(InstalledModel model, {required int contextSize, String? projectorPath}) async {}

  @override
  Future<void> unload() async => stop();

  @override
  void stop() {
    _stopped = true;
    _client?.close(); // aborts the request in progress
  }

  // ── Conversation → turns ───────────────────────────────────────────────────

  static String? _mime(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
    if (p.endsWith('.gif')) return 'image/gif';
    if (p.endsWith('.webp')) return 'image/webp';
    return null;
  }

  Future<List<CloudImage>> _images(List<String> paths) async {
    if (kIsWeb) return const [];
    final out = <CloudImage>[];
    for (final path in paths) {
      final mime = _mime(path);
      if (mime == null) continue;
      try {
        out.add(CloudImage(mime, base64Encode(await File(path).readAsBytes())));
      } catch (_) {/* unreadable image: skipped */}
    }
    return out;
  }

  Future<List<CloudTurn>> _turns(List<ChatMessage> history, bool sendImages) async {
    if (history.isEmpty) return const [];
    final lastUser = history.lastWhere((m) => m.role == ChatRole.user, orElse: () => history.last);
    var usable = [
      for (final m in history)
        if (m.role != ChatRole.system && m.text.trim().isNotEmpty && !m.failed) m,
    ];
    // "Messages of history sent" setting (0 = everything).
    final limit = cloudHistoryNotifier.value;
    if (limit > 0 && usable.length > limit) usable = usable.sublist(usable.length - limit);
    final out = <CloudTurn>[];
    for (final m in usable) {
      final isLast = m.id == lastUser.id;
      // Like the local engine: hidden context (files, web results, phone data…)
      // goes with the last message of the person only.
      final text = (isLast && m.context.isNotEmpty) ? '${m.context}\n\n${m.text}' : m.text;
      out.add(CloudTurn(
        user: m.role == ChatRole.user,
        text: text,
        images: (isLast && sendImages && m.images.isNotEmpty) ? await _images(m.images) : const [],
      ));
    }
    return out;
  }

  // ── Streaming ──────────────────────────────────────────────────────────────

  @override
  Stream<String> generate(List<ChatMessage> history, GenerationOptions options) async* {
    final model = _model;
    if (model == null) throw StateError('No cloud model selected');
    final acc = model.account;
    _stopped = false;

    final turns = await _turns(history, model.info.vision && cloudCtxFilesNotifier.value);
    final maxOut = outputBudget(acc.provider, model.info.id, options.maxTokens, model.info.maxOutput);
    double? temperature = options.temperature;
    var gotText = false;

    // A second try only when a model refuses the temperature parameter
    // (OpenAI reasoning models, recent Claude models).
    for (var attempt = 0; attempt < 2; attempt++) {
      final req = buildChatRequest(
        provider: acc.provider,
        baseUrl: acc.effectiveBaseUrl,
        apiKey: acc.apiKey.trim(),
        modelId: model.info.id,
        system: options.systemPrompt,
        turns: turns,
        maxTokens: maxOut,
        temperature: temperature,
        browser: kIsWeb,
      );
      final client = http.Client();
      _client = client;
      try {
        final rq = http.Request(req.method, req.url)
          ..headers.addAll(req.headers)
          ..body = req.body ?? '';
        final resp = await client.send(rq).timeout(const Duration(seconds: 60));

        if (resp.statusCode != 200) {
          final body = await resp.stream.bytesToString();
          final err = errorFromResponse(resp.statusCode, body);
          if (attempt == 0 && temperature != null && err.kind == CloudErrorKind.badRequest && err.mentions('temperature')) {
            temperature = null;
            continue;
          }
          throw err;
        }

        final lines = resp.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(const Duration(seconds: 120)); // silence = the connection died
        await for (final line in lines) {
          if (_stopped) break;
          if (!line.startsWith('data:')) continue; // "event:" lines, comments, blanks
          final piece = parseStreamData(acc.provider, line.substring(5));
          if (piece.text != null) {
            gotText = true;
            yield piece.text!;
          }
          if (piece.done) break;
        }
        if (!_stopped && !gotText) throw const CloudException(CloudErrorKind.empty, '');
        return;
      } on CloudException {
        rethrow;
      } catch (e) {
        if (_stopped) return; // the stop button closed the connection
        throw _network(e);
      } finally {
        client.close();
        if (identical(_client, client)) _client = null;
      }
    }
  }
}

CloudException _network(Object e) {
  if (e is CloudException) return e;
  if (e is TimeoutException) return const CloudException(CloudErrorKind.network, 'timeout');
  return CloudException(CloudErrorKind.network, '$e'.replaceFirst('ClientException: ', ''));
}

// ── Model list / connection test ─────────────────────────────────────────────

class CloudApi {
  /// Asks the service which models the key can use. Also proves the key works.
  static Future<List<CloudModelInfo>> listModels(CloudAccount a) async {
    final all = <CloudModelInfo>[];
    String? token;
    try {
      for (var page = 0; page < 8; page++) {
        final req = buildListRequest(
          provider: a.provider,
          baseUrl: a.effectiveBaseUrl,
          apiKey: a.apiKey.trim(),
          pageToken: token,
          browser: kIsWeb,
        );
        final resp = await http.get(req.url, headers: req.headers).timeout(const Duration(seconds: 30));
        final body = utf8.decode(resp.bodyBytes, allowMalformed: true);
        if (resp.statusCode != 200) throw errorFromResponse(resp.statusCode, body);
        final json = jsonDecode(body);
        all.addAll(parseModelList(a.provider, json));
        token = nextPageToken(a.provider, json);
        if (token == null) break;
      }
    } on FormatException {
      throw const CloudException(CloudErrorKind.notFound, 'not an AI server (unexpected answer)');
    } catch (e) {
      throw _network(e);
    }
    return all;
  }
}

/// Readable, translated message for an error of the cloud engine.
String cloudErrorText(Object e) {
  final c = e is CloudException ? e : _network(e);
  final detail = c.detail.trim();
  return tr('cloud_err_${c.kind.name}', {'detail': detail.isEmpty ? '—' : detail});
}
