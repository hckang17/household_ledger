// """ 계층: Presentation / Reusable Feature View """
// """ 역할: 카페와 장보기처럼 방문 횟수 기반 분석에 공통 카드 레이아웃 제공 """
// """ 범위: analysis 음식 기능 내부 재사용 위젯 """

import 'package:flutter/material.dart';
import 'package:household_ledger/features/analysis/models/food_analysis_result.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/food/analysis_insight_components.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';

// """ 방문 빈도 공통 카드 """
class VisitFrequencyCard extends StatelessWidget {
  const VisitFrequencyCard({
    required this.icon,
    required this.title,
    required this.result,
    required this.dailyLabel,
    required this.averageLabel,
    required this.comparisonText,
    required this.warningTooltip,
    required this.currentLabel,
    required this.previousLabel,
    required this.valueSuffix,
    required this.currency,
    required this.color,
    required this.emptyText,
    required this.addButtonLabel,
    required this.onAddExpense,
    super.key,
  });

  final IconData icon;
  final String title;
  final VisitAnalysisResult result;
  final String dailyLabel;
  final String averageLabel;
  final String comparisonText;
  final String? warningTooltip;
  final String currentLabel;
  final String previousLabel;
  final String valueSuffix;
  final String currency;
  final Color color;
  final String emptyText;
  final String addButtonLabel;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnalysisInsightHeader(
            icon: icon,
            title: title,
            color: color,
            warningTooltip: warningTooltip,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: AnalysisInsightValue(
                  value: result.dailyAverage.toStringAsFixed(2),
                  label: dailyLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnalysisInsightValue(
                  value: '${result.averageAmount.toCurrency()}$currency',
                  label: averageLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnalysisAnimatedComparisonBars(
            current: result.dailyAverage,
            previous: result.previousDailyAverage,
            currentLabel: currentLabel,
            previousLabel: previousLabel,
            valueSuffix: valueSuffix,
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
                  text: emptyText,
                  buttonLabel: addButtonLabel,
                  onPressed: onAddExpense,
                ),
        ],
      ),
    );
  }
}
