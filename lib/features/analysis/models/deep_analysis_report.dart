/// 집계가 끝난 심층분석 결과. 화면에서는 원본 데이터 집계를 수행하지 않는다.
class DeepAnalysisReport {
  const DeepAnalysisReport({
    required this.month,
    required this.total,
    required this.fixedTotal,
    required this.fixedShare,
    required this.topShare,
    required this.withoutTop,
    required this.baselines,
    required this.trend,
    required this.largeExpenses,
    required this.fixedBreakdown,
    this.isDemo = false,
  });
  final DateTime month;
  final int total, fixedTotal, withoutTop;
  final double fixedShare, topShare;
  final bool isDemo;
  final List<DeepAnalysisBaseline> baselines;
  final List<DeepAnalysisMonth> trend;
  final List<DeepAnalysisItem> largeExpenses, fixedBreakdown;
}

/// 비교 기간의 평균과 변화량. average가 null이면 비교할 이력이 부족하다.
class DeepAnalysisBaseline {
  const DeepAnalysisBaseline({
    required this.months,
    this.average,
    this.difference = 0,
    this.fixedAverage = 0,
    this.changes = const [],
  });
  final int months;
  final int? average;
  final int difference, fixedAverage;
  final List<DeepAnalysisItem> changes;
}

class DeepAnalysisMonth {
  const DeepAnalysisMonth(this.month, this.amount);
  final DateTime month;
  final int amount;
}

/// 사용자 내용(label) 또는 시스템 항목 식별자(labelKey)와 가공된 수치.
class DeepAnalysisItem {
  const DeepAnalysisItem({
    this.label = '',
    this.labelKey,
    required this.amount,
    this.share = 0,
    this.date,
  });
  final String label;
  final String? labelKey;
  final int amount;
  final double share;
  final DateTime? date;
}
