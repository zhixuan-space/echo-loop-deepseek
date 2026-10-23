import 'package:echo_loop/features/personal_ai/personal_ai_providers.dart';
import 'package:echo_loop/features/personal_ai/personal_ai_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Storage extends Mock implements FlutterSecureStorage {}

void main() {
  testWidgets('配置页默认隐藏密钥；保存后才启用个人服务', (tester) async {
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PersonalAiSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.first).obscureText, isTrue);
    await tester.enterText(fields.first, 'synthetic-secret');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(container.read(personalAiEnabledProvider), isFalse);
    await tester.ensureVisible(find.text('保存配置'));
    await tester.tap(find.text('保存配置'));
    await tester.pumpAndSettle();
    expect(container.read(personalAiEnabledProvider), isTrue);
    expect(find.textContaining('已保存'), findsOneWidget);
    verify(
      () => storage.write(
        key: PersonalAiSettingsController.storageKey,
        value: any(named: 'value'),
      ),
    ).called(1);
  });

  testWidgets('启用时缺少密钥显示错误并保持停用', (tester) async {
    final storage = _Storage();
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    final container = ProviderContainer(
      overrides: [personalAiStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PersonalAiSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存配置'));
    await tester.tap(find.text('保存配置'));
    await tester.pumpAndSettle();
    expect(find.text('请填写 DeepSeek API Key 和模型名称。'), findsOneWidget);
    expect(container.read(personalAiEnabledProvider), isFalse);
    verifyNever(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
  });
}
