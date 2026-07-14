// """ MVVM 계층: Model / Calculation Feature """
// """ 역할: 현재·이전 소비의 금액 차이와 카테고리별 증감을 계산 """
// """ 규칙: 원본 입력을 결과 모델로 변환하며 화면 상태를 직접 읽지 않음 """

import 'package:household_ledger/features/comparison/models/expense_comparison_result.dart';
import 'package:household_ledger/model/expense_entry.dart';

class ExpenseComparisonCalculator {
  const ExpenseComparisonCalculator();

  ExpenseComparisonResult? calculate({
    required Iterable<ExpenseEntry> currentExpenses,
    required Iterable<ExpenseEntry> previousExpenses,
  }) {
    final previous = previousExpenses.toList(growable: false);
    if (previous.isEmpty) return null;
    final current = currentExpenses.toList(growable: false);

    final currentTotal = _total(current);
    final previousTotal = _total(previous);
    final diff = currentTotal - previousTotal;
    final currentCategories = _categoryTotals(current);
    final previousCategories = _categoryTotals(previous);
    final categoryCodes = <String>{
      ...currentCategories.keys,
      ...previousCategories.keys,
    };
    final categoryDifferences =
        categoryCodes
            .map(
              (String code) => MapEntry<String, int>(
                code,
                (currentCategories[code] ?? 0) -
                    (previousCategories[code] ?? 0),
              ),
            )
            .where((MapEntry<String, int> entry) => entry.value != 0)
            .toList(growable: false)
          ..sort(
            (MapEntry<String, int> left, MapEntry<String, int> right) =>
                right.value.abs().compareTo(left.value.abs()),
          );

    return ExpenseComparisonResult(
      diff: diff,
      diffPercent: previousTotal > 0 ? diff.abs() / previousTotal * 100 : 0,
      moreSpent: diff > 0,
      categoryDifferences: List<MapEntry<String, int>>.unmodifiable(
        categoryDifferences,
      ),
    );
  }

  int _total(Iterable<ExpenseEntry> expenses) => expenses.fold<int>(
    0,
    (int total, ExpenseEntry entry) => total + entry.amount,
  );

  Map<String, int> _categoryTotals(Iterable<ExpenseEntry> expenses) {
    final totals = <String, int>{};
    for (final entry in expenses) {
      totals.update(
        entry.categoryCode,
        (int value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    return totals;
  }
}
