// test/cloud_protocol_test.dart
// Pure-Dart checks for the cloud AI protocol layer (no network, no Flutter).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:picochat/services/cloud/cloud_protocol.dart';

const _user = CloudTurn(user: true, text: 'Hello');
const _bot = CloudTurn(user: false, text: 'Hi!');

Map<String, dynamic> _body(CloudRequest r) => jsonDecode(r.body!) as Map<String, dynamic>;

CloudRequest _req(CloudProvider p,
        {String base = '', String key = 'k', String model = 'm', String system = '', List<CloudTurn>? turns, int max = 10, double? temp, bool browser = false}) =>
    buildChatRequest(
      provider: p,
      baseUrl: base,
      apiKey: key,
      modelId: model,
      system: system,
      turns: turns ?? const [_user],
      maxTokens: max,
      temperature: temp,
      browser: browser,
    );

void main() {
  test('normalizeTurns drops a leading assistant turn, empty turns and merges same roles', () {
    final out = normalizeTurns(const [
      CloudTurn(user: false, text: 'welcome'),
      CloudTurn(user: true, text: 'a'),
      CloudTurn(user: true, text: 'b'),
      CloudTurn(user: false, text: '  '),
      CloudTurn(user: false, text: 'c'),
    ]);
    expect(out.length, 2);
    expect(out[0].text, 'a\n\nb');
    expect(out[1].text, 'c');
  });

  group('Anthropic request', () {
    test('url, headers, body', () {
      final r = _req(CloudProvider.anthropic,
          key: 'sk-ant-x', model: 'claude-sonnet-5-5', system: 'Be brief.', turns: const [_user, _bot, CloudTurn(user: true, text: 'And?')], max: 500, temp: 0.7);
      expect(r.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(r.headers['x-api-key'], 'sk-ant-x');
      expect(r.headers['anthropic-version'], '2023-06-01');
      expect(r.headers.containsKey('anthropic-dangerous-direct-browser-access'), false);
      final b = _body(r);
      expect(b['system'], 'Be brief.');
      expect(b['stream'], true);
      expect(b['max_tokens'], 500);
      expect(b['temperature'], 0.7);
      expect((b['messages'] as List).length, 3);
    });
    test('temperature is clamped to 1 and can be left out', () {
      expect(_body(_req(CloudProvider.anthropic, temp: 1.8))['temperature'], 1.0);
      final none = _body(_req(CloudProvider.anthropic));
      expect(none.containsKey('temperature'), false);
      expect(none.containsKey('system'), false);
    });
    test('browser header and image blocks', () {
      final w = _req(CloudProvider.anthropic,
          browser: true, turns: const [CloudTurn(user: true, text: 'what is it?', images: [CloudImage('image/png', 'AAA')])]);
      expect(w.headers['anthropic-dangerous-direct-browser-access'], 'true');
      final content = _body(w)['messages'][0]['content'] as List;
      expect(content[0]['type'], 'image');
      expect(content[0]['source']['media_type'], 'image/png');
      expect(content[1]['text'], 'what is it?');
    });
  });

  group('Gemini request', () {
    final r = _req(CloudProvider.gemini,
        key: 'AIza-secret', model: 'models/gemini-2.5-flash', system: 'Be brief.', turns: const [_user, _bot, CloudTurn(user: true, text: 'And?')], max: 800, temp: 0.5);
    test('url has alt=sse and never contains the key', () {
      expect(r.url.toString(),
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse');
      expect(r.url.toString().contains('AIza-secret'), false);
      expect(r.headers['x-goog-api-key'], 'AIza-secret');
    });
    test('roles, system instruction and config', () {
      final b = _body(r);
      expect(b['systemInstruction']['parts'][0]['text'], 'Be brief.');
      expect((b['contents'] as List).map((c) => c['role']).toList(), ['user', 'model', 'user']);
      expect(b['generationConfig']['maxOutputTokens'], 800);
      expect(b['generationConfig']['temperature'], 0.5);
    });
  });

  group('OpenAI request', () {
    test('official: bearer, system first, max_completion_tokens', () {
      final r = _req(CloudProvider.openai, key: 'sk-x', model: 'gpt-5', system: 'Be brief.', max: 300, temp: 1.0);
      expect(r.url.toString(), 'https://api.openai.com/v1/chat/completions');
      expect(r.headers['authorization'], 'Bearer sk-x');
      final b = _body(r);
      expect(b['max_completion_tokens'], 300);
      expect(b.containsKey('max_tokens'), false);
      expect(b['messages'][0]['role'], 'system');
      expect(b['messages'][1]['role'], 'user');
    });
    test('custom: own base url, max_tokens, no key = no auth header', () {
      final r = _req(CloudProvider.custom, base: 'http://localhost:11434/v1/', key: '', model: 'llama3', max: 300);
      expect(r.url.toString(), 'http://localhost:11434/v1/chat/completions');
      expect(r.headers.containsKey('authorization'), false);
      final b = _body(r);
      expect(b['max_tokens'], 300);
      expect(b.containsKey('max_completion_tokens'), false);
      expect((b['messages'] as List).length, 1);
    });
    test('image goes as a data URI', () {
      final r = _req(CloudProvider.openai,
          turns: const [CloudTurn(user: true, text: 'see', images: [CloudImage('image/jpeg', 'QQ==')])]);
      final parts = _body(r)['messages'][0]['content'] as List;
      expect(parts[1]['image_url']['url'], 'data:image/jpeg;base64,QQ==');
    });
  });

  group('stream parsing', () {
    test('Anthropic: text_delta yes, thinking and pings no, error throws', () {
      expect(parseStreamData(CloudProvider.anthropic, '{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}').text, 'Hel');
      expect(parseStreamData(CloudProvider.anthropic, '{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"hmm"}}').text, null);
      expect(parseStreamData(CloudProvider.anthropic, '{"type":"ping"}').text, null);
      expect(parseStreamData(CloudProvider.anthropic, '{"type":"message_stop"}').done, true);
      expect(() => parseStreamData(CloudProvider.anthropic, '{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}'),
          throwsA(isA<CloudException>()));
    });
    test('Gemini: joins parts, skips thoughts, blocked prompt throws', () {
      final p = parseStreamData(CloudProvider.gemini,
          '{"candidates":[{"content":{"role":"model","parts":[{"text":"secret plan","thought":true},{"text":"Bon"},{"text":"jour"}]}}]}');
      expect(p.text, 'Bonjour');
      expect(() => parseStreamData(CloudProvider.gemini, '{"promptFeedback":{"blockReason":"SAFETY"}}'), throwsA(isA<CloudException>()));
    });
    test('OpenAI: delta content, null content, [DONE], usage chunk, junk', () {
      expect(parseStreamData(CloudProvider.openai, '{"choices":[{"delta":{"content":"Hi"}}]}').text, 'Hi');
      expect(parseStreamData(CloudProvider.openai, '{"choices":[{"delta":{"role":"assistant","content":null}}]}').text, null);
      expect(parseStreamData(CloudProvider.openai, '{"choices":[],"usage":{"total_tokens":3}}').text, null);
      expect(parseStreamData(CloudProvider.openai, ' [DONE]').done, true);
      expect(parseStreamData(CloudProvider.custom, 'not json').text, null);
    });
  });

  test('errors: status to kind, message extracted', () {
    final e = errorFromResponse(401, '{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}');
    expect(e.kind, CloudErrorKind.auth);
    expect(e.detail, 'invalid x-api-key');
    expect(errorFromResponse(429, '{"error":{"message":"Quota exceeded","status":"RESOURCE_EXHAUSTED"}}').kind, CloudErrorKind.rateLimit);
    expect(errorFromResponse(404, 'x').kind, CloudErrorKind.notFound);
    expect(errorFromResponse(503, '<html>').kind, CloudErrorKind.server);
    final t = errorFromResponse(400, '{"error":{"message":"Unsupported value: \'temperature\' does not support 0.7"}}');
    expect(t.kind, CloudErrorKind.badRequest);
    expect(t.mentions('temperature'), true);
  });

  group('model list', () {
    test('Anthropic', () {
      final m = parseModelList(CloudProvider.anthropic, {
        'data': [
          {'id': 'claude-opus-5-5', 'display_name': 'Claude Opus 5.5', 'max_input_tokens': 1000000, 'max_tokens': 64000, 'capabilities': {'image_input': {'supported': true}}},
        ],
      });
      expect(m.single.id, 'claude-opus-5-5');
      expect(m.single.contextTokens, 1000000);
      expect(m.single.maxOutput, 64000);
      expect(m.single.vision, true);
    });
    test('Gemini keeps only chat models and strips "models/"', () {
      final m = parseModelList(CloudProvider.gemini, {
        'models': [
          {'name': 'models/gemini-2.5-pro', 'displayName': 'Gemini 2.5 Pro', 'inputTokenLimit': 1048576, 'outputTokenLimit': 65536, 'supportedGenerationMethods': ['generateContent', 'countTokens']},
          {'name': 'models/text-embedding-004', 'supportedGenerationMethods': ['embedContent']},
        ],
      });
      expect(m.map((e) => e.id).toList(), ['gemini-2.5-pro']);
      expect(m.single.maxOutput, 65536);
    });
    test('OpenAI filters non-chat models, newest first', () {
      final m = parseModelList(CloudProvider.openai, {
        'data': [
          {'id': 'text-embedding-3-small', 'created': 5},
          {'id': 'gpt-4o', 'created': 10},
          {'id': 'whisper-1', 'created': 1},
          {'id': 'gpt-5', 'created': 20},
          {'id': 'gpt-4o-realtime-preview', 'created': 30},
        ],
      });
      expect(m.map((e) => e.id).toList(), ['gpt-5', 'gpt-4o']);
    });
    test('custom keeps everything and reads context_length', () {
      final m = parseModelList(CloudProvider.custom, {
        'data': [
          {'id': 'llama3', 'context_length': 8192},
          {'id': 'qwen2.5-vl'},
        ],
      });
      expect(m.length, 2);
      expect(m.first.contextTokens, 8192);
      expect(m.last.vision, true);
    });
    test('paging', () {
      expect(nextPageToken(CloudProvider.gemini, {'nextPageToken': 'abc'}), 'abc');
      expect(nextPageToken(CloudProvider.anthropic, {'has_more': true, 'last_id': 'z'}), 'z');
      expect(nextPageToken(CloudProvider.openai, {'nextPageToken': 'abc'}), null);
    });
    test('model info survives JSON', () {
      final i = CloudModelInfo.fromJson(const CloudModelInfo(id: 'a', name: 'A', contextTokens: 5, maxOutput: 2, vision: true).toJson());
      expect([i.id, i.name, i.contextTokens, i.maxOutput, i.vision], ['a', 'A', 5, 2, true]);
    });
  });

  test('outputBudget leaves room for hidden reasoning tokens', () {
    expect(outputBudget(CloudProvider.anthropic, 'claude-sonnet-5-5', 1024, 64000), 1024);
    expect(outputBudget(CloudProvider.gemini, 'gemini-2.5-flash', 1024, 65536), 3072);
    expect(outputBudget(CloudProvider.gemini, 'gemini-2.0-flash', 1024, 8192), 1024);
    expect(outputBudget(CloudProvider.openai, 'gpt-5', 1024, 0), 5120);
    expect(outputBudget(CloudProvider.openai, 'gpt-4o', 1024, 16384), 1024);
    expect(outputBudget(CloudProvider.openai, 'o3', 20000, 8000), 8000);
  });
}
