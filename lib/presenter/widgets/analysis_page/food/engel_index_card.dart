// """ 계층: Presentation / Feature View """
// """ 역할: 계산된 엥겔지수와 상태 안내를 게이지 카드로 표시 """
// """ 표현 규칙: 상태 기준에 따라 색상과 현지화 문구를 선택 """

import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/food/analysis_insight_components.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';

// """ 엥겔지수 카드 """
class EngelIndexCard extends StatelessWidget {
  const EngelIndexCard({
    required this.engelIndex,
    required this.hasCurrentData,
    required this.strings,
    required this.onAddExpense,
    super.key,
  });

  final double engelIndex;
  final bool hasCurrentData;
  final Map<String, String> strings;
  final VoidCallback onAddExpense;

  String _text(String key, String fallback) => strings[key] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final statusKey = engelIndex > 35
        ? 'analysisEngelHigh'
        : engelIndex < 25
        ? 'analysisEngelLow'
        : 'analysisEngelBalanced';
    final statusFallback = engelIndex > 35
        ? '엥겔지수가 높아요!'
        : engelIndex < 25
        ? '엥겔지수가 낮아요!'
        : '엥겔지수가 안정적인 수준이에요.';
    final color = engelIndex > 35
        ? const Color(0xFFDC3545)
        : engelIndex < 25
        ? const Color(0xFF0D6EFD)
        : const Color(0xFF198754);

    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AnalysisInsightHeader(
                  icon: Icons.pie_chart_outline_rounded,
                  title: _text('analysisEngelIndexLabel', '엥겔지수'),
                  color: color,
                ),
              ),
              Tooltip(
                message: _text(
                  'analysisEngelTooltip',
                  '엥겔지수는 전체 지출 중 카페·외식·식료품 지출이 차지하는 비율입니다.',
                ),
                triggerMode: TooltipTriggerMode.tap,
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: Color(0xFF627D98),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                engelIndex.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 3),
                child: Text(
                  '%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnalysisAnimatedGauge(
            value: (engelIndex / 60).clamp(0.0, 1.0).toDouble(),
            color: color,
          ),
          const SizedBox(height: 12),
          hasCurrentData
              ? AnalysisComparisonMessage(
                  text: _text(statusKey, statusFallback),
                  isIncrease: engelIndex > 35,
                  isSimilar: engelIndex >= 25 && engelIndex <= 35,
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
