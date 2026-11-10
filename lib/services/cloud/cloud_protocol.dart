// lib/services/cloud/cloud_protocol.dart
// ══════════════════════════════════════════════════════════════════════════
//  Pure Dart (no Flutter, no network): builds the HTTP requests of the
//  optional cloud AI and parses the answers.
//
//  Three wire formats:
//    anthropic : POST {base}/v1/messages                     (Claude)
//    gemini    : POST {base}/models/{id}:streamGenerateContent?alt=sse
//    openai    : POST {base}/chat/completions                (ChatGPT and every
//                OpenAI-compatible server: Mistral, DeepSeek, Groq, OpenRouter,
//                Ollama, LM Studio…)
// ══════════════════════════════════════════════════════════════════════════

import 'dart:convert';

enum CloudProvider { anthropic, gemini, openai, mistral, deepseek, xai, custom }

CloudProvider cloudProviderFromId(String? id) =>
    CloudProvider.values.firstWhere((p) => p.name == id, orElse: () => CloudProvider.custom);

extension CloudProviderInfo on CloudProvider {
  String get shortName => switch (this) {
        CloudProvider.anthropic => 'Claude',
        CloudProvider.gemini => 'Gemini',
        CloudProvider.openai => 'ChatGPT',
        CloudProvider.mistral => 'Mistral',
        CloudProvider.deepseek => 'DeepSeek',
        CloudProvider.xai => 'Grok',
        CloudProvider.custom => 'Compatible',
      };

  String get label => switch (this) {
        CloudProvider.anthropic => 'Claude (Anthropic)',
        CloudProvider.gemini => 'Gemini (Google)',
        CloudProvider.openai => 'ChatGPT (OpenAI)',
        CloudProvider.mistral => 'Mistral AI',
        CloudProvider.deepseek => 'DeepSeek',
        CloudProvider.xai => 'Grok (xAI)',
        CloudProvider.custom => 'OpenAI-compatible',
      };

  String get defaultBaseUrl => switch (this) {
        CloudProvider.anthropic => 'https://api.anthropic.com',
        CloudProvider.gemini => 'https://generativelanguage.googleapis.com/v1beta',
        CloudProvider.openai => 'https://api.openai.com/v1',
        CloudProvider.mistral => 'https://api.mistral.ai/v1',
        CloudProvider.deepseek => 'https://api.deepseek.com/v1',
        CloudProvider.xai => 'https://api.x.ai/v1',
        CloudProvider.custom => '',
      };

  /// Page where the person creates an API key ('' = none).
  String get keyUrl => switch (this) {
        CloudProvider.anthropic => 'https://platform.claude.com/settings/keys',
        CloudProvider.gemini => 'https://aistudio.google.com/apikey',
        CloudProvider.openai => 'https://platform.openai.com/api-keys',
        CloudProvider.mistral => 'https://console.mistral.ai/api-keys',
        CloudProvider.deepseek => 'https://platform.deepseek.com/api_keys',
        CloudProvider.xai => 'https://console.x.ai',
        CloudProvider.custom => '',
      };

  /// Local servers (Ollama, LM Studio) work without a key.
  bool get keyRequired => this != CloudProvider.custom;
}

// ── Data ─────────────────────────────────────────────────────────────────────

class CloudImage {
  final String mime;
  final String data; // base64
  const CloudImage(this.mime, this.data);
}

/// One message of the conversation, already holding its hidden context.
class CloudTurn {
  final bool user;
  final String text;
  final List<CloudImage> images;
  const CloudTurn({required this.user, required this.text, this.images = const []});
}

class CloudRequest {
  final String method;
  final Uri url;
  final Map<String, String> headers; // lower-case keys
  final String? body;
  const CloudRequest(this.method, this.url, this.headers, [this.body]);
}

class CloudModelInfo {
  final String id;
  final String name;
  final int contextTokens;
  final int maxOutput; // 0 = unknown
  final bool vision;
  final bool image; // can make pictures
  final bool imageOnly; // only makes pictures: not a chat model
  const CloudModelInfo({
    required this.id,
    String? name,
    this.contextTokens = 128000,
    this.maxOutput = 0,
    this.vision = false,
    this.image = false,
    this.imageOnly = false,
  }) : name = name ?? id;

