/// 用户自带 DeepSeek 密钥的配置页面。
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../screens/asr_settings_screen.dart';
import 'deepseek_client.dart';
import 'deepseek_prompts.dart';
import 'personal_ai_providers.dart';

class PersonalAiSettingsScreen extends ConsumerStatefulWidget {
  const PersonalAiSettingsScreen({super.key});

  @override
  ConsumerState<PersonalAiSettingsScreen> createState() =>
      _PersonalAiSettingsScreenState();
}

class _PersonalAiSettingsScreenState
    extends ConsumerState<PersonalAiSettingsScreen> {
  final _keyController = TextEditingController();
  final _modelController = TextEditingController(text: 'deepseek-flash');
  bool _initialized = false;
  bool _enabled = false;
  bool _busy = false;
  bool _obscureKey = true;
  String? _message;
  CancelToken? _testCancellation;

  @override
  void dispose() {
    _testCancellation?.cancel('settings closed');
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  PersonalAiSettings get _draft => PersonalAiSettings(
    enabled: _enabled,
    apiKey: _keyController.text.trim(),
    model: _modelController.text.trim(),
  );

  /// 测试只发起一条短翻译请求，不保存密钥；错误信息不包含请求原文或密钥。
  Future<void> _test() async {
    final draft = _draft;
    if (draft.apiKey.isEmpty || draft.model.isEmpty) {
      setState(() => _message = '请先填写 API Key 和模型名称。');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final client = DeepSeekClient(apiKey: draft.apiKey, model: draft.model);
    final cancellation = CancelToken();
    _testCancellation = cancellation;
    try {
      final result = await client.runTask(DeepSeekTask.translation, {
        'text': 'Hello!',
        'targetLanguage': 'zh-CN',
      }, cancelToken: cancellation);
      if (mounted) setState(() => _message = '连接成功：${result['translation']}');
    } on DeepSeekException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) setState(() => _message = '连接失败，请检查网络后重试。');
    } finally {
      client.dispose();
      _testCancellation = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(personalAiSettingsProvider.notifier).save(_draft);
      if (mounted) setState(() => _message = '已保存。新的文本 AI 请求将使用此配置。');
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) setState(() => _message = '安全存储写入失败，配置未保存，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(personalAiSettingsProvider);
    final saved = settings.valueOrNull;
    if (!_initialized && saved != null) {
      _initialized = true;
      _enabled = saved.enabled;
      _keyController.text = saved.apiKey;
      _modelController.text = saved.model;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('个人 AI · DeepSeek')),
      body: settings.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (settings.hasError) const Text('无法读取已保存配置。可以重新填写并保存。'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('使用我的 DeepSeek 服务'),
                  subtitle: const Text('翻译、句子解析、意群划分、AI 词典、对话助手'),
                  value: _enabled,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _enabled = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _keyController,
                  enabled: !_busy,
                  obscureText: _obscureKey,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'DeepSeek API Key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscureKey ? '显示密钥' : '隐藏密钥',
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                      icon: Icon(
                        _obscureKey ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _modelController,
                  enabled: !_busy,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '模型名称',
                    helperText: '填写你的 DeepSeek API 账户可用的模型 ID。',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '请求直接发往 api.deepseek.com，按你的 DeepSeek API 账户计费。'
                  '密钥保存在本机安全存储中。测试连接会产生一条短翻译请求。',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _busy ? null : _test,
                      child: const Text('测试连接'),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: const Text('保存配置'),
                    ),
                  ],
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (_message case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(message),
                  ),
                const Divider(height: 40),
                const Text(
                  '字幕转录',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '字幕使用本地 Whisper 语音识别，不经过 DeepSeek。'
                  '启用个人 AI 后，在材料的“管理字幕”中选择“离线转录”。'
                  '首次使用需下载模型；长音频的耗时和准确率取决于设备与模型。',
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AsrSettingsScreen(),
                    ),
                  ),
                  child: const Text('管理语音识别模型'),
                ),
              ],
            ),
    );
  }
}
