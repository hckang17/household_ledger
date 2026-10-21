import 'package:household_ledger/features/analysis/calculators/monthly_spending_forecast_calculator.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:test/test.dart';

ExpenseEntry expense(DateTime date, int amount) => ExpenseEntry.create(
  spentAt: date,
  categoryCode: 'F',
  description: '',
  amount: amount,
);

void main() {
  const calculator = MonthlySpendingForecastCalculator();
  test(
    'Fixed spending offsets every point without changing average or slope',
    () {
      final month = DateTime(2026, 1);
      final entries = [expense(month, 300)];
      final base = calculator.calculate(
        expenses: entries,
        selectedMonth: month,
        usingRange: false,
        today: DateTime(2026, 1, 3),
      )!;
      final result = calculator.calculate(
        expenses: entries,
        fixedExpenses: [
          FixedExpense.create(
            appliedAt: month,
            categoryCode: 'L',
            description: '',
            amount: 1000,
          ),
          FixedExpense.create(
            appliedAt: month,
            categoryCode: 'L',
            description: '',
            amount: 500,
          ),
          FixedExpense.create(
            appliedAt: DateTime(2025, 12),
            categoryCode: 'L',
            description: '',
            amount: 9999,
          ),
          FixedExpense.create(
            appliedAt: DateTime(2027, 1),
            categoryCode: 'L',
            description: '',
            amount: 9999,
          ),
        ],
        selectedMonth: month,
        usingRange: false,
        today: DateTime(2026, 1, 3),
      )!;
      expect(result.fixedAmount, 1500);
      expect(result.variableAmount, 300);
      expect(result.dailyAverage, base.dailyAverage);
      expect(result.remainingAmount, base.remainingAmount);
      expect(
        result.actual.map((p) => p.amount),
        base.actual.map((p) => p.amount + 1500),
      );
      expect(
        result.projected.map((p) => p.amount),
        base.projected.map((p) => p.amount + 1500),
      );
      expect(result.monthEndAmount, base.monthEndAmount + 1500);
    },
  );
  test('Fixed-only month stays flat including the last day', () {
    for (final day in [1, 15, 31]) {
      final result = calculator.calculate(
        expenses: [],
        fixedExpenses: [
          FixedExpense.create(
            appliedAt: DateTime(2026, 1),
            categoryCode: 'L',
            description: '',
            amount: 500,
          ),
        ],
        selectedMonth: DateTime(2026, 1),
        usingRange: false,
        today: DateTime(2026, 1, day),
      )!;
      expect(result.dailyAverage, 0);
      expect(result.remainingAmount, 0);
      expect(result.monthEndAmount, 500);
      expect(result.actual.every((p) => p.amount == 500), isTrue);
      expect(result.projected.every((p) => p.amount == 500), isTrue);
    }
  });
  test(
    'Includes zero-spend days and today, excludes other months and future days',
    () {
      final result = calculator.calculate(
        expenses: [
          expense(DateTime(2026, 1, 1), 100),
          expense(DateTime(2026, 1, 3, 23, 59), 201),
          expense(DateTime(2026, 1, 4), 9999),
          expense(DateTime(2025, 12, 31), 9999),
          expense(DateTime(2027, 1, 1), 9999),
        ],
        selectedMonth: DateTime(2026, 1),
        usingRange: false,
        today: DateTime(2026, 1, 3),
      )!;
      expect(result.actual.map((p) => p.amount), [100, 100, 301]);
      expect(result.dailyAverage, 100);
      expect(result.projected.first.amount, 301);
      expect(result.projected.first.dayOffset, 3);
      expect(result.projected.last.dayOffset, 31);
      expect(result.remainingAmount, 2809);
      expect(result.monthEndAmount, 3110);
      expect(() => result.actual.clear(), throwsUnsupportedError);
    },
  );
  test('Only the current month in monthly mode is eligible', () {
    for (final month in [
      DateTime(2025, 12),
      DateTime(2027, 1),
      DateTime(2026, 2),
    ]) {
      expect(
        calculator.calculate(
          expenses: [],
          selectedMonth: month,
          usingRange: false,
          today: DateTime(2026, 1, 1),
        ),
        isNull,
      );
    }
    expect(
      calculator.calculate(
        expenses: [],
        selectedMonth: DateTime(2026, 1),
        usingRange: true,
        today: DateTime(2026, 1, 1),
      ),
      isNull,
    );
  });
  test('First day and empty data remain finite', () {
    for (final amount in [0, 100]) {
      final result = calculator.calculate(
        expenses: amount == 0 ? [] : [expense(DateTime(2026, 1, 1), amount)],
        selectedMonth: DateTime(2026, 1),
        usingRange: false,
        today: DateTime(2026, 1, 1),
      )!;
      expect(result.dailyAverage, amount);
      expect(result.monthEndAmount, amount * 31);
      expect(result.actual.length, 1);
    }
  });
  test('Leap year and month ends have correct remaining periods', () {
    for (final date in [
      DateTime(2024, 2, 28),
      DateTime(2024, 2, 29),
      DateTime(2025, 2, 28),
      DateTime(2026, 4, 30),
    ]) {
      final result = calculator.calculate(
        expenses: [expense(date, date.day * 100)],
        selectedMonth: date,
        usingRange: false,
        today: date,
      )!;
      final remaining = date == DateTime(2024, 2, 28) ? 1 : 0;
      expect(result.remainingAmount, remaining * 100);
      expect(result.projected.isEmpty, remaining == 0);
      expect(result.daysInMonth, date.day + remaining);
    }
  });
}
