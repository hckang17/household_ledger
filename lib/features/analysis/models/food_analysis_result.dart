// """ MVVM 계층: Model / Calculation Result """
// """ 역할: 음식 분석 계산 결과를 UI와 분리된 불변 데이터로 표현 """
// """ 규칙: 색상, 문구, Widget 같은 표현 계층 정보를 포함하지 않음 """

// """ 공통 비교 결과 """
/// 현재 기간과 비교 기간의 증감 방향이다.
enum AnalysisComparisonDirection { increase, decrease, similar, unavailable }

/// 하나의 수치에 대한 현재 기간과 비교 기간의 결과다.
class AnalysisMetricComparison {
  const AnalysisMetricComparison({
    required this.current,
    required this.previous,
    required this.difference,
    required this.direction,
  });

  final double current;
  final double previous;
  final double difference;
  final AnalysisComparisonDirection direction;
}

// """ 방문형 카테고리 결과 """
/// 방문형 지출 카테고리의 집계 결과다.
class VisitAnalysisResult {
  const VisitAnalysisResult({
    required this.count,
    required this.totalAmount,
    required this.averageAmount,
    required this.dailyAverage,
    required this.previousCount,
    required this.previousDailyAverage,
    required this.dailyComparison,
    required this.countComparison,
  });

  final int count;
  final int totalAmount;
  final int averageAmount;
  final double dailyAverage;
  final int previousCount;
  final double previousDailyAverage;
  final AnalysisMetricComparison dailyComparison;
  final AnalysisMetricComparison countComparison;

  bool get hasCurrentData => count > 0;
}

// """ 외식 유형별 결과 """
/// 외식 식사 유형별 집계 결과다.
class DiningOccasionAnalysisResult {
  const DiningOccasionAnalysisResult({
    required this.currentCounts,
    required this.previousCounts,
    required this.peakCode,
    required this.peakCount,
    required this.previousPeakCount,
    required this.peakComparison,
  });

  final Map<String, int> currentCounts;
  final Map<String, int> previousCounts;
  final String? peakCode;
  final int peakCount;
  final int previousPeakCount;
  final AnalysisMetricComparison peakComparison;
}

// """ 음식 분석 전체 결과 """
/// 음식 관련 분석 카드가 사용하는 전체 계산 결과다.
class FoodAnalysisResult {
  const FoodAnalysisResult({
    required this.foodTotalAmount,
    required this.engelIndex,
    required this.dining,
    required this.diningOccasions,
    required this.companyDining,
    required this.cafe,
    required this.grocery,
  });

  final int foodTotalAmount;
  final double engelIndex;
  final VisitAnalysisResult dining;
  final DiningOccasionAnalysisResult diningOccasions;
  final VisitAnalysisResult companyDining;
  final VisitAnalysisResult cafe;
  final VisitAnalysisResult grocery;

  bool get hasFoodData => foodTotalAmount > 0;
}
