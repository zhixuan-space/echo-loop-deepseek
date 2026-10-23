# 个人 DeepSeek 服务

本分支保留 Echo Loop 的播放器、学习流程和数据结构，新增用户自带密钥的文本 AI 服务。

## 功能

| 功能 | 实现 |
| --- | --- |
| AI 翻译 | DeepSeek；可带前后句上下文，只翻译目标句 |
| 句子解析 | DeepSeek；输出语法、词汇和可能的听力难点 |
| 意群划分 | DeepSeek；中等与细粒度拆分，逐字拼接校验 |
| 单词与词组解析 | DeepSeek；兼容现有 AI 词典的数据模型 |
| 对话助手 | DeepSeek；支持上下文、多轮对话、引用、流式回答和停止 |
| 字幕转录 | 复用本地 Whisper / Sherpa ONNX；首次使用下载模型 |

个人 AI 开启后，前五项不要求 Echo Loop 账号或会员，调用费用来自用户自己的
DeepSeek API 账户。本分支不改变官方会员状态，不申请官方无限额度。

## 使用

1. 打开「设置 → 个人 AI · DeepSeek」。
2. 填写 DeepSeek API Key 和账户可用的模型 ID，开启个人服务。
3. 可点击「测试连接」发送一条短翻译请求，然后点击「保存配置」。
4. 在原有句子讲解、词典和聊天入口使用文本功能。既有缓存仍可复用；
   更换模型后，如需重新生成同一内容，可以使用应用的 AI 缓存管理功能。
5. 打开材料的「管理字幕」，选择「离线转录」，选择并下载识别模型后开始。

密钥运行时填写，保存在 `FlutterSecureStorage`，不写入源码、编译变量、偏好备份或日志。
配置默认关闭；停用后恢复原有官方服务流程。

## 构建与验证

使用满足 `pubspec.yaml` 的 Flutter / Dart 环境：

```sh
flutter pub get
dart run build_runner build
flutter run -d android
```

自带 DeepSeek 文本服务不需要配置 Supabase 或 RevenueCat。原项目其他在线功能
可能仍需要其相应服务配置。个人 API Key 在应用设置里填写，不要放进构建命令。
若调试设备是 iPhone，使用 `flutter run -d ios`；iOS 构建需要 macOS / Xcode。

针对新增服务的测试：

```sh
flutter test test/features/personal_ai
flutter test test/features/chatbot/providers/chat_session_controller_test.dart
flutter test test/services/sentence_ai_api_client_test.dart
flutter test test/widgets/manage_subtitles_sheet_test.dart
```

## 已知边界

- 结构化任务等待完整 JSON 校验后一次显示；聊天回答逐段显示。
- 模型返回空内容、截断结果或无法还原原文的意群时明确失败，不写入新缓存。
- DeepSeek 的鉴权、余额或限流错误作为个人服务错误处理，不触发官方订阅。
- 本地转录当前仅开放英文。原项目曾因效果不稳定隐藏该入口，本分支在个人 AI
  模式下恢复显示；耗时、发热、识别准确率和长音频稳定性需要在目标设备验证。
- 本地字幕没有新增云端转录提供商。若需要云端 ASR，需另外接入支持音频的服务。
- 未提供真实 DeepSeek Key 时，只能完成模拟网络测试，不能声称完成真实模型效果验收。

接口依据：[DeepSeek Chat Completions](https://api-docs.deepseek.com/api/create-chat-completion/)
和 [JSON Output](https://api-docs.deepseek.com/guides/json_mode/)。
