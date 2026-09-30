import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/presenter/widgets/common/app_exit_guard.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_dialog.dart';

void main() {
  const strings = <String, String>{
    'appExitTitle': '앱 종료',
    'appExitMessage': '가계부 앱을 종료하시겠습니까?',
    'appExitConfirm': '종료',
    'cancel': '취소',
  };

  testWidgets('최상위 뒤로가기에서 취소하면 앱을 종료하지 않는다', (tester) async {
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppExitGuard(
          strings: strings,
          exitApp: () async => exited = true,
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(BootstrapDialog), findsOneWidget);
    expect(find.text('가계부 앱을 종료하시겠습니까?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(exited, isFalse);
  });

  testWidgets('종료 확인 후 사전 작업을 마치고 앱을 종료한다', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: AppExitGuard(
          strings: strings,
          onBeforeExit: () async => calls.add('beforeExit'),
          exitApp: () async => calls.add('exit'),
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('종료'));
    await tester.pumpAndSettle();

    expect(calls, <String>['beforeExit', 'exit']);
    expect(find.byType(BootstrapDialog), findsNothing);
  });

  testWidgets('확인창이 열린 상태의 뒤로가기는 앱을 종료하지 않는다', (tester) async {
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppExitGuard(
          strings: strings,
          exitApp: () async => exited = true,
          child: const Scaffold(body: Text('home')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BootstrapDialog), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(BootstrapDialog), findsNothing);
    expect(exited, isFalse);
  });
}
