// """ MVVM 계층: Model / Calculation Feature """
// """ 역할: 분석 도넛 분류와 일별 지출·수입 시계열을 계산 """
// """ 규칙: 차트 라이브러리와 표현용 라벨·색상에 의존하지 않음 """

import 'package:household_ledger/features/analysis/models/analysis_series_result.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';

class AnalysisSeriesCalculator {
  const AnalysisSeriesCalculator();

  static const String fixedExpenseCode = '__fixed__';

  int expenseTotal(Iterable<ExpenseEntry> expenses) => expenses.fold<int>(
    0,
    (int total, ExpenseEntry entry) => total + entry.amount,
  );

  int fixedExpenseTotal(Iterable<FixedExpense> fixedExpenses) => fixedExpenses
      .fold<int>(0, (int total, FixedExpense entry) => total + entry.amount);

  Map<String, int> categoryTotals(Iterable<ExpenseEntry> expenses) =>
      Map<String, int>.unmodifiable(
        _expenseSums(expenses, (ExpenseEntry entry) => entry.categoryCode),
      );

  List<AnalysisBreakdownItem> categoryBreakdown({
    required Iterable<ExpenseEntry> expenses,
    required Iterable<FixedExpense> fixedExpenses,
  }) {
    final sums = _expenseSums(
      expenses,
      (ExpenseEntry entry) => entry.categoryCode,
    );
    final fixedTotal = fixedExpenseTotal(fixedExpenses);
    if (fixedTotal > 0) sums[fixedExpenseCode] = fixedTotal;
    return _toBreakdown(sums);
  }

  List<AnalysisBreakdownItem> subcategoryBreakdown(
    Iterable<ExpenseEntry> expenses,
  ) => _toBreakdown(
    _expenseSums(expenses, (ExpenseEntry entry) => entry.subcategoryCode),
  );

  List<AnalysisBreakdownItem> paymentMethodBreakdown(
    Iterable<ExpenseEntry> expenses,
  ) => _toBreakdown(
    _expenseSums(expenses, (ExpenseEntry entry) => entry.paymentMethodCode),
  );

  List<AnalysisBreakdownItem> diningOccasionBreakdown(
    Iterable<ExpenseEntry> expenses,
  ) {
    return _toBreakdown(
      _expenseSums(
        expenses.where((ExpenseEntry entry) => entry.categoryCode == 'F'),
        (ExpenseEntry entry) => entry.diningOccasionCode ?? '',
      ),
    );
  }

  List<DailyAmountPoint> dailyExpenses(
    Iterable<ExpenseEntry> expenses,
    DateTime rangeStart,
  ) => _dailyAmounts(
    values: expenses,
    rangeStart: rangeStart,
    dateOf: (ExpenseEntry entry) => entry.spentAt,
    amountOf: (ExpenseEntry entry) => entry.amount,
  );

  List<DailyAmountPoint> dailyIncomes(
    Iterable<IncomeEntry> incomes,
    DateTime rangeStart,
  ) => _dailyAmounts(
    values: incomes,
    rangeStart: rangeStart,
    dateOf: (IncomeEntry entry) => entry.earnedAt,
    amountOf: (IncomeEntry entry) => entry.amount,
  );

  int incomeTotal(Iterable<IncomeEntry> incomes) => incomes.fold<int>(
    0,
    (int total, IncomeEntry entry) => total + entry.amount,
  );

  Map<String, int> _expenseSums(
    Iterable<ExpenseEntry> expenses,
    String Function(ExpenseEntry entry) codeOf,
  ) {
    final sums = <String, int>{};
    for (final entry in expenses) {
      final code = codeOf(entry);
      if (code.isEmpty) continue;
      sums.update(
        code,
        (int value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    return sums;
  }

  List<AnalysisBreakdownItem> _toBreakdown(Map<String, int> sums) {
    final total = sums.values.fold<int>(0, (int sum, int value) => sum + value);
    if (total == 0) return const <AnalysisBreakdownItem>[];
    final sorted = sums.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));
    return List<AnalysisBreakdownItem>.unmodifiable(
      sorted.map(
        (entry) => AnalysisBreakdownItem(
          code: entry.key,
          amount: entry.value,
          percentage: entry.value / total * 100,
        ),
      ),
    );
  }

  List<DailyAmountPoint> _dailyAmounts<T>({
    required Iterable<T> values,
    required DateTime rangeStart,
    required DateTime Function(T value) dateOf,
    required int Function(T value) amountOf,
  }) {
    final base = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final daily = <int, int>{};
    for (final value in values) {
      final date = dateOf(value);
      final offset =
          DateTime(date.year, date.month, date.day).difference(base).inDays + 1;
      if (offset < 1) continue;
      daily.update(
        offset,
        (int amount) => amount + amountOf(value),
        ifAbsent: () => amountOf(value),
      );
    }
    final sortedDays = daily.keys.toList(growable: false)..sort();
    return List<DailyAmountPoint>.unmodifiable(
      sortedDays.map(
        (int day) => DailyAmountPoint(dayOffset: day, amount: daily[day]!),
      ),
    );
  }
}