  CloudModelInfo copyWith({bool? vision, bool? image, bool? imageOnly}) => CloudModelInfo(
        id: id,
        name: name,
        contextTokens: contextTokens,
        maxOutput: maxOutput,
        vision: vision ?? this.vision,
        image: image ?? this.image,
        imageOnly: imageOnly ?? this.imageOnly,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ctx': contextTokens,
        'out': maxOutput,
        'vision': vision,
        if (image) 'img': imageOnly ? 2 : 1,
      };

  factory CloudModelInfo.fromJson(Map<String, dynamic> j) => CloudModelInfo(
        id: j['id'] as String,
        name: j['name'] as String?,
        contextTokens: (j['ctx'] as num?)?.toInt() ?? 128000,
        maxOutput: (j['out'] as num?)?.toInt() ?? 0,
        vision: j['vision'] == true,
        image: ((j['img'] as num?)?.toInt() ?? 0) > 0,
        imageOnly: ((j['img'] as num?)?.toInt() ?? 0) == 2,
      );
}

enum CloudErrorKind { auth, rateLimit, notFound, badRequest, server, network, blocked, empty, other }

class CloudException implements Exception {
  final CloudErrorKind kind;
  final String detail;
  const CloudException(this.kind, this.detail);

  bool mentions(String word) => detail.toLowerCase().contains(word.toLowerCase());

  @override
  String toString() => 'CloudException(${kind.name}: $detail)';
}

/// What one streamed line brings: some text, the end, or nothing.
class StreamPiece {
  final String? text;
  final bool done;
  const StreamPiece({this.text, this.done = false});
}

// ── Turns ────────────────────────────────────────────────────────────────────

/// Removes empty turns and a leading assistant turn, and merges consecutive
/// turns of the same role (all three APIs want user/assistant alternation).
List<CloudTurn> normalizeTurns(List<CloudTurn> turns) {
  final out = <CloudTurn>[];
  for (final t in turns) {
    if (t.text.trim().isEmpty && t.images.isEmpty) continue;
    if (out.isEmpty && !t.user) continue;
    if (out.isNotEmpty && out.last.user == t.user) {
      final p = out.removeLast();
      out.add(CloudTurn(
        user: p.user,
        text: p.text.trim().isEmpty ? t.text : (t.text.trim().isEmpty ? p.text : '${p.text}\n\n${t.text}'),
        images: [...p.images, ...t.images],
      ));
    } else {
      out.add(t);
    }
  }
  return out;
}

String _base(String baseUrl, CloudProvider p) {
  var b = baseUrl.trim().isEmpty ? p.defaultBaseUrl : baseUrl.trim();
  while (b.endsWith('/')) {
    b = b.substring(0, b.length - 1);
  }
  return b;
}

String _modelPath(String id) => id.startsWith('models/') ? id.substring(7) : id;

double _clamp(double v, double max) => v < 0 ? 0 : (v > max ? max : v);

// ── Chat request ─────────────────────────────────────────────────────────────

