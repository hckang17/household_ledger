import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/features/analysis/calculators/prepare_expense_analysis.dart';
import 'package:household_ledger/features/analysis/models/prepared_expense_analysis.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/presenter/pages/expense_page/analysis_page.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/analysis_donut_chart.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/analysis_expense_tab.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/analysis_forecast_card.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/prepared_expense_analysis_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

class FakeLedger extends LedgerNotifier {
  @override
  Future<LedgerState> build() async => LedgerState.initial();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko');
    await initializeDateFormatting('ja');
  });
  for (final language in ['ko', 'jp']) {
    final strings = Map<String, String>.from(
      jsonDecode(File('assets/language_data/$language.json').readAsStringSync())
          as Map,
    );
    testWidgets(
      '$language: loading, error, retry, scroll and local chart touch',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var runs = 0;
        final worker = Completer<PreparedExpenseAnalysis>();
        ExpenseAnalysisRequest? request;
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            ledgerProvider.overrideWith(FakeLedger.new),
            localizedStringsProvider.overrideWithValue(strings),
            monthlyExpensesProvider.overrideWith(
              (ref, month) async => [
                ExpenseEntry.create(
                  spentAt: month,
                  categoryCode: 'F',
                  description: '',
                  amount: 300,
                ),
              ],
            ),
            rangeExpensesProvider.overrideWith((ref, query) async => []),
            monthlyIncomesProvider.overrideWith((ref, month) async => []),
            expenseAnalysisRunnerProvider.overrideWithValue((input) async {
              runs++;
              request = input;
              if (runs == 1) return worker.future;
              return prepareExpenseAnalysis(input);
            }),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
                child: const AnalysisPage(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text(strings['analysisProcessing']!), findsOneWidget);
        expect(find.byType(AnalysisExpenseTabSection), findsNothing);
        expect(request, isNotNull);
        worker.completeError(StateError('worker failed'));
        await tester.pump();
        await tester.pump();
        expect(find.text(strings['analysisProcessingError']!), findsOneWidget);
        await tester.ensureVisible(
          find.text(strings['analysisProcessingRetry']!),
        );
        await tester.tap(find.text(strings['analysisProcessingRetry']!));
        await tester.pumpAndSettle();
        expect(find.byType(AnalysisExpenseTabSection), findsOneWidget);
        expect(runs, 2);
        final forecastBefore = tester.widget<AnalysisForecastView>(
          find.byType(AnalysisForecastView),
        );
        final donutBefore = tester.widget<AnalysisDonutChart>(
          find.byType(AnalysisDonutChart),
        );
        donutBefore.onTouchUpdate(0);
        await tester.pump();
        expect(
          tester
              .widget<AnalysisDonutChart>(find.byType(AnalysisDonutChart))
              .touchedIndex,
          0,
        );
        expect(
          tester.widget<AnalysisForecastView>(
            find.byType(AnalysisForecastView),
          ),
          same(forecastBefore),
        );
        expect(runs, 2);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -1400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
