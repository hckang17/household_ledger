import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import '../models/deep_analysis_report.dart';
import 'analysis_series_calculator.dart';

/// A dated snapshot; current-month comparisons use the same day in each month.
typedef DeepAnalysisInput = ({
  DateTime month,
  DateTime today,
  List<ExpenseEntry> expenses,
  List<FixedExpense> fixedExpenses,
});

/// Aggregates each month once. Missing months inside observed history count as
/// zero; history before the first observed record never becomes an invented zero.
DeepAnalysisReport calculateDeepAnalysis(DeepAnalysisInput input) {
  final month = DateTime(input.month.year, input.month.month);
  final today = DateTime(input.today.year, input.today.month, input.today.day);
  if (month.isAfter(today)) throw ArgumentError('Future month');
  final partial = month.year == today.year && month.month == today.month;
  final start = DateTime(month.year, month.month - 12);
  final end = DateTime(month.year, month.month + 1);
  DateTime key(DateTime d) => DateTime(d.year, d.month);
  final regular = <DateTime, List<ExpenseEntry>>{};
  final fixed = <DateTime, List<FixedExpense>>{};
  DateTime? first;
  void observe(DateTime d) {
    final m = key(d);
    if (first == null || m.isBefore(first!)) first = m;
  }

  for (final e in input.expenses) {
    if (e.spentAt.isBefore(start) || !e.spentAt.isBefore(end)) continue;
    if (key(e.spentAt) == month &&
        e.spentAt.isAfter(
          DateTime(
            today.year,
            today.month,
            today.day + 1,
          ).subtract(const Duration(microseconds: 1)),
        )) {
      continue;
    }
    observe(e.spentAt);
    if (!partial || e.spentAt.day <= today.day) {
      (regular[key(e.spentAt)] ??= []).add(e);
    }
  }
  for (final e in input.fixedExpenses) {
    if (e.appliedAt.isBefore(start) || !e.appliedAt.isBefore(end)) continue;
    observe(e.appliedAt);
    (fixed[key(e.appliedAt)] ??= []).add(e);
  }
  const series = AnalysisSeriesCalculator();
  final totals = <DateTime, int>{};
  final fixedTotals = <DateTime, int>{};
  final categories = <DateTime, Map<String, int>>{};
  for (var i = 12; i >= 0; i--) {
    final m = DateTime(month.year, month.month - i);
    final entries = regular[m] ?? <ExpenseEntry>[];
    fixedTotals[m] = series.fixedExpenseTotal(fixed[m] ?? []);
    totals[m] = series.expenseTotal(entries) + fixedTotals[m]!;
    categories[m] = series.categoryTotals(entries);
  }
  final baselines = <DeepAnalysisBaseline>[];
  for (final n in [1, 3, 6, 12]) {
    final earliest = DateTime(month.year, month.month - n);
    if (first == null || first!.isAfter(earliest)) {
      baselines.add(DeepAnalysisBaseline(months: n));
      continue;
    }
    final sums = <String, int>{};
    var fixedSum = 0;
    for (var i = 1; i <= n; i++) {
      final m = DateTime(month.year, month.month - i);
      fixedSum += fixedTotals[m]!;
      for (final e in categories[m]!.entries) {
        sums.update(e.key, (v) => v + e.value, ifAbsent: () => e.value);
      }
    }
    final codes = {...categories[month]!.keys, ...sums.keys};
    final fixedAverage = (fixedSum / n).round();
    // Round category averages first so displayed contributions sum exactly.
    final averages = {
      for (final code in codes) code: ((sums[code] ?? 0) / n).round(),
    };
    final average = averages.values.fold(fixedAverage, (int a, b) => a + b);
    final changes = [
      for (final code in codes)
        DeepAnalysisItem(
          categoryCode: code,
          amount: (categories[month]![code] ?? 0) - averages[code]!,
        ),
      DeepAnalysisItem(
        categoryCode: AnalysisSeriesCalculator.fixedExpenseCode,
        amount: fixedTotals[month]! - fixedAverage,
      ),
    ]..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    baselines.add(
      DeepAnalysisBaseline(
        months: n,
        average: average,
        difference: totals[month]! - average,
        fixedAverage: fixedAverage,
        changes: List.unmodifiable(changes),
      ),
    );
  }
  final largest = List<ExpenseEntry>.of(regular[month] ?? [])
    ..sort((a, b) {
      final c = b.amount.compareTo(a.amount);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final top = largest.take(3).toList();
  final topTotal = series.expenseTotal(top);
  final total = totals[month]!;
  final fixedTotal = fixedTotals[month]!;
  final fixedGroups = <String, int>{};
  for (final e in fixed[month] ?? <FixedExpense>[]) {
    fixedGroups.update(
      e.categoryCode,
      (v) => v + e.amount,
      ifAbsent: () => e.amount,
    );
  }
  return DeepAnalysisReport(
    month: month,
    asOf: partial ? today : null,
    total: total,
    fixedTotal: fixedTotal,
    fixedShare: total == 0 ? 0 : fixedTotal / total * 100,
    topShare: total == 0 ? 0 : topTotal / total * 100,
    withoutTop: total - topTotal,
    baselines: List.unmodifiable(baselines),
    trend: List.unmodifiable([
      for (final m in totals.keys)
        if (first != null && !m.isBefore(first!))
          DeepAnalysisMonth(m, totals[m]!),
    ]),
    largeExpenses: List.unmodifiable([
      for (final e in top)
        DeepAnalysisItem(
          recordId: e.id,
          label: e.description,
          amount: e.amount,
          date: e.spentAt,
        ),
    ]),
    fixedBreakdown: List.unmodifiable([
      for (final e in fixedGroups.entries)
        DeepAnalysisItem(
          categoryCode: e.key,
          amount: e.value,
          share: fixedTotal == 0 ? 0 : e.value / fixedTotal * 100,
        ),
    ]),
  );
}