/// Request that streams one answer. [temperature] null = left to the service.
/// [browser] adds the header Anthropic needs when called from a web page.
CloudRequest buildChatRequest({
  required CloudProvider provider,
  required String baseUrl,
  required String apiKey,
  required String modelId,
  required String system,
  required List<CloudTurn> turns,
  required int maxTokens,
  double? temperature,
  bool browser = false,
}) {
  final base = _base(baseUrl, provider);
  final list = normalizeTurns(turns);
  final sys = system.trim();
  const json = 'application/json';

  switch (provider) {
    case CloudProvider.anthropic:
      final body = <String, dynamic>{
        'model': modelId,
        'max_tokens': maxTokens,
        'stream': true,
        if (sys.isNotEmpty) 'system': sys,
        if (temperature != null) 'temperature': _clamp(temperature, 1.0),
        'messages': [
          for (final t in list)
            {
              'role': t.user ? 'user' : 'assistant',
              'content': t.images.isEmpty
                  ? t.text
                  : [
                      for (final i in t.images)
                        {
                          'type': 'image',
                          'source': {'type': 'base64', 'media_type': i.mime, 'data': i.data},
                        },
                      {'type': 'text', 'text': t.text.trim().isEmpty ? '.' : t.text},
                    ],
            },
        ],
      };
      return CloudRequest(
        'POST',
        Uri.parse('$base/v1/messages'),
        {
          'content-type': json,
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          if (browser) 'anthropic-dangerous-direct-browser-access': 'true',
        },
        jsonEncode(body),
      );

    case CloudProvider.gemini:
      final body = <String, dynamic>{
        if (sys.isNotEmpty)
          'systemInstruction': {
            'parts': [
              {'text': sys},
            ],
          },
        'contents': [
          for (final t in list)
            {
              'role': t.user ? 'user' : 'model',
              'parts': [
                {'text': t.text.trim().isEmpty ? '.' : t.text},
                for (final i in t.images)
                  {
                    'inline_data': {'mime_type': i.mime, 'data': i.data},
                  },
              ],
            },
        ],
        'generationConfig': {
          'maxOutputTokens': maxTokens,
          if (temperature != null) 'temperature': _clamp(temperature, 2.0),
        },
      };
      // The key goes in a header, never in the URL (URLs end up in logs).
      return CloudRequest(
        'POST',
        Uri.parse('$base/models/${_modelPath(modelId)}:streamGenerateContent?alt=sse'),
        {'content-type': json, 'x-goog-api-key': apiKey},
        jsonEncode(body),
      );

    case CloudProvider.openai:
    case CloudProvider.custom:
    case CloudProvider.mistral:
    case CloudProvider.deepseek:
    case CloudProvider.xai:
      final official = provider == CloudProvider.openai;
      final body = <String, dynamic>{
        'model': modelId,
        'stream': true,
        // Official API: max_tokens is deprecated and refused by recent models.
        // Other servers still only know max_tokens.
        if (official) 'max_completion_tokens': maxTokens else 'max_tokens': maxTokens,
        if (temperature != null) 'temperature': _clamp(temperature, 2.0),
        'messages': [
          if (sys.isNotEmpty) {'role': 'system', 'content': sys},
          for (final t in list)
            {
              'role': t.user ? 'user' : 'assistant',
              'content': t.images.isEmpty
                  ? t.text
                  : [
                      {'type': 'text', 'text': t.text.trim().isEmpty ? '.' : t.text},
                      for (final i in t.images)
                        {
                          'type': 'image_url',
                          'image_url': {'url': 'data:${i.mime};base64,${i.data}'},
                        },
                    ],
            },
        ],
      };
      return CloudRequest(
        'POST',
        Uri.parse('$base/chat/completions'),
        {
          'content-type': json,
          if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
        },
        jsonEncode(body),
      );
  }
}

// ── Stream parsing ───────────────────────────────────────────────────────────

CloudErrorKind _kindOfType(String t) {
  final s = t.toLowerCase();
  if (s.contains('auth') || s.contains('permission') || s.contains('api_key') || s.contains('unauthenticated')) {
    return CloudErrorKind.auth;
  }
  if (s.contains('rate') || s.contains('quota') || s.contains('exhausted') || s.contains('billing')) {
    return CloudErrorKind.rateLimit;
  }
  if (s.contains('not_found') || s.contains('not found')) return CloudErrorKind.notFound;
  if (s.contains('overload') || s.contains('unavailable') || s.contains('internal') || s.contains('api_error')) {
    return CloudErrorKind.server;
  }
  if (s.contains('invalid')) return CloudErrorKind.badRequest;
  return CloudErrorKind.other;
}

String _errorMessage(Object? j) {
  if (j is Map) {
    final e = j['error'];
    if (e is Map) {
      final m = e['message'];
      if (m is String && m.isNotEmpty) return m;
    }
    if (e is String && e.isNotEmpty) return e;
    final m = j['message'];
    if (m is String && m.isNotEmpty) return m;
  }
  return '';
}

