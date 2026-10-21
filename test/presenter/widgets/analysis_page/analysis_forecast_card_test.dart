import 'dart:convert';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
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
          int fixedAmount = 0,
          AsyncValue<int> budget = const AsyncData(0),
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
                        monthlyBudget: budget,
                        input: (
                          fixedExpenses: [
                            FixedExpense.create(
                              appliedAt: DateTime(2026, 1),
                              categoryCode: 'L',
                              description: '',
                              amount: fixedAmount,
                            ),
                          ],
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
        expect(find.text(strings['forecastNoSpending']!), findsNothing);
        expect(find.text(strings['forecastExplanation']!), findsNothing);
        expect(
          tester
              .widget<Text>(find.text(strings['forecastTitle']!))
              .style
              ?.fontWeight,
          FontWeight.w700,
        );
        for (final key in [
          'forecastActual',
          'forecastFixed',
          'forecastAverage',
          'forecastRemaining',
          'forecastMonthEnd',
          'forecastLegend',
        ]) {
          expect(
            tester.getTopLeft(find.text(strings[key]!)).dy,
            greaterThanOrEqualTo(
              tester.getBottomLeft(find.byType(LineChart)).dy,
            ),
          );
        }
        await tester.tap(find.byIcon(Icons.help_outline_rounded));
        await tester.pumpAndSettle();
        expect(
          find.text(
            '${strings['forecastExplanation']}\n\n${strings['forecastNoSpending']}',
          ),
          findsOneWidget,
        );
        Tooltip.dismissAllToolTips();
        await tester.pumpAndSettle();
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
        await pump(
          amount: 300,
          fixedAmount: 1000,
          budget: const AsyncData(100000),
        );
        final budgetChart = tester
            .widget<LineChart>(find.byType(LineChart))
            .data;
        expect(budgetChart.extraLinesData.horizontalLines.single.y, 100000);
        expect(
          budgetChart.extraLinesData.horizontalLines.single.strokeWidth,
          3,
        );
        expect(budgetChart.maxY, greaterThan(100000));
        expect(
          budgetChart.showingTooltipIndicators.single.showingSpots.single.y,
          1300,
        );
        await pump(amount: 300, budget: const AsyncData(50));
        expect(
          tester
              .widget<LineChart>(find.byType(LineChart))
              .data
              .extraLinesData
              .horizontalLines
              .single
              .y,
          50,
        );
        await pump(budget: const AsyncLoading());
        expect(find.text(strings['forecastBudgetLoading']!), findsOneWidget);
        expect(
          tester
              .widget<LineChart>(find.byType(LineChart))
              .data
              .extraLinesData
              .horizontalLines,
          isEmpty,
        );
        await pump(
          budget: AsyncError(StateError('budget failed'), StackTrace.empty),
        );
        expect(find.text(strings['forecastBudgetError']!), findsOneWidget);
        await pump();
        expect(
          tester
              .widget<LineChart>(find.byType(LineChart))
              .data
              .extraLinesData
              .horizontalLines,
          isEmpty,
        );
        await pump(month: 12);
        expect(find.byType(LineChart), findsNothing);
      },
    );
  }
}
