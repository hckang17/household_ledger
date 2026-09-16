import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_dialog.dart';
import 'package:household_ledger/presenter/widgets/common/ledger_dialogs.dart';

void main() {
  for (final cancel in [false, true]) {
    testWidgets(
      'landscape keyboard: enter text and reach ${cancel ? 'cancel' : 'save'}',
      (tester) async {
        tester.view.physicalSize = const Size(640, 360);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 244);
        tester.view.padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.view.resetPadding);
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<String>(
                      context: context,
                      builder: (context) => BootstrapDialog(
                        title: '사용자 카테고리 / カテゴリーの追加',
                        icon: Icons.add,
                        content: TextField(controller: controller),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'cancel'),
                            child: const Text('취소'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(context, controller.text),
                            child: const Text('저장'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'test category');
        await tester.pumpAndSettle();
        final action = find.text(cancel ? '취소' : '저장');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(116));
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(result, cancel ? 'cancel' : 'test category');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('공통 확인창은 작은 화면과 긴 일본어 문구에서도 정돈되어 표시된다', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => showLedgerConfirmDialog(
                context: context,
                title: '先月の固定支出データを確認します',
                message: 'この操作を続ける前に内容を確認してください。',
                confirmLabel: '確認する',
                cancelLabel: 'キャンセル',
                isDestructive: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BootstrapDialog), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    expect(find.text('確認する'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