/// Parses the payload of one "data:" line of the stream. Throws a
/// [CloudException] when the line carries an error or a blocked answer.
StreamPiece parseStreamData(CloudProvider provider, String data) {
  final raw = data.trim();
  if (raw.isEmpty) return const StreamPiece();
  if (raw == '[DONE]') return const StreamPiece(done: true);
  Object? j;
  try {
    j = jsonDecode(raw);
  } catch (_) {
    return const StreamPiece(); // keep-alive or a format we do not know
  }
  if (j is! Map) return const StreamPiece();

  switch (provider) {
    case CloudProvider.anthropic:
      final type = j['type'];
      if (type == 'error') {
        final e = j['error'];
        final t = e is Map ? '${e['type']}' : '';
        throw CloudException(_kindOfType(t), _errorMessage(j));
      }
      if (type == 'content_block_delta') {
        final d = j['delta'];
        if (d is Map && d['type'] == 'text_delta' && d['text'] is String) {
          return StreamPiece(text: d['text'] as String);
        }
        return const StreamPiece(); // thinking_delta, input_json_delta…
      }
      if (type == 'message_delta') {
        final d = j['delta'];
        if (d is Map && d['stop_reason'] == 'refusal') {
          throw const CloudException(CloudErrorKind.blocked, 'refusal');
        }
      }
      if (type == 'message_stop') return const StreamPiece(done: true);
      return const StreamPiece();

    case CloudProvider.gemini:
      if (j['error'] != null) {
        final e = j['error'];
        final status = e is Map ? '${e['status']}' : '';
        throw CloudException(_kindOfType(status), _errorMessage(j));
      }
      final fb = j['promptFeedback'];
      if (fb is Map && fb['blockReason'] != null) {
        throw CloudException(CloudErrorKind.blocked, '${fb['blockReason']}');
      }
      final cands = j['candidates'];
      if (cands is! List || cands.isEmpty || cands.first is! Map) return const StreamPiece();
      final cand = cands.first as Map;
      final b = StringBuffer();
      final content = cand['content'];
      if (content is Map && content['parts'] is List) {
        for (final p in content['parts'] as List) {
          if (p is Map && p['thought'] != true && p['text'] is String) b.write(p['text']);
        }
      }
      if (b.isEmpty) {
        const bad = {'SAFETY', 'RECITATION', 'PROHIBITED_CONTENT', 'BLOCKLIST', 'SPII', 'IMAGE_SAFETY'};
        final fr = '${cand['finishReason']}';
        if (bad.contains(fr)) throw CloudException(CloudErrorKind.blocked, fr);
        return const StreamPiece();
      }
      return StreamPiece(text: b.toString());

    case CloudProvider.openai:
    case CloudProvider.custom:
    case CloudProvider.mistral:
    case CloudProvider.deepseek:
    case CloudProvider.xai:
      if (j['error'] != null) {
        final e = j['error'];
        final t = e is Map ? '${e['type']} ${e['code']}' : '';
        throw CloudException(_kindOfType(t), _errorMessage(j));
      }
      final ch = j['choices'];
      if (ch is! List || ch.isEmpty || ch.first is! Map) return const StreamPiece();
      final delta = (ch.first as Map)['delta'];
      if (delta is Map && delta['content'] is String && (delta['content'] as String).isNotEmpty) {
        return StreamPiece(text: delta['content'] as String);
      }
      return const StreamPiece();
  }
}

// ── HTTP errors ──────────────────────────────────────────────────────────────

CloudException errorFromResponse(int status, String body) {
  Object? j;
  try {
    j = jsonDecode(body);
  } catch (_) {}
  var msg = _errorMessage(j);
  if (msg.isEmpty) {
    final t = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    msg = t.length > 140 ? '${t.substring(0, 140)}…' : t;
  }
  final kind = switch (status) {
    401 || 403 => CloudErrorKind.auth,
    402 || 429 => CloudErrorKind.rateLimit,
    404 => CloudErrorKind.notFound,
    400 || 413 || 422 => CloudErrorKind.badRequest,
    >= 500 => CloudErrorKind.server,
    _ => CloudErrorKind.other,
  };
  return CloudException(kind, msg.isEmpty ? 'HTTP $status' : msg);
}

// ── Model list ───────────────────────────────────────────────────────────────

