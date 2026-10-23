import 'dart:convert';

import 'package:echo_loop/features/auth/providers/auth_providers.dart';
import 'package:echo_loop/features/personal_ai/personal_ai_providers.dart';
import 'package:echo_loop/features/subscription/models/premium_feature.dart';
import 'package:echo_loop/features/subscription/providers/feature_access_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Storage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('新安装默认关闭；只有启用、密钥和模型齐全时才接管文本请求', () {
    expect(const PersonalAiSettings().isReady, isFalse);
    expect(const PersonalAiSettings(enabled: true).isReady, isFalse);
    expect(
      const PersonalAiSettings(enabled: true, apiKey: 'key', model: '').isReady,
      isFalse,
    );
    expect(
      const PersonalAiSettings(enabled: true, apiKey: 'key').isReady,
      isTrue,
    );
  });

  test('个人服务允许未登录用户使用五项文本功能，不授权官方音频能力', () {
    final container = ProviderContainer(
      overrides: [
        personalAiEnabledProvider.overrideWithValue(true),
        isAuthenticatedProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    for (final feature in PremiumFeature.values) {
      expect(
        container.read(featureAccessProvider(feature)),
        personalAiSupports(feature),
        reason: feature.name,
      );
    }
    expect(
      container.read(textAiAccessTokenProvider),
      'personal-ai-local-session',
    );
  });

  test('安全存储写入成功才切换配置，写入失败保留旧配置', () async {
    final storage = _Storage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    final container = ProviderContainer(
      overrides: [personalAiStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await container.read(personalAiSettingsProvider.future);
    const configured = PersonalAiSettings(
      enabled: true,
      apiKey: 'synthetic-key',
    );
    await container.read(personalAiSettingsProvider.notifier).save(configured);
    expect(container.read(personalAiEnabledProvider), isTrue);
    verify(
      () => storage.write(
        key: PersonalAiSettingsController.storageKey,
        value: jsonEncode(configured.toJson()),
      ),
    ).called(1);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenThrow(Exception('storage unavailable'));
    await expectLater(
      container
          .read(personalAiSettingsProvider.notifier)
          .save(const PersonalAiSettings()),
      throwsException,
    );
    expect(container.read(personalAiEnabledProvider), isTrue);
  });

  test('损坏配置明确报错，重新保存后可以恢复', () async {
    final storage = _Storage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => 'corrupt');
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    final container = ProviderContainer(
      overrides: [personalAiStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(personalAiSettingsProvider.future),
      throwsFormatException,
    );
    expect(container.read(personalAiEnabledProvider), isFalse);
    await container
        .read(personalAiSettingsProvider.notifier)
        .save(const PersonalAiSettings(enabled: true, apiKey: 'new-key'));
    expect(container.read(personalAiEnabledProvider), isTrue);
  });

  test('缺密钥的启用操作不写入安全存储', () async {
    final storage = _Storage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    final container = ProviderContainer(
      overrides: [personalAiStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await container.read(personalAiSettingsProvider.future);
    await expectLater(
      container
          .read(personalAiSettingsProvider.notifier)
          .save(const PersonalAiSettings(enabled: true)),
      throwsFormatException,
    );
    verifyNever(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
  });
}
