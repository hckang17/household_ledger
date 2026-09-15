import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_dialog.dart';
import 'package:household_ledger/presenter/widgets/common/ledger_dialogs.dart';

void main() {
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
