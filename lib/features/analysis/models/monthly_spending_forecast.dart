import 'analysis_series_result.dart';

/// 월 고정지출을 기준액으로 포함한 누적액과 월말까지의 선형 예측 결과.
class MonthlySpendingForecast {
  MonthlySpendingForecast({
    required List<DailyAmountPoint> actual,
    required List<DailyAmountPoint> projected,
    required this.daysInMonth,
    required this.dailyAverage,
    required this.remainingAmount,
    required this.fixedAmount,
  }) : actual = List.unmodifiable(actual),
       projected = List.unmodifiable(projected);

  final List<DailyAmountPoint> actual;

  /// 실선과 연결하기 위해 오늘의 실제 누적액을 첫 점으로 포함한다.
  /// 월말에는 미래 구간이 없으므로 빈 목록이다.
  final List<DailyAmountPoint> projected;
  final int daysInMonth;
  final int dailyAverage;
  final int remainingAmount;

  /// 실제 결제일과 무관하게 이번 달 전체 고정지출을 절편으로 사용한다.
  final int fixedAmount;
  int get variableAmount => accumulatedAmount - fixedAmount;
  int get accumulatedAmount => actual.last.amount;
  int get monthEndAmount => accumulatedAmount + remainingAmount;
}
