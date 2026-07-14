// """ MVVM 계층: Model / Calculation Result """
// """ 역할: 현재 기간과 이전 기간의 전체·카테고리별 소비 비교 결과 표현 """
// """ 규칙: Widget, Provider, 현지화 문구를 포함하지 않는 불변 결과 """

class ExpenseComparisonResult {
  const ExpenseComparisonResult({
    required this.diff,
    required this.diffPercent,
    required this.moreSpent,
    required this.categoryDifferences,
  });

  final int diff;
  final double diffPercent;
  final bool moreSpent;
  final List<MapEntry<String, int>> categoryDifferences;

  List<MapEntry<String, int>> get gainers => categoryDifferences
      .where((MapEntry<String, int> entry) => entry.value > 0)
      .toList(growable: false);
}
