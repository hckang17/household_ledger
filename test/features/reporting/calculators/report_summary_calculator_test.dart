// """ 테스트 계층: Domain Unit Test """
// """ 대상: ReportSummaryCalculator의 합계와 분류별 집계 """
// """ 실행: dart run test test/features/reporting/calculators """

import 'package:household_ledger/features/reporting/calculators/report_summary_calculator.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:test/test.dart';

void main() {
  const calculator = ReportSummaryCalculator();
  final date = DateTime(2026, 7, 14);

  test('리포트 합계와 분류별 집계를 계산한다', () {
    final result = calculator.calculate(
      expenses: <ExpenseEntry>[
        ExpenseEntry.create(
          id: 'food-card',
          spentAt: date,
          categoryCode: 'F',
          paymentMethodCode: 'card',
          description: 'lunch',
          amount: 3000,
        ),
        ExpenseEntry.create(
          id: 'food-cash',
          spentAt: date,
          categoryCode: 'F',
          paymentMethodCode: 'cash',
          description: 'dinner',
          amount: 5000,
        ),
        ExpenseEntry.create(
          id: 'cafe-card',
          spentAt: date,
          categoryCode: 'C',
          paymentMethodCode: 'card',
          description: 'coffee',
          amount: 2000,
        ),
      ],
      fixedExpenses: <FixedExpense>[
        FixedExpense.create(
          id: 'rent',
          appliedAt: date,
          categoryCode: 'L',
          description: 'rent',
          amount: 4000,
        ),
      ],
      incomes: <IncomeEntry>[
        IncomeEntry.create(
          id: 1,
          earnedAt: date,
          description: 'salary',
          amount: 20000,
        ),
      ],
    );

    expect(result.expenseTotal, 10000);
    expect(result.fixedTotal, 4000);
    expect(result.incomeTotal, 20000);
    expect(result.combinedExpense, 14000);
    expect(result.balance, 6000);
    expect(result.categoryTotals['F'], 8000);
    expect(result.categoryCounts['F'], 2);
    expect(result.paymentMethodTotals['card'], 5000);
    expect(result.categoryTotalsSorted.first.key, 'F');
  });

  test('데이터가 없으면 모든 합계를 0으로 반환한다', () {
    final result = calculator.calculate(
      expenses: const <ExpenseEntry>[],
      fixedExpenses: const <FixedExpense>[],
      incomes: const <IncomeEntry>[],
    );

    expect(result.expenseTotal, 0);
    expect(result.combinedExpense, 0);
    expect(result.balance, 0);
    expect(result.categoryTotals, isEmpty);
  });
}
