// """ 테스트 계층: Model Calculation Unit Test """
// """ 대상: ExpenseCalendarCalculator의 날짜별 월간 합계 """
// """ 실행: dart run test test/features/expense/calculators """

import 'package:household_ledger/features/expense/calculators/expense_calendar_calculator.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:test/test.dart';

void main() {
  const calculator = ExpenseCalendarCalculator();
  final month = DateTime(2026, 7, 1);

  test('선택한 월의 날짜별 지출만 집계한다', () {
    final result = calculator.monthlyTotals(<ExpenseEntry>[
      ExpenseEntry.create(
        id: 'first',
        spentAt: DateTime(2026, 7, 1),
        categoryCode: 'F',
        description: 'first',
        amount: 1000,
      ),
      ExpenseEntry.create(
        id: 'second',
        spentAt: DateTime(2026, 7, 1),
        categoryCode: 'C',
        description: 'second',
        amount: 2000,
      ),
      ExpenseEntry.create(
        id: 'nextMonth',
        spentAt: DateTime(2026, 8, 1),
        categoryCode: 'G',
        description: 'next',
        amount: 5000,
      ),
    ], month);

    expect(result, <int, int>{1: 3000});
  });
}
