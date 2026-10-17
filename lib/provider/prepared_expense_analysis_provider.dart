import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/features/analysis/calculators/prepare_expense_analysis.dart';
import 'package:household_ledger/features/analysis/models/prepared_expense_analysis.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'ledger_provider.dart';

/// Date-only values keep the family key stable during UI rebuilds.
typedef ExpenseAnalysisQuery = ({
  DateTime start,
  DateTime end,
  DateTime previousStart,
  DateTime previousEnd,
  DateTime today,
  bool usingRange,
});

typedef ExpenseAnalysisRunner =
    Future<PreparedExpenseAnalysis> Function(ExpenseAnalysisRequest request);

/// Overridable worker for deterministic loading/error and race tests.
final expenseAnalysisRunnerProvider = Provider<ExpenseAnalysisRunner>(
  (ref) =>
      (request) => compute(
        prepareExpenseAnalysis,
        request,
        debugLabel: 'expense-analysis',
      ),
);

/// A single readiness state for current, comparison, budget and calculations.
final preparedExpenseAnalysisProvider = FutureProvider.autoDispose
    .family<PreparedExpenseAnalysis, ExpenseAnalysisQuery>((ref, query) async {
      final current = query.usingRange
          ? rangeExpensesProvider(
              ExpenseRangeQuery(start: query.start, endInclusive: query.end),
            )
          : monthlyExpensesProvider(query.start);
      // Subscribe before awaiting so all IO starts together and invalidation of any
      // dependency replaces the whole snapshot, never mixing periods.
      final expensesFuture = ref.watch(current.future);
      final previousFuture = ref.watch(
        rangeExpensesProvider(
          ExpenseRangeQuery(
            start: query.previousStart,
            endInclusive: query.previousEnd,
          ),
        ).future,
      );
      final incomesFuture = ref.watch(
        monthlyIncomesProvider(
          DateTime(query.start.year, query.start.month),
        ).future,
      );
      final ledgerFuture = ref.watch(ledgerProvider.future);
      final runner = ref.watch(expenseAnalysisRunnerProvider);
      final (expenses, previous, incomes, ledger) = await (
        expensesFuture,
        previousFuture,
        incomesFuture,
        ledgerFuture,
      ).wait;
      // Disposed requests must not start an expensive worker after delayed IO.
      if (!ref.mounted) throw StateError('Analysis request disposed');
      final incomeTotal = incomes.fold<int>(
        0,
        (sum, item) => sum + item.amount,
      );
      return runner((
        expenses: expenses,
        previousExpenses: previous,
        fixedExpenses: ledger.fixedExpenses,
        diningOccasionCodes: ledger
            .tagsByType(MetadataTagType.diningOccasion)
            .map((tag) => tag.code)
            .toList(growable: false),
        start: query.start,
        end: query.end,
        previousStart: query.previousStart,
        today: query.today,
        usingRange: query.usingRange,
        budget: incomeTotal > 0 ? incomeTotal : ledger.settings.monthlyBudget,
      ));
    });

/// Explicit retry also retries failed source reads, not just the calculation.
void retryExpenseAnalysis(WidgetRef ref, ExpenseAnalysisQuery query) {
  if (query.usingRange) {
    ref.invalidate(
      rangeExpensesProvider(
        ExpenseRangeQuery(start: query.start, endInclusive: query.end),
      ),
    );
  } else {
    ref.invalidate(monthlyExpensesProvider(query.start));
  }
  ref.invalidate(
    rangeExpensesProvider(
      ExpenseRangeQuery(
        start: query.previousStart,
        endInclusive: query.previousEnd,
      ),
    ),
  );
  ref.invalidate(
    monthlyIncomesProvider(DateTime(query.start.year, query.start.month)),
  );
  ref.invalidate(preparedExpenseAnalysisProvider(query));
}
