// """ 테스트 계층: Domain Unit Test """
// """ 대상: FoodAnalysisCalculator의 합계, 비교, 식사 유형 계산 """
// """ 실행: dart run test test/features/analysis/calculators """

import 'package:household_ledger/features/analysis/calculators/food_analysis_calculator.dart';
import 'package:household_ledger/features/analysis/models/food_analysis_result.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:test/test.dart';

void main() {
  const calculator = FoodAnalysisCalculator();
  final date = DateTime(2026, 7, 10, 12);

  ExpenseEntry expense({
    required String id,
    required String category,
    required int amount,
    String? occasion,
  }) => ExpenseEntry.create(
    id: id,
    spentAt: date,
    categoryCode: category,
    diningOccasionCode: occasion,
    description: id,
    amount: amount,
  );

  group('FoodAnalysisCalculator', () {
    test('음식 합계와 엥겔지수 및 방문 통계를 계산한다', () {
      final result = calculator.calculate(
        expenses: <ExpenseEntry>[
          expense(
            id: 'breakfast',
            category: 'F',
            amount: 1000,
            occasion: 'breakfast',
          ),
          expense(id: 'lunch', category: 'F', amount: 3000, occasion: 'lunch'),
          expense(id: 'cafe', category: 'C', amount: 2000),
          expense(id: 'grocery', category: 'G', amount: 1000),
          expense(id: 'living', category: 'L', amount: 3000),
        ],
        previousExpenses: <ExpenseEntry>[
          expense(
            id: 'previousLunch',
            category: 'F',
            amount: 500,
            occasion: 'lunch',
          ),
          expense(
            id: 'previousCompany',
            category: 'F',
            amount: 1000,
            occasion: 'company',
          ),
          expense(id: 'previousCafe', category: 'C', amount: 100),
        ],
        activeFixedExpenses: <FixedExpense>[
          FixedExpense.create(
            id: 'fixedGrocery',
            appliedAt: date,
            categoryCode: 'G',
            description: 'fixed',
            amount: 1000,
          ),
        ],
        totalAmount: 11000,
        periodDays: 10,
        diningOccasionCodes: const <String>['breakfast', 'lunch', 'company'],
      );

      expect(result.foodTotalAmount, 8000);
      expect(result.engelIndex, closeTo(72.7272, 0.001));
      expect(result.dining.count, 2);
      expect(result.dining.totalAmount, 4000);
      expect(result.dining.averageAmount, 2000);
      expect(result.dining.dailyAverage, 0.2);
      expect(result.dining.previousCount, 2);
      expect(
        result.dining.dailyComparison.direction,
        AnalysisComparisonDirection.similar,
      );
      expect(result.cafe.count, 1);
      expect(result.grocery.count, 1);
    });

    test('식사 유형별 횟수와 최다 유형을 태그 순서 기준으로 계산한다', () {
      final result = calculator.calculate(
        expenses: <ExpenseEntry>[
          expense(
            id: 'breakfast1',
            category: 'F',
            amount: 1000,
            occasion: 'breakfast',
          ),
          expense(id: 'lunch1', category: 'F', amount: 1000, occasion: 'lunch'),
          expense(
            id: 'company1',
            category: 'F',
            amount: 1000,
            occasion: 'company',
          ),
          expense(
            id: 'company2',
            category: 'F',
            amount: 1000,
            occasion: 'company',
          ),
        ],
        previousExpenses: <ExpenseEntry>[
          expense(
            id: 'previousCompany',
            category: 'F',
            amount: 1000,
            occasion: 'company',
          ),
        ],
        activeFixedExpenses: const <FixedExpense>[],
        totalAmount: 4000,
        periodDays: 10,
        diningOccasionCodes: const <String>['breakfast', 'lunch', 'company'],
      );

      expect(result.diningOccasions.currentCounts['company'], 2);
      expect(result.diningOccasions.previousCounts['company'], 1);
      expect(result.diningOccasions.peakCode, 'company');
      expect(result.diningOccasions.peakCount, 2);
      expect(result.diningOccasions.previousPeakCount, 1);
      expect(
        result.diningOccasions.peakComparison.direction,
        AnalysisComparisonDirection.increase,
      );
      expect(result.companyDining.averageAmount, 1000);
      expect(
        result.companyDining.countComparison.direction,
        AnalysisComparisonDirection.increase,
      );
    });

    test('현재 데이터가 없으면 0 결과와 감소 비교를 안전하게 반환한다', () {
      final result = calculator.calculate(
        expenses: const <ExpenseEntry>[],
        previousExpenses: <ExpenseEntry>[
          expense(id: 'previousCafe', category: 'C', amount: 1500),
        ],
        activeFixedExpenses: const <FixedExpense>[],
        totalAmount: 0,
        periodDays: 0,
        diningOccasionCodes: const <String>['breakfast', 'lunch'],
      );

      expect(result.foodTotalAmount, 0);
      expect(result.engelIndex, 0);
      expect(result.hasFoodData, isFalse);
      expect(result.cafe.count, 0);
      expect(result.cafe.previousCount, 1);
      expect(
        result.cafe.countComparison.direction,
        AnalysisComparisonDirection.decrease,
      );
      expect(result.diningOccasions.peakCode, 'breakfast');
      expect(result.diningOccasions.peakCount, 0);
    });

    test('비교 기간 데이터가 없으면 unavailable을 반환한다', () {
      final result = calculator.calculate(
        expenses: <ExpenseEntry>[
          expense(id: 'cafe', category: 'C', amount: 1200),
        ],
        previousExpenses: const <ExpenseEntry>[],
        activeFixedExpenses: const <FixedExpense>[],
        totalAmount: 1200,
        periodDays: 12,
        diningOccasionCodes: const <String>[],
      );

      expect(
        result.cafe.dailyComparison.direction,
        AnalysisComparisonDirection.unavailable,
      );
      expect(result.diningOccasions.peakCode, isNull);
    });
  });
}