CloudRequest buildListRequest({
  required CloudProvider provider,
  required String baseUrl,
  required String apiKey,
  String? pageToken,
  bool browser = false,
}) {
  final base = _base(baseUrl, provider);
  switch (provider) {
    case CloudProvider.anthropic:
      return CloudRequest(
        'GET',
        Uri.parse('$base/v1/models').replace(queryParameters: {
          'limit': '1000',
          'after_id': ?pageToken,
        }),
        {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          if (browser) 'anthropic-dangerous-direct-browser-access': 'true',
        },
      );
    case CloudProvider.gemini:
      return CloudRequest(
        'GET',
        Uri.parse('$base/models').replace(queryParameters: {
          'pageSize': '1000',
          'pageToken': ?pageToken,
        }),
        {'x-goog-api-key': apiKey},
      );
    case CloudProvider.openai:
    case CloudProvider.custom:
    case CloudProvider.mistral:
    case CloudProvider.deepseek:
    case CloudProvider.xai:
      return CloudRequest(
        'GET',
        Uri.parse('$base/models'),
        {if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey'},
      );
  }
}

String? nextPageToken(CloudProvider provider, Object? json) {
  if (json is! Map) return null;
  if (provider == CloudProvider.gemini) {
    final t = json['nextPageToken'];
    return t is String && t.isNotEmpty ? t : null;
  }
  if (provider == CloudProvider.anthropic && json['has_more'] == true) {
    final t = json['last_id'];
    return t is String && t.isNotEmpty ? t : null;
  }
  return null;
}

int _int(Object? v) => v is num ? v.toInt() : 0;

final _openaiChat = RegExp(r'^(gpt-|o\d|chatgpt-)');
final _openaiImage = RegExp(r'^(gpt-image|dall-e)');
final _openaiNot = RegExp(
    r'embedding|whisper|tts|dall-e|realtime|audio|transcribe|image|moderation|instruct|codex|davinci|babbage|search|computer-use|sora');
final _openaiVision = RegExp(r'^(gpt-4o|gpt-4\.1|gpt-4\.5|gpt-4-turbo|gpt-5|o3|o4|chatgpt-4o)');
final _customVision = RegExp(r'vision|-vl|vl-|llava|gpt-4o|gemma-3|pixtral|multimodal|minicpm-v');
const _geminiNot = ['tts', 'imagen', 'veo', 'live', 'native-audio', 'embedding', 'aqa'];

/// Chat models of one "list models" answer, most useful first.
List<CloudModelInfo> parseModelList(CloudProvider provider, Object? json) {
  if (json is! Map) return const [];
  final out = <CloudModelInfo>[];

  switch (provider) {
    case CloudProvider.anthropic:
      for (final m in (json['data'] as List?) ?? const []) {
        if (m is! Map || m['id'] is! String) continue;
        final caps = m['capabilities'];
        final img = caps is Map && caps['image_input'] is Map && (caps['image_input'] as Map)['supported'] == true;
        out.add(CloudModelInfo(
          id: m['id'] as String,
          name: (m['display_name'] as String?) ?? m['id'] as String,
          contextTokens: _int(m['max_input_tokens']) > 0 ? _int(m['max_input_tokens']) : 200000,
          maxOutput: _int(m['max_tokens']),
          vision: img,
        ));
      }

    case CloudProvider.gemini:
      for (final m in (json['models'] as List?) ?? const []) {
        if (m is! Map || m['name'] is! String) continue;
        final methods = (m['supportedGenerationMethods'] as List?) ?? const [];
        if (!methods.contains('generateContent')) continue;
        final id = _modelPath(m['name'] as String);
        if (_geminiNot.any(id.contains)) continue;
        out.add(CloudModelInfo(
          id: id,
          name: (m['displayName'] as String?) ?? id,
          contextTokens: _int(m['inputTokenLimit']) > 0 ? _int(m['inputTokenLimit']) : 128000,
          maxOutput: _int(m['outputTokenLimit']),
          vision: id.startsWith('gemini'),
          image: id.contains('image'), // e.g. gemini-2.5-flash-image: chats and draws
        ));
      }

    case CloudProvider.openai:
      final rows = <(int, CloudModelInfo)>[];
      for (final m in (json['data'] as List?) ?? const []) {
        if (m is! Map || m['id'] is! String) continue;
        final id = m['id'] as String;
        if (_openaiImage.hasMatch(id)) {
          rows.add((_int(m['created']), CloudModelInfo(id: id, image: true, imageOnly: true)));
          continue;
        }
        if (!_openaiChat.hasMatch(id) || _openaiNot.hasMatch(id)) continue;
        rows.add((_int(m['created']), CloudModelInfo(id: id, vision: _openaiVision.hasMatch(id))));
      }
      rows.sort((a, b) => b.$1.compareTo(a.$1));
      out.addAll(rows.map((r) => r.$2));

    case CloudProvider.custom:
    case CloudProvider.mistral:
    case CloudProvider.deepseek:
    case CloudProvider.xai:
      for (final m in (json['data'] as List?) ?? const []) {
        if (m is! Map || m['id'] is! String) continue;
        final id = m['id'] as String;
        final ctx = [m['context_length'], m['max_context_length'], m['context_window'], m['max_model_len']]
            .map(_int)
            .firstWhere((v) => v > 0, orElse: () => 32000);
        final arch = m['architecture'];
        final mods = arch is Map && arch['input_modalities'] is List ? arch['input_modalities'] as List : const [];
        final isImg = mods.contains('image_output') || RegExp(r'sd|flux|dall-e|imagen|image-gen').hasMatch(id.toLowerCase());
        out.add(CloudModelInfo(
          id: id,
          name: (m['name'] as String?) ?? id,
          contextTokens: ctx,
          vision: mods.contains('image') || _customVision.hasMatch(id.toLowerCase()),
          image: isImg,
        ));
      }
  }
  return out;
}

// ── Output budget ────────────────────────────────────────────────────────────

/// Number of tokens to ask for. "Thinking" models count their hidden reasoning
/// inside the limit, so a small limit can leave no room for the visible answer.
int outputBudget(CloudProvider provider, String modelId, int wanted, int modelMax) {
  final id = modelId.toLowerCase();
  var n = wanted;
  if (provider == CloudProvider.gemini && RegExp(r'gemini-(2\.5|[3-9])').hasMatch(id)) {
    n = wanted * 3;
  } else if (provider == CloudProvider.openai && RegExp(r'^(gpt-5|o\d)').hasMatch(id)) {
    n = wanted + 4096;
  }
  if (modelMax > 0 && n > modelMax) n = modelMax;
  return n < 1 ? 1 : n;
}

// ── Picture generation ───────────────────────────────────────────────────────

/// A picture made by a cloud model: base64 data, or a link to download.
class GeneratedPicture {
  final String mime;
  final String? base64;
  final String? url;
  const GeneratedPicture(this.mime, {this.base64, this.url});
}

/// Request that makes one picture. Claude has no picture model.
CloudRequest buildImageRequest({
  required CloudProvider provider,
  required String baseUrl,
  required String apiKey,
  required String modelId,
  required String prompt,
}) {
  final base = _base(baseUrl, provider);
  const json = 'application/json';
  switch (provider) {
    case CloudProvider.gemini:
      return CloudRequest(
        'POST',
        Uri.parse('$base/models/${_modelPath(modelId)}:generateContent'),
        {'content-type': json, 'x-goog-api-key': apiKey},
        jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'responseModalities': ['TEXT', 'IMAGE'],
          },
        }),
      );
    case CloudProvider.openai:
    case CloudProvider.custom:
    case CloudProvider.mistral:
    case CloudProvider.deepseek:
    case CloudProvider.xai:
      return CloudRequest(
        'POST',
        Uri.parse('$base/images/generations'),
        {
          'content-type': json,
          if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
        },
        jsonEncode({
          'model': modelId,
          'prompt': prompt,
          'n': 1,
          'size': '1024x1024',
          if (modelId.startsWith('dall-e')) 'response_format': 'b64_json',
        }),
      );
    case CloudProvider.anthropic:
      throw const CloudException(CloudErrorKind.badRequest, 'This service cannot make pictures');
  }
}

GeneratedPicture? parseImageResponse(CloudProvider provider, Object? json) {
  if (json is! Map) return null;
  if (provider == CloudProvider.gemini) {
    for (final c in (json['candidates'] as List?) ?? const []) {
      final parts = c is Map && c['content'] is Map ? (c['content'] as Map)['parts'] : null;
      for (final part in (parts as List?) ?? const []) {
        if (part is! Map) continue;
        final inline = part['inlineData'] ?? part['inline_data'];
        if (inline is Map && inline['data'] is String) {
          return GeneratedPicture((inline['mimeType'] ?? inline['mime_type'] ?? 'image/png') as String,
              base64: inline['data'] as String);
        }
      }
    }
    return null;
  }
  final data = json['data'];
  if (data is List && data.isNotEmpty && data.first is Map) {
    final d = data.first as Map;
    if (d['b64_json'] is String) return GeneratedPicture('image/png', base64: d['b64_json'] as String);
    if (d['url'] is String) return GeneratedPicture('image/png', url: d['url'] as String);
  }
  return null;
}
