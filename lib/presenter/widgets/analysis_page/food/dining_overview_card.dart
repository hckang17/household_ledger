// """ 계층: Presentation / Feature View """
// """ 역할: 외식 빈도, 평균 금액, 전월동기 비교를 요약 카드로 표시 """
// """ 입력: 계산 완료된 VisitAnalysisResult와 표현용 문구 """

import 'package:flutter/material.dart';
import 'package:household_ledger/features/analysis/models/food_analysis_result.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/food/analysis_insight_components.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';

// """ 외식 요약 카드 """
class DiningOverviewCard extends StatelessWidget {
  const DiningOverviewCard({
    required this.result,
    required this.comparisonText,
    required this.strings,
    required this.currency,
    required this.onAddExpense,
    super.key,
  });

  final VisitAnalysisResult result;
  final String comparisonText;
  final Map<String, String> strings;
  final String currency;
  final VoidCallback onAddExpense;

  String _text(String key, String fallback) => strings[key] ?? fallback;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0D6EFD);
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnalysisInsightHeader(
            icon: Icons.restaurant_rounded,
            title: _text('analysisDiningOverviewTitle', '외식'),
            color: color,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: AnalysisInsightValue(
                  value: result.dailyAverage.toStringAsFixed(2),
                  label: _text('analysisDailyDiningLabel', '하루평균 외식 횟수'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnalysisInsightValue(
                  value: '${result.averageAmount.toCurrency()}$currency',
                  label: _text('analysisAverageDiningLabel', '1회 평균 금액'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnalysisAnimatedComparisonBars(
            current: result.dailyAverage,
            previous: result.previousDailyAverage,
            currentLabel: _text('analysisCurrentPeriod', '현재'),
            previousLabel: _text('analysisPreviousPeriod', '전월동기'),
            valueSuffix: _text('analysisTimesPerDayUnit', '회/일'),
            color: color,
          ),
          const SizedBox(height: 12),
          result.hasCurrentData
              ? AnalysisComparisonMessage(
                  text: comparisonText,
                  isIncrease:
                      result.dailyComparison.direction ==
                      AnalysisComparisonDirection.increase,
                  isSimilar:
                      result.dailyComparison.direction ==
                          AnalysisComparisonDirection.similar ||
                      result.dailyComparison.direction ==
                          AnalysisComparisonDirection.unavailable,
                )
              : AnalysisNoCurrentDataPrompt(
                  text: _text(
                    'analysisNoCurrentComparisonData',
                    '비교할 데이터가 존재하지 않습니다. 데이터를 입력하러 갈까요?',
                  ),
                  buttonLabel: _text('analysisAddExpenseAction', '소비내역 입력하기'),
                  onPressed: onAddExpense,
                ),
        ],
      ),
    );
  }
}
