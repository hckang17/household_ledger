import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/presenter/widgets/fixed_expense_page/month_navigator_bar.dart';

void main() {
  testWidgets('320dp 큰 글자에서도 월 이동 버튼의 이름과 48dp 영역을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.8),
          ),
          child: Scaffold(
            body: MonthNavigatorBar(
              displayText: '2026年 09月',
              previousLabel: '前の月',
              nextLabel: '次の月',
              selectLabel: '月を選択',
              onPrevious: () {},
              onNext: () {},
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('前の月'), findsOneWidget);
    expect(find.byTooltip('次の月'), findsOneWidget);
    expect(find.bySemanticsLabel('月を選択: 2026年 09月'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('前の月')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byTooltip('次の月')).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}
