// """ MVVM 계층: Model / Calculation Feature """
// """ 역할: 음식 관련 원본 지출을 화면에서 사용할 분석 결과로 계산 """
// """ 규칙: BuildContext, Widget, Provider, Localization에 의존하지 않는 순수 계산 코드 """

import 'package:household_ledger/features/analysis/models/food_analysis_result.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';

/// 음식 관련 지출 통계를 UI와 무관하게 계산한다.
class FoodAnalysisCalculator {
  const FoodAnalysisCalculator();

  static const Set<String> foodCategoryCodes = <String>{'C', 'F', 'G'};

  // """ 공개 계산 진입점 """
  FoodAnalysisResult calculate({
    required List<ExpenseEntry> expenses,
    required List<ExpenseEntry> previousExpenses,
    required List<FixedExpense> activeFixedExpenses,
    required int totalAmount,
    required int periodDays,
    required Iterable<String> diningOccasionCodes,
  }) {
    final safePeriodDays = periodDays < 1 ? 1 : periodDays;
    final foodExpenseTotal = _expenseTotal(
      expenses.where(
        (ExpenseEntry entry) => foodCategoryCodes.contains(entry.categoryCode),
      ),
    );
    final foodFixedTotal = activeFixedExpenses
        .where(
          (FixedExpense entry) =>
              foodCategoryCodes.contains(entry.categoryCode),
        )
        .fold<int>(0, (int total, FixedExpense entry) => total + entry.amount);
    final foodTotal = foodExpenseTotal + foodFixedTotal;

    final diningEntries = _categoryEntries(expenses, 'F');
    final previousDiningEntries = _categoryEntries(previousExpenses, 'F');
    final cafeEntries = _categoryEntries(expenses, 'C');
    final previousCafeEntries = _categoryEntries(previousExpenses, 'C');
    final groceryEntries = _categoryEntries(expenses, 'G');
    final previousGroceryEntries = _categoryEntries(previousExpenses, 'G');
    final companyEntries = _occasionEntries(diningEntries, 'company');
    final previousCompanyEntries = _occasionEntries(
      previousDiningEntries,
      'company',
    );

    final occasionCodes = diningOccasionCodes.toSet().toList();
    final currentOccasionCounts = <String, int>{
      for (final code in occasionCodes)
        code: _occasionEntries(diningEntries, code).length,
    };
    final previousOccasionCounts = <String, int>{
      for (final code in occasionCodes)
        code: _occasionEntries(previousDiningEntries, code).length,
    };
    final peakCode = _peakCode(currentOccasionCounts, occasionCodes);
    final peakCount = peakCode == null
        ? 0
        : currentOccasionCounts[peakCode] ?? 0;
    final previousPeakCount = peakCode == null
        ? 0
        : previousOccasionCounts[peakCode] ?? 0;

    return FoodAnalysisResult(
      foodTotalAmount: foodTotal,
      engelIndex: totalAmount > 0 ? foodTotal / totalAmount * 100 : 0,
      dining: _visitResult(
        diningEntries,
        previousDiningEntries,
        safePeriodDays,
      ),
      diningOccasions: DiningOccasionAnalysisResult(
        currentCounts: Map<String, int>.unmodifiable(currentOccasionCounts),
        previousCounts: Map<String, int>.unmodifiable(previousOccasionCounts),
        peakCode: peakCode,
        peakCount: peakCount,
        previousPeakCount: previousPeakCount,
        peakComparison: _comparison(
          current: peakCount.toDouble(),
          previous: previousPeakCount.toDouble(),
        ),
      ),
      companyDining: _visitResult(
        companyEntries,
        previousCompanyEntries,
        safePeriodDays,
      ),
      cafe: _visitResult(cafeEntries, previousCafeEntries, safePeriodDays),
      grocery: _visitResult(
        groceryEntries,
        previousGroceryEntries,
        safePeriodDays,
      ),
    );
  }

  // """ 원본 데이터 필터링과 합산 헬퍼 """
  List<ExpenseEntry> _categoryEntries(
    Iterable<ExpenseEntry> source,
    String categoryCode,
  ) => source
      .where((ExpenseEntry entry) => entry.categoryCode == categoryCode)
      .toList(growable: false);

  List<ExpenseEntry> _occasionEntries(
    Iterable<ExpenseEntry> source,
    String occasionCode,
  ) => source
      .where((ExpenseEntry entry) => entry.diningOccasionCode == occasionCode)
      .toList(growable: false);

  int _expenseTotal(Iterable<ExpenseEntry> source) => source.fold<int>(
    0,
    (int total, ExpenseEntry entry) => total + entry.amount,
  );

  VisitAnalysisResult _visitResult(
    List<ExpenseEntry> current,
    List<ExpenseEntry> previous,
    int periodDays,
  ) {
    final total = _expenseTotal(current);
    final currentDaily = current.length / periodDays;
    final previousDaily = previous.length / periodDays;
    return VisitAnalysisResult(
      count: current.length,
      totalAmount: total,
      averageAmount: current.isEmpty ? 0 : (total / current.length).round(),
      dailyAverage: currentDaily,
      previousCount: previous.length,
      previousDailyAverage: previousDaily,
      dailyComparison: _comparison(
        current: currentDaily,
        previous: previousDaily,
        similarTolerance: 0.05,
      ),
      countComparison: _comparison(
        current: current.length.toDouble(),
        previous: previous.length.toDouble(),
      ),
    );
  }

  AnalysisMetricComparison _comparison({
    required double current,
    required double previous,
    double similarTolerance = 0,
  }) {
    final difference = current - previous;
    final direction = previous == 0
        ? AnalysisComparisonDirection.unavailable
        : difference.abs() <= similarTolerance
        ? AnalysisComparisonDirection.similar
        : difference > 0
        ? AnalysisComparisonDirection.increase
        : AnalysisComparisonDirection.decrease;
    return AnalysisMetricComparison(
      current: current,
      previous: previous,
      difference: difference,
      direction: direction,
    );
  }

  // """ 동일 횟수일 때 전달받은 태그 순서를 우선하는 최다 유형 선택 """
  String? _peakCode(Map<String, int> counts, List<String> orderedCodes) {
    if (orderedCodes.isEmpty) return null;
    return orderedCodes.reduce(
      (String left, String right) =>
          (counts[left] ?? 0) >= (counts[right] ?? 0) ? left : right,
    );
  }
}
