// """ MVVM 계층: Model / Calculation Result """
// """ 역할: 분석 차트에 전달할 분류별 합계와 일별 금액 결과 표현 """
// """ 규칙: FlSpot, Color, Widget, 현지화 라벨을 포함하지 않음 """

class AnalysisBreakdownItem {
  const AnalysisBreakdownItem({
    required this.code,
    required this.amount,
    required this.percentage,
  });

  final String code;
  final int amount;
  final double percentage;
}

class DailyAmountPoint {
  const DailyAmountPoint({required this.dayOffset, required this.amount});

  final int dayOffset;
  final int amount;
}
