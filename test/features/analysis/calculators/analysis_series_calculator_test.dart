// """ 테스트 계층: Model Calculation Unit Test """
// """ 대상: AnalysisSeriesCalculator의 분류별 합계와 일별 시계열 """
// """ 실행: dart run test test/features/analysis/calculators """

import 'package:household_ledger/features/analysis/calculators/analysis_series_calculator.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:test/test.dart';

void main() {
  const calculator = AnalysisSeriesCalculator();
  final start = DateTime(2026, 7, 1);

  ExpenseEntry expense(String id, int day, String category, int amount) =>
      ExpenseEntry.create(
        id: id,
        spentAt: DateTime(2026, 7, day),
        categoryCode: category,
        description: id,
        amount: amount,
      );

  test('카테고리 금액과 고정지출을 비율순으로 집계한다', () {
    final result = calculator.categoryBreakdown(
      expenses: <ExpenseEntry>[
        expense('food', 1, 'F', 3000),
        expense('cafe', 2, 'C', 1000),
      ],
      fixedExpenses: <FixedExpense>[
        FixedExpense.create(
          id: 'rent',
          appliedAt: start,
          categoryCode: 'L',
          description: 'rent',
          amount: 6000,
        ),
      ],
    );

    expect(result.first.code, AnalysisSeriesCalculator.fixedExpenseCode);
    expect(result.first.amount, 6000);
    expect(result.first.percentage, 60);
  });

  test('기간 시작일 기준으로 일별 금액을 합산한다', () {
    final result = calculator.dailyExpenses(<ExpenseEntry>[
      expense('first', 1, 'F', 1000),
      expense('second', 1, 'C', 2000),
      expense('third', 3, 'G', 4000),
    ], start);

    expect(result.map((point) => point.dayOffset), <int>[1, 3]);
    expect(result.map((point) => point.amount), <int>[3000, 4000]);
  });
}
