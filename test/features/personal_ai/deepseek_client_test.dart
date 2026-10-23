import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:echo_loop/features/chatbot/models/chat_message.dart';
import 'package:echo_loop/features/chatbot/services/chat_api_client.dart';
import 'package:echo_loop/features/personal_ai/deepseek_client.dart';
import 'package:echo_loop/features/personal_ai/deepseek_prompts.dart';
import 'package:echo_loop/models/dictionary/dictionary_entry.dart';
import 'package:echo_loop/services/sentence_ai_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _completion(Object? result, {String finish = 'stop'}) =>
    ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {'content': jsonEncode(result)},
            'finish_reason': finish,
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

DeepSeekClient _client(_Adapter adapter) {
  final client = DeepSeekClient(
    apiKey: 'test-key',
    model: 'test-model',
    dio: Dio()..httpClientAdapter = adapter,
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('翻译直接发送到 DeepSeek，包含上下文、模型和 JSON 输出约束', () async {
    final adapter = _Adapter((_) => _completion({'translation': '你好'}));
    final result = await _client(adapter).runTask(DeepSeekTask.translation, {
      'text': 'Hello',
      'previousText': 'Hi.',
      'targetLanguage': 'zh-CN',
    });
    expect(result['translation'], '你好');
    final request = adapter.requests.single;
    expect(request.uri.toString(), 'https://api.deepseek.com/chat/completions');
    expect(request.headers['Authorization'], 'Bearer test-key');
    expect(request.followRedirects, isFalse);
    final data = request.data;
    expect(data, isA<Map>());
    if (data is Map) {
      expect(data['model'], 'test-model');
      expect(data['response_format'], {'type': 'json_object'});
      expect(jsonEncode(data['messages']), contains('previousText'));
      expect(jsonEncode(data), isNot(contains('test-key')));
    }
  });

  test('翻译、解析、意群、单词、词组均适配现有视图且不访问官方接口', () async {
    final responses = <Object?>[
      {'translation': '你好'},
      {
        'grammar': [
          {'point': '主谓', 'note': 'Birds fly'},
        ],
        'vocabulary': [],
        'listening': [],
      },
      {
        'medium': ['Birds ', 'fly.'],
        'fine': ['Birds ', 'fly.'],
      },
      {
        'headword': 'fly',
        'meanings': [
          {'partOfSpeech': 'v.', 'definition': 'move through air'},
        ],
      },
      {
        'originalExpression': 'take off',
        'meanings': [],
        'keyPoints': [
          {'point': '起飞'},
        ],
      },
    ];
    var index = 0;
    final deepseek = _client(_Adapter((_) => _completion(responses[index++])));
    final official = _Adapter(
      (_) => throw StateError('Must not contact official backend'),
    );
    final client = SentenceAiApiClient.withDio(
      Dio()..httpClientAdapter = official,
      personalClient: deepseek,
    );
    addTearDown(client.dispose);
    expect(
      (await client.translateStream('Hello', accessToken: 'local').single)
          .translation
          .translation,
      '你好',
    );
    expect(
      (await client.analyzeStream('Birds fly.', accessToken: 'local').single)
          .analysis
          .grammar
          .single
          .point,
      '主谓',
    );
    expect(
      (await client
              .senseGroupsStream('Birds fly.', accessToken: 'local')
              .single)
          .result
          .medium,
      ['Birds ', 'fly.'],
    );
    expect(
      (await client.lookupWordStreamFrames('fly', accessToken: 'local').single)
          .entry,
      isA<DictionaryEntry>(),
    );
    expect(
      (await client
              .lookupPhraseStreamFrames('take off', accessToken: 'local')
              .single)
          .entry,
      isA<MultiWordDictionaryEntry>(),
    );
    expect(official.requests, isEmpty);
  });

  for (final result in [
    {'translation': ''},
    {'translation': 42},
    <String, Object?>{},
  ]) {
    test('无效译文不能进入缓存：$result', () async {
      final client = _client(_Adapter((_) => _completion(result)));
      await expectLater(
        client.runTask(DeepSeekTask.translation, {'text': 'Hello'}),
        throwsA(isA<DeepSeekException>()),
      );
    });
  }

  test('结构化输出截断时不伪装成功', () async {
    final client = _client(
      _Adapter((_) => _completion({'translation': '你好'}, finish: 'length')),
    );
    await expectLater(
      client.runTask(DeepSeekTask.translation, {'text': 'Hello'}),
      throwsA(isA<DeepSeekException>()),
    );
  });

  test('意群必须逐字还原原文，包括空格和标点', () async {
    final client = _client(
      _Adapter(
        (_) => _completion({
          'medium': ['Birds', 'fly.'],
          'fine': ['Birds ', 'fly.'],
        }),
      ),
    );
    await expectLater(
      client.runTask(DeepSeekTask.senseGroups, {'text': 'Birds fly.'}),
      throwsA(isA<DeepSeekException>()),
    );
  });

  for (final status in [401, 402, 429, 500]) {
    test('HTTP $status 映射为个人服务错误，不泄露密钥或误触发官方订阅', () async {
      final client = _client(
        _Adapter((_) => ResponseBody.fromString('sensitive-test-key', status)),
      );
      try {
        await client.runTask(DeepSeekTask.translation, {'text': 'Hello'});
        fail('Expected error');
      } on DeepSeekException catch (error) {
        expect(error.toString(), isNot(contains('test-key')));
        expect(error.message, contains('DeepSeek'));
      }
    });
  }

  test('取消令牌在请求开始前即可阻止网络请求', () async {
    final adapter = _Adapter((_) => _completion({'translation': '你好'}));
    final token = CancelToken()..cancel('stopped');
    await expectLater(
      _client(adapter).runTask(DeepSeekTask.translation, {
        'text': 'Hello',
      }, cancelToken: token),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  ResponseBody sse(String content) => ResponseBody(
    Stream<Uint8List>.fromIterable(
      utf8.encode(content).map((byte) => Uint8List.fromList([byte])),
    ),
    200,
    headers: {
      Headers.contentTypeHeader: ['text/event-stream'],
    },
  );
  String delta(Object? content, {String? finish}) =>
      'data: ${jsonEncode({
        'choices': [
          {
            'delta': {'content': content},
            'finish_reason': finish,
          },
        ],
      })}\n\n';

  test('聊天处理拆包 UTF-8、保活、多轮上下文和显式完成', () async {
    final adapter = _Adapter(
      (_) => sse(
        ': keepalive\n\n${delta('你')}${delta('好')}${delta('', finish: 'stop')}data: [DONE]\n\n',
      ),
    );
    final frames = await _client(adapter)
        .streamChat(
          history: [
            {'role': 'user', 'content': 'Explain it.'},
          ],
          context: {'sentence': 'Birds fly.'},
          targetLanguage: 'zh-CN',
        )
        .toList();
    expect(frames.map((frame) => frame.text), ['你', '你好', '你好']);
    expect(frames.last.isFinal, isTrue);
    expect(jsonEncode(adapter.requests.single.data), contains('Birds fly.'));
    expect(jsonEncode(adapter.requests.single.data), contains('Explain it.'));
  });

  test('原聊天入口携带引用与历史，使用个人服务时不访问官方后端', () async {
    final adapter = _Adapter(
      (_) => sse('${delta('answer', finish: 'stop')}data: [DONE]\n\n'),
    );
    final official = _Adapter(
      (_) => throw StateError('Must not contact official backend'),
    );
    final client = ChatApiClient.withDio(
      Dio()..httpClientAdapter = official,
      personalClient: _client(adapter),
    );
    addTearDown(client.dispose);
    final frames = await client
        .streamChat(
          endpoint: '/api/v1/stream/chat/sentence',
          history: [
            ChatMessage.user(
              id: 'test',
              content: 'Explain',
              quote: 'Birds fly.',
              createdAt: DateTime.utc(2026),
            ),
          ],
          context: {'sentence': 'Birds fly.'},
          followUpInstruction: 'Explain this quote',
          accessToken: 'personal-ai-local-session',
        )
        .toList();
    expect(frames.last.isFinal, isTrue);
    expect(official.requests, isEmpty);
    final request = adapter.requests.single;
    expect(request.headers['Authorization'], 'Bearer test-key');
    expect(jsonEncode(request.data), contains('Explain this quote'));
    expect(
      jsonEncode(request.data),
      isNot(contains('personal-ai-local-session')),
    );
  });

  test('聊天异常断流保留部分结果，但不产生完成帧', () async {
    final frames = <String>[];
    final stream = _client(
      _Adapter((_) => sse(delta('partial'))),
    ).streamChat(history: [], context: {}, targetLanguage: 'zh-CN');
    await expectLater(
      stream.map((frame) {
        expect(frame.isFinal, isFalse);
        frames.add(frame.text);
        return frame;
      }),
      emitsInOrder([anything, emitsError(isA<DeepSeekException>())]),
    );
    expect(frames, ['partial']);
  });

  test('聊天 token 用尽即便收到 DONE 也应提示重试', () async {
    final client = _client(
      _Adapter(
        (_) => sse('${delta('partial', finish: 'length')}data: [DONE]\n\n'),
      ),
    );
    await expectLater(
      client.streamChat(history: [], context: {}, targetLanguage: 'zh-CN'),
      emitsInOrder([anything, emitsError(isA<DeepSeekException>())]),
    );
  });
}
