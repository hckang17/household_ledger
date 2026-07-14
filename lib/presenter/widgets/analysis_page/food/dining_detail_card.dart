// """ 계층: Presentation / Feature View """
// """ 역할: 식사 유형 차트와 회식 통계를 하나의 외식 상세 카드로 구성 """
// """ 입력: Domain 결과 모델과 현지화 문자열, 사용자 액션 콜백 """

import 'package:flutter/material.dart';
import 'package:household_ledger/features/analysis/models/food_analysis_result.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/food/analysis_insight_components.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/food/charts/dining_occasion_vertical_chart.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';

// """ 외식 상세 분석 카드 """
class DiningDetailCard extends StatelessWidget {
  const DiningDetailCard({
    required this.dining,
    required this.occasions,
    required this.companyDining,
    required this.tags,
    required this.peakComparisonText,
    required this.companyComparisonText,
    required this.strings,
    required this.currency,
    required this.onAddExpense,
    super.key,
  });

  final VisitAnalysisResult dining;
  final DiningOccasionAnalysisResult occasions;
  final VisitAnalysisResult companyDining;
  final List<MetadataTag> tags;
  final String peakComparisonText;
  final String companyComparisonText;
  final Map<String, String> strings;
  final String currency;
  final VoidCallback onAddExpense;

  String _text(String key, String fallback) => strings[key] ?? fallback;

  // """ 현재 데이터가 없을 때 표시할 소비 입력 안내 """
  Widget _emptyPrompt() => AnalysisNoCurrentDataPrompt(
    text: _text(
      'analysisNoCurrentComparisonData',
      '비교할 데이터가 존재하지 않습니다. 데이터를 입력하러 갈까요?',
    ),
    buttonLabel: _text('analysisAddExpenseAction', '소비내역 입력하기'),
    onPressed: onAddExpense,
  );

  @override
  Widget build(BuildContext context) {
    const chartColor = Color(0xFF6F42C1);
    final peakCode = occasions.peakCode;
    final peakLabel = peakCode == null ? '' : tags.labelFor(peakCode);
    final peakText = occasions.peakCount == 0
        ? _text('analysisNoMealTimeData', '식사 시간대 데이터가 없습니다.')
        : '${_text('analysisPeakMealTime', '{label} 유형의 외식이 가장 많아요!').replaceAll('{label}', peakLabel)}\n$peakComparisonText';

    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnalysisInsightHeader(
            icon: Icons.query_stats_rounded,
            title: _text('analysisDiningDetailTitle', '외식 상세 분석'),
            color: chartColor,
          ),
          const SizedBox(height: 16),
          AnalysisChartLegend(
            currentLabel: _text('analysisCurrentPeriod', '현재'),
            previousLabel: _text('analysisPreviousPeriod', '전월동기'),
            color: chartColor,
          ),
          const SizedBox(height: 10),
          DiningOccasionVerticalChart(
            tags: tags,
            currentCounts: occasions.currentCounts,
            previousCounts: occasions.previousCounts,
            color: chartColor,
          ),
          // Todo::공백수정 - 그래프와 요약 문구 사이 간격은 이 값을 조절합니다.
          const SizedBox(height: 3),
          dining.hasCurrentData
              ? AnalysisComparisonMessage(
                  text: peakText,
                  isIncrease:
                      occasions.previousPeakCount > 0 &&
                      occasions.peakCount > occasions.previousPeakCount,
                  isSimilar:
                      occasions.previousPeakCount == 0 ||
                      occasions.peakCount == occasions.previousPeakCount,
                )
              : _emptyPrompt(),
          const Divider(height: 30),
          Text(
            _text('analysisCompanyDiningTitle', '회식 분석'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: AnalysisInsightValue(
                  value: '${companyDining.count}',
                  label: _text('analysisCompanyCountLabel', '회식 횟수'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnalysisInsightValue(
                  value: '${companyDining.averageAmount.toCurrency()}$currency',
                  label: _text('analysisCompanyAverageLabel', '회식 평균'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnalysisInsightValue(
                  value: '${companyDining.totalAmount.toCurrency()}$currency',
                  label: _text('analysisCompanyTotalLabel', '회식 총금액'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnalysisAnimatedComparisonBars(
            current: companyDining.count.toDouble(),
            previous: companyDining.previousCount.toDouble(),
            currentLabel: _text('analysisCurrentPeriod', '현재'),
            previousLabel: _text('analysisPreviousPeriod', '전월동기'),
            valueSuffix: _text('analysisTimesUnit', '회'),
            color: const Color(0xFFDC3545),
          ),
          const SizedBox(height: 12),
          if (dining.hasCurrentData)
            companyDining.hasCurrentData
                ? AnalysisComparisonMessage(
                    text: companyComparisonText,
                    isIncrease:
                        companyDining.countComparison.direction ==
                        AnalysisComparisonDirection.increase,
                    isSimilar:
                        companyDining.countComparison.direction ==
                            AnalysisComparisonDirection.similar ||
                        companyDining.countComparison.direction ==
                            AnalysisComparisonDirection.unavailable,
                  )
                : _emptyPrompt(),
        ],
      ),
    );
  }
}
