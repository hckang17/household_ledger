import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/features/analysis/calculators/prepare_expense_analysis.dart';
import 'package:household_ledger/features/analysis/models/prepared_expense_analysis.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/prepared_expense_analysis_provider.dart';

ExpenseAnalysisQuery queryFor(int month) => (
  start: DateTime(2026, month),
  end: DateTime(2026, month, 15),
  previousStart: DateTime(2026, month - 1),
  previousEnd: DateTime(2026, month - 1, 15),
  today: DateTime(2026, 1, 15),
  usingRange: false,
);

class FakeLedger extends LedgerNotifier {
  @override
  Future<LedgerState> build() async => LedgerState.initial();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final query = queryFor(1);
  final provider = preparedExpenseAnalysisProvider(query);

  test(
    'waits for comparison and budget, computes once and reuses result',
    () async {
      final previous = Completer<List<ExpenseEntry>>();
      final income = Completer<List<IncomeEntry>>();
      var runs = 0;
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWith(FakeLedger.new),
          monthlyExpensesProvider.overrideWith((ref, month) async => []),
          rangeExpensesProvider.overrideWith((ref, query) => previous.future),
          monthlyIncomesProvider.overrideWith((ref, month) => income.future),
          expenseAnalysisRunnerProvider.overrideWithValue((input) async {
            runs++;
            return prepareExpenseAnalysis(input);
          }),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final future = container.read(provider.future);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).isLoading, isTrue);
      expect(runs, 0);
      previous.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(runs, 0);
      income.complete([
        IncomeEntry.create(
          earnedAt: query.start,
          amount: 1234,
          description: '',
        ),
      ]);
      final result = await future;
      expect(result.budget, 1234);
      expect(result.previousTotal, 0);
      expect(
        await container.read(
          preparedExpenseAnalysisProvider(queryFor(1)).future,
        ),
        same(result),
      );
      expect(runs, 1);
      container.invalidate(monthlyExpensesProvider(query.start));
      await container.read(provider.future);
      expect(runs, 2);
    },
  );

  test('source failure remains error and invalidation retries', () async {
    var fail = true;
    var runs = 0;
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ledgerProvider.overrideWith(FakeLedger.new),
        monthlyExpensesProvider.overrideWith((ref, month) async => []),
        rangeExpensesProvider.overrideWith((ref, query) async {
          if (fail) throw StateError('read failed');
          return [];
        }),
        monthlyIncomesProvider.overrideWith((ref, month) async => []),
        expenseAnalysisRunnerProvider.overrideWithValue((input) async {
          runs++;
          return prepareExpenseAnalysis(input);
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(container.read(provider.future), throwsA(anything));
    expect(container.read(provider).hasError, isTrue);
    expect(runs, 0);
    fail = false;
    container.invalidate(rangeExpensesProvider);
    final result = await container.read(provider.future);
    expect(result.expenseTotal, 0);
    expect(runs, 1);
  });

  test('late old worker cannot replace new period result', () async {
    final workers = <int, Completer<PreparedExpenseAnalysis>>{};
    final inputs = <int, ExpenseAnalysisRequest>{};
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWith(FakeLedger.new),
        monthlyExpensesProvider.overrideWith((ref, month) async => []),
        rangeExpensesProvider.overrideWith((ref, query) async => []),
        monthlyIncomesProvider.overrideWith((ref, month) async => []),
        expenseAnalysisRunnerProvider.overrideWithValue((input) {
          inputs[input.start.month] = input;
          return (workers[input.start.month] = Completer()).future;
        }),
      ],
    );
    addTearDown(container.dispose);
    final first = container.listen(provider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    first.close();
    final next = preparedExpenseAnalysisProvider(queryFor(2));
    final second = container.listen(next, (_, _) {});
    addTearDown(second.close);
    final nextFuture = container.read(next.future);
    await Future<void>.delayed(Duration.zero);
    workers[2]!.complete(prepareExpenseAnalysis(inputs[2]!));
    final result = await nextFuture;
    workers[1]!.complete(prepareExpenseAnalysis(inputs[1]!));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(next).requireValue, same(result));
  });

  test('real compute worker supports native model transfer', () async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWith(FakeLedger.new),
        monthlyExpensesProvider.overrideWith(
          (ref, month) async => [
            ExpenseEntry.create(
              spentAt: month,
              categoryCode: 'F',
              description: '',
              amount: 150,
            ),
          ],
        ),
        rangeExpensesProvider.overrideWith((ref, query) async => []),
        monthlyIncomesProvider.overrideWith((ref, month) async => []),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    final result = await container.read(provider.future);
    expect(result.expenseTotal, 150);
    expect(result.food.dining.count, 1);
    expect(result.forecast!.dailyAverage, 10);
  });
}
