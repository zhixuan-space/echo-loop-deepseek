/// 个人 AI 配置与文本请求上下文；不修改账号或官方会员状态。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/providers/auth_providers.dart';
import '../auth/sign_in_required_dialog.dart';
import '../subscription/models/premium_feature.dart';
import 'deepseek_client.dart';

/// 密钥与启用状态只保存到本机安全存储，不进入偏好备份、账号同步或编译产物。
class PersonalAiSettings {
  const PersonalAiSettings({
    this.enabled = false,
    this.apiKey = '',
    this.model = 'deepseek-flash',
  });

  final bool enabled;
  final String apiKey;
  final String model;
  bool get isReady =>
      enabled && apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'apiKey': apiKey,
    'model': model,
  };

  factory PersonalAiSettings.fromJson(Map<String, Object?> json) =>
      PersonalAiSettings(
        enabled: json['enabled'] == true,
        apiKey: switch (json['apiKey']) {
          final String key => key,
          _ => '',
        },
        model: switch (json['model']) {
          final String model when model.trim().isNotEmpty => model,
          _ => 'deepseek-flash',
        },
      );
}

final personalAiStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final personalAiSettingsProvider =
    AsyncNotifierProvider<PersonalAiSettingsController, PersonalAiSettings>(
      PersonalAiSettingsController.new,
    );

/// 配置读取失败显式进入错误态；保存成功后才切换请求路由。
class PersonalAiSettingsController extends AsyncNotifier<PersonalAiSettings> {
  static const storageKey = 'personal_deepseek_settings_v1';

  @override
  Future<PersonalAiSettings> build() async {
    final raw = await ref.read(personalAiStorageProvider).read(key: storageKey);
    if (raw == null) return const PersonalAiSettings();
    final value = jsonDecode(raw);
    if (value is! Map<String, Object?>) {
      throw const FormatException('个人 AI 配置损坏，请重新保存。');
    }
    return PersonalAiSettings.fromJson(value);
  }

  /// 密钥可留空保存为停用配置；启用时必须填写密钥和模型名称。
  Future<void> save(PersonalAiSettings settings) async {
    if (settings.enabled && !settings.isReady) {
      throw const FormatException('请填写 DeepSeek API Key 和模型名称。');
    }
    await ref
        .read(personalAiStorageProvider)
        .write(key: storageKey, value: jsonEncode(settings.toJson()));
    state = AsyncData(settings);
  }
}

final personalAiEnabledProvider = Provider<bool>(
  (ref) => ref.watch(personalAiSettingsProvider).valueOrNull?.isReady ?? false,
);

/// 仅五类文本功能由 DeepSeek 接管；音频评估和官方云端转录仍使用原有链路。
bool personalAiSupports(PremiumFeature feature) => switch (feature) {
  PremiumFeature.aiTranslation ||
  PremiumFeature.aiAnalysis ||
  PremiumFeature.aiSenseGroup ||
  PremiumFeature.aiWordAnalysis ||
  PremiumFeature.aiChat => true,
  PremiumFeature.aiTranscription || PremiumFeature.aiRetellReview => false,
};

/// 本地会话标记只通过调用前置检查，绝不作为网络鉴权令牌发送到任何服务。
final textAiAccessTokenProvider = Provider<String?>((ref) {
  if (ref.watch(personalAiEnabledProvider)) return 'personal-ai-local-session';
  return ref.watch(supabaseSessionProvider).valueOrNull?.accessToken;
});

final personalDeepSeekClientProvider = Provider<DeepSeekClient?>((ref) {
  final settings = ref.watch(personalAiSettingsProvider).valueOrNull;
  if (settings == null || !settings.isReady) return null;
  final client = DeepSeekClient(apiKey: settings.apiKey, model: settings.model);
  ref.onDispose(client.dispose);
  return client;
});

/// 文本功能使用个人服务时不需要 Echo Loop 登录；其他操作维持原账号检查。
Future<bool> ensureTextAiAvailableForAction({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String message,
}) async {
  if (ref.read(personalAiEnabledProvider)) return true;
  return ensureSignedInForAction(
    context: context,
    ref: ref,
    title: title,
    message: message,
  );
}
