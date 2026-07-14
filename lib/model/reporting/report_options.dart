// """ MVVM 계층: Model / Reporting Option """
// """ 역할: PDF에 포함할 선택 섹션을 표현 """
// """ 규칙: Checkbox 같은 UI 타입을 모르는 순수 설정 모델 """

/// PDF 리포트에 포함할 섹션을 선택한다.
class ReportOptions {
  const ReportOptions({
    this.includeDetailedData = true,
    this.includeTop10 = true,
    this.includeFixedExpenses = true,
    this.includePaymentSummary = true,
    this.includePrevComparison = false,
    this.includePrevCategoryAnalysis = false,
  });

  final bool includeDetailedData;
  final bool includeTop10;
  final bool includeFixedExpenses;
  final bool includePaymentSummary;
  final bool includePrevComparison;
  final bool includePrevCategoryAnalysis;
}
