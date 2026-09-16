import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/presenter/widgets/expense_record_page/expense_calendar_section.dart';

void main() {
  test('weekday labels exist in both supported languages', () {
    final ko = Map<String, String>.from(
      jsonDecode(File('assets/language_data/ko.json').readAsStringSync())
          as Map,
    );
    final jp = Map<String, String>.from(
      jsonDecode(File('assets/language_data/jp.json').readAsStringSync())
          as Map,
    );
    const keys = <String>[
      'weekdaySundayShort',
      'weekdayMondayShort',
      'weekdayTuesdayShort',
      'weekdayWednesdayShort',
      'weekdayThursdayShort',
      'weekdayFridayShort',
      'weekdaySaturdayShort',
    ];
    expect(keys.map((key) => ko[key]), <String>[
      '일',
      '월',
      '화',
      '수',
      '목',
      '금',
      '토',
    ]);
    expect(keys.map((key) => jp[key]), <String>[
      '日',
      '月',
      '火',
      '水',
      '木',
      '金',
      '土',
    ]);
  });

  for (final month in [2, 9, 8]) {
    testWidgets(
      '4/5/6-week calendar: month $month selection and fold survive resize',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final strings = Map<String, String>.from(
          jsonDecode(File('assets/language_data/jp.json').readAsStringSync())
              as Map,
        );
        var selected = DateTime(2026, month, 1);
        var focused = DateTime(2026, month);
        var queried = false;
        var monthly = false;
        final lastDay = DateUtils.getDaysInMonth(2026, month);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) => ExpenseCalendarSection(
                    focusedMonth: focused,
                    selectedDay: selected,
                    entries: [],
                    currency: '¥',
                    strings: strings,
                    totalSpentLabel: '今月の支出',
                    remainingBudgetLabel: '残りの予算',
                    monthlySpent: 0,
                    monthlyRemaining: 99999999,
                    onFocusedMonthChanged: (v) => setState(() => focused = v),
                    onSelectedDayChanged: (v) => setState(() => selected = v),
                    onQueryByDate: () => queried = true,
                    onViewMonthly: () => monthly = true,
                  ),
                ),
              ),
            ),
          ),
        );
        for (final weekday in <String>['日', '月', '火', '水', '木', '金', '土']) {
          expect(find.text(weekday), findsWidgets);
        }
        expect(find.text('Sun'), findsNothing);
        await tester.ensureVisible(find.text('$lastDay'));
        await tester.tap(find.text('$lastDay'));
        await tester.pumpAndSettle();
        expect(selected, DateTime(2026, month, lastDay));
        await tester.ensureVisible(find.text(strings['queryByDate']!));
        await tester.tap(find.text(strings['queryByDate']!));
        expect(queried, isTrue);
        await tester.ensureVisible(find.text(strings['viewMonthly']!));
        await tester.tap(find.text(strings['viewMonthly']!));
        expect(monthly, isTrue);
        await tester.ensureVisible(find.byTooltip(strings['calendarFold']!));
        await tester.tap(find.byTooltip(strings['calendarFold']!));
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(640, 360);
        await tester.pumpAndSettle();
        expect(find.byTooltip(strings['calendarUnfold']!), findsOneWidget);
        await tester.ensureVisible(find.byTooltip(strings['calendarUnfold']!));
        await tester.tap(find.byTooltip(strings['calendarUnfold']!));
        await tester.pumpAndSettle();
        expect(selected, DateTime(2026, month, lastDay));
        expect(focused, DateTime(2026, month));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
