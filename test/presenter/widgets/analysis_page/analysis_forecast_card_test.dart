import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/analysis_forecast_card.dart';

void main() {
  for (final language in ['ko', 'jp']) {
    final strings = Map<String, String>.from(
      jsonDecode(File('assets/language_data/$language.json').readAsStringSync())
          as Map,
    );
    testWidgets(
      '$language: small screen, empty state, actual/projected lines and visibility',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Future<void> pump({
          bool range = false,
          int month = 1,
          int day = 3,
          int amount = 0,
        }) async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: Scaffold(
                  body: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(1.8),
                    ),
                    child: SingleChildScrollView(
                      child: AnalysisForecastCard(
                        input: (
                          expenses: amount == 0
                              ? <ExpenseEntry>[]
                              : [
                                  ExpenseEntry.create(
                                    spentAt: DateTime(2026, 1, 1),
                                    categoryCode: 'F',
                                    description: '',
                                    amount: amount,
                                  ),
                                ],
                          selectedMonth: DateTime(2026, month),
                          usingRange: range,
                          today: DateTime(2026, 1, day),
                        ),
                        strings: strings,
                        currency: language == 'ko' ? '원' : '円',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await pump();
        expect(find.text(strings['forecastNoSpending']!), findsOneWidget);
        final chart = tester.widget<LineChart>(find.byType(LineChart)).data;
        expect(chart.lineBarsData[0].dashArray, isNull);
        expect(chart.lineBarsData[1].dashArray, [6, 4]);
        expect(chart.titlesData.leftTitles.sideTitles.showTitles, isTrue);
        expect(chart.titlesData.leftTitles.sideTitles.interval, greaterThan(0));
        expect(chart.lineTouchData.handleBuiltInTouches, isFalse);
        final todaySpot =
            chart.showingTooltipIndicators.single.showingSpots.single;
        expect(todaySpot.x, 3);
        expect(todaySpot.y, 0);
        final tooltip = chart.lineTouchData.touchTooltipData.getTooltipItems([
          todaySpot,
        ]).single!;
        expect(tooltip.text, contains(strings['forecastCumulativeSpending']!));
        expect(tooltip.text, contains('1/3'));
        expect(
          chart.lineBarsData[0].spots.last,
          chart.lineBarsData[1].spots.first,
        );
        await pump(day: 31, amount: 3100);
        final monthEndChart = tester
            .widget<LineChart>(find.byType(LineChart))
            .data;
        expect(
          monthEndChart.showingTooltipIndicators.single.showingSpots.single.y,
          3100,
        );
        expect(
          tester
              .widget<LineChart>(find.byType(LineChart))
              .data
              .lineBarsData
              .length,
          1,
        );
        await pump(day: 1, amount: 1234567);
        final firstDayChart = tester
            .widget<LineChart>(find.byType(LineChart))
            .data;
        expect(
          firstDayChart.showingTooltipIndicators.single.showingSpots.single.x,
          1,
        );
        expect(
          firstDayChart.maxY,
          greaterThan(firstDayChart.lineBarsData.last.spots.last.y),
        );
        await pump(range: true);
        expect(find.byType(LineChart), findsNothing);
        await pump(month: 12);
        expect(find.byType(LineChart), findsNothing);
      },
    );
  }
}
