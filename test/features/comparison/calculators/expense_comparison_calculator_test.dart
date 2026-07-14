// """ 테스트 계층: Model Calculation Unit Test """
// """ 대상: ExpenseComparisonCalculator의 전체·카테고리별 증감 계산 """
// """ 실행: dart run test test/features/comparison/calculators """

import 'package:household_ledger/features/comparison/calculators/expense_comparison_calculator.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:test/test.dart';

void main() {
  const calculator = ExpenseComparisonCalculator();
  final date = DateTime(2026, 7, 14);

  ExpenseEntry expense(String id, String category, int amount) =>
      ExpenseEntry.create(
        id: id,
        spentAt: date,
        categoryCode: category,
        description: id,
        amount: amount,
      );

  test('전체 금액과 카테고리 증감액을 절댓값 순서로 계산한다', () {
    final result = calculator.calculate(
      currentExpenses: <ExpenseEntry>[
        expense('food', 'F', 7000),
        expense('cafe', 'C', 3000),
      ],
      previousExpenses: <ExpenseEntry>[
        expense('previousFood', 'F', 2000),
        expense('previousGrocery', 'G', 5000),
      ],
    );

    expect(result, isNotNull);
    expect(result!.diff, 3000);
    expect(result.diffPercent, closeTo(42.857, 0.001));
    expect(result.moreSpent, isTrue);
    expect(result.categoryDifferences.first.value.abs(), 5000);
    expect(
      result.gainers.map((entry) => entry.key),
      containsAll(<String>['F', 'C']),
    );
  });

  test('이전 기간 데이터가 없으면 비교 결과를 만들지 않는다', () {
    final result = calculator.calculate(
      currentExpenses: <ExpenseEntry>[expense('food', 'F', 1000)],
      previousExpenses: const <ExpenseEntry>[],
    );

    expect(result, isNull);
  });
}
