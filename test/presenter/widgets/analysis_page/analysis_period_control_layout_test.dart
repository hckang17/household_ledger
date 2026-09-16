import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/analysis_period_control_card.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/analysis_scope_control.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja'));
  final Map<String, String> japanese = Map<String, String>.from(
    jsonDecode(File('assets/language_data/jp.json').readAsStringSync()) as Map,
  );

  testWidgets('Japanese month controls remain operable at 320dp and 1.3 text', (
    WidgetTester tester,
  ) async {
    var previousCount = 0;
    var nextCount = 0;
    await _pumpControls(
      tester,
      size: const Size(320, 568),
      textScale: 1.3,
      child: AnalysisPeriodControlCard(
        showExpense: true,
        isRangeMode: false,
        selectedMonth: DateTime(2026, 9),
        selectedRange: null,
        periodSubtitle: '2026年9月の分析',
        localeCode: 'jp',
        strings: japanese,
        onTabChanged: (_) {},
        onMonthPrev: () => previousCount++,
        onMonthNext: () => nextCount++,
        onMonthChanged: (_) {},
        onRangeChanged: (_) {},
        onModeChanged: (_) {},
      ),
    );

    expect(find.text('09.01 - 09.30'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(previousCount, 1);
    expect(nextCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Japanese range and scope controls adapt at 360dp and 1.8 text', (
    WidgetTester tester,
  ) async {
    var selectedTravel = false;
    await _pumpControls(
      tester,
      size: const Size(360, 640),
      textScale: 1.8,
      child: Column(
        children: <Widget>[
          AnalysisScopeControl(
            isTravel: false,
            strings: japanese,
            onChanged: (value) => selectedTravel = value,
          ),
          const SizedBox(height: 12),
          AnalysisPeriodControlCard(
            showExpense: true,
            isRangeMode: true,
            selectedMonth: DateTime(2026, 9),
            selectedRange: DateTimeRange(
              start: DateTime(2026, 9, 1),
              end: DateTime(2026, 9, 30),
            ),
            periodSubtitle: '選択した期間の分析',
            localeCode: 'jp',
            strings: japanese,
            onTabChanged: (_) {},
            onMonthPrev: () {},
            onMonthNext: () {},
            onMonthChanged: (_) {},
            onRangeChanged: (_) {},
            onModeChanged: (_) {},
          ),
        ],
      ),
    );

    expect(find.text('09.01 - 09.30'), findsOneWidget);
    await tester.tap(find.text(japanese['analysisTravelScope']!));
    expect(selectedTravel, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpControls(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required Widget child,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
