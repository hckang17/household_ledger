import 'package:test/test.dart';
import 'package:household_ledger/features/analysis/calculators/deep_analysis_calculator.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';

ExpenseEntry entry(DateTime date, int amount) => ExpenseEntry.create(
  spentAt: date,
  categoryCode: 'F',
  description: 'test',
  amount: amount,
);
void main() {
  test(
    'current month uses same-day history, excludes future, includes registered fixed',
    () {
      final r = calculateDeepAnalysis((
        month: DateTime(2026, 10),
        today: DateTime(2026, 10, 10),
        expenses: [
          entry(DateTime(2026, 9, 1), 100),
          entry(DateTime(2026, 9, 11), 900),
          entry(DateTime(2026, 10, 10, 23), 200),
          entry(DateTime(2026, 10, 11), 800),
        ],
        fixedExpenses: [
          FixedExpense.create(
            appliedAt: DateTime(2026, 10, 20),
            categoryCode: 'L',
            description: 'fixed',
            amount: 300,
          ),
        ],
      ));
      expect(r.total, 500);
      expect(r.baselines.first.average, 100);
      expect(r.baselines.first.difference, 400);
      expect(r.largeExpenses.single.amount, 200);
      expect(r.largeExpenses.single.recordId, isNotNull);
      expect(r.topShare, 40);
      expect(r.withoutTop, 300);
      expect(r.asOf, DateTime(2026, 10, 10));
    },
  );
  test(
    'January, missing months, rounding contributions and immutable collections',
    () {
      final r = calculateDeepAnalysis((
        month: DateTime(2026, 1),
        today: DateTime(2026, 10, 10),
        expenses: [
          entry(DateTime(2025, 10, 1), 10),
          entry(DateTime(2026, 1, 31), 20),
        ],
        fixedExpenses: <FixedExpense>[],
      ));
      final baseline = r.baselines[1];
      expect(baseline.average, 3);
      expect(
        baseline.changes.fold<int>(0, (s, e) => s + e.amount),
        baseline.difference,
      );
      expect(r.baselines[2].average, isNull);
      expect(r.trend.map((e) => e.amount), [10, 0, 0, 20]);
      expect(() => r.trend.clear(), throwsUnsupportedError);
      expect(r.asOf, isNull);
    },
  );
  test('leap month and shorter comparison months include their last day', () {
    final r = calculateDeepAnalysis((
      month: DateTime(2024, 3),
      today: DateTime(2024, 3, 31),
      expenses: [
        entry(DateTime(2024, 2, 29), 50),
        entry(DateTime(2024, 3, 31), 80),
      ],
      fixedExpenses: <FixedExpense>[],
    ));
    expect(r.baselines.first.average, 50);
    expect(r.total, 80);
  });
  test('empty and fixed-only snapshots remain finite', () {
    final r = calculateDeepAnalysis((
      month: DateTime(2026, 1),
      today: DateTime(2026, 2),
      expenses: <ExpenseEntry>[],
      fixedExpenses: <FixedExpense>[],
    ));
    expect(r.trend, isEmpty);
    expect(r.topShare, 0);
    expect(r.baselines.every((b) => b.average == null), isTrue);
    final fixed = calculateDeepAnalysis((
      month: DateTime(2026, 1),
      today: DateTime(2026, 2),
      expenses: <ExpenseEntry>[],
      fixedExpenses: [
        FixedExpense.create(
          appliedAt: DateTime(2026, 1),
          categoryCode: 'L',
          description: '',
          amount: 50,
        ),
      ],
    ));
    expect(fixed.total, 50);
    expect(fixed.fixedShare, 100);
    expect(fixed.largeExpenses, isEmpty);
  });
}
