// """ MVVM 계층: Model / Calculation Result """
// """ 역할: PDF 리포트 집계 결과와 파생 합계를 불변 데이터로 제공 """
// """ 규칙: PDF Widget, 색상, 파일 경로를 포함하지 않음 """

/// PDF 화면 구성 전에 계산되는 순수 집계 결과다.
class ReportSummary {
  const ReportSummary({
    required this.expenseTotal,
    required this.fixedTotal,
    required this.incomeTotal,
    required this.categoryTotals,
    required this.categoryCounts,
    required this.paymentMethodTotals,
  });

  final int expenseTotal;
  final int fixedTotal;
  final int incomeTotal;
  final Map<String, int> categoryTotals;
  final Map<String, int> categoryCounts;
  final Map<String, int> paymentMethodTotals;

  int get combinedExpense => expenseTotal + fixedTotal;
  int get balance => incomeTotal - combinedExpense;

  // """ 렌더링 순서를 위한 금액 내림차순 결과 """
  List<MapEntry<String, int>> get categoryTotalsSorted =>
      _sortedEntries(categoryTotals);

  List<MapEntry<String, int>> get paymentMethodTotalsSorted =>
      _sortedEntries(paymentMethodTotals);

  static List<MapEntry<String, int>> _sortedEntries(Map<String, int> source) =>
      source.entries.toList(growable: false)..sort(
        (MapEntry<String, int> left, MapEntry<String, int> right) =>
            right.value.compareTo(left.value),
      );
}
