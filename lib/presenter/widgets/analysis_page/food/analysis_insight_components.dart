// """ 계층: Presentation / Shared View Components """
// """ 역할: 음식 분석 카드에서 반복되는 헤더, 수치, 안내문, 비교 막대를 제공 """
// """ 범위: analysis_page 내부에서만 재사용하며 widgets/common 대상은 아님 """

import 'dart:math' as math;

import 'package:flutter/material.dart';

// """ 카드 제목 컴포넌트 """
class AnalysisInsightHeader extends StatelessWidget {
  const AnalysisInsightHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.warningTooltip,
    super.key,
  });

  final IconData icon;
  final String title;
  final Color color;
  final String? warningTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (warningTooltip != null) ...<Widget>[
                const SizedBox(width: 6),
                AnalysisDataSufficiencyTooltip(message: warningTooltip!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class AnalysisDataSufficiencyTooltip extends StatelessWidget {
  const AnalysisDataSufficiencyTooltip({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 5),
      child: const Icon(
        Icons.error_outline_rounded,
        color: Color(0xFFDC3545),
        size: 19,
      ),
    );
  }
}

// """ 핵심 수치 컴포넌트 """
class AnalysisInsightValue extends StatelessWidget {
  const AnalysisInsightValue({
    required this.value,
    required this.label,
    super.key,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F3A5F),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF627D98)),
        ),
      ],
    );
  }
}

class AnalysisAnimatedGauge extends StatelessWidget {
  const AnalysisAnimatedGauge({
    required this.value,
    required this.color,
    super.key,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double animatedValue, Widget? child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: 10,
            color: color,
            backgroundColor: const Color(0xFFE6EDF4),
          ),
        );
      },
    );
  }
}

class AnalysisNoCurrentDataPrompt extends StatelessWidget {
  const AnalysisNoCurrentDataPrompt({
    required this.text,
    required this.buttonLabel,
    required this.onPressed,
    super.key,
  });

  final String text;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF486581);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                textStyle: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalysisComparisonMessage extends StatelessWidget {
  const AnalysisComparisonMessage({
    required this.text,
    required this.isIncrease,
    required this.isSimilar,
    super.key,
  });

  final String text;
  final bool isIncrease;
  final bool isSimilar;

  @override
  Widget build(BuildContext context) {
    final Color color = isSimilar
        ? const Color(0xFF486581)
        : isIncrease
        ? const Color(0xFFDC3545)
        : const Color(0xFF198754);
    final IconData icon = isSimilar
        ? Icons.remove_rounded
        : isIncrease
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalysisChartLegend extends StatelessWidget {
  const AnalysisChartLegend({
    required this.currentLabel,
    required this.previousLabel,
    required this.color,
    super.key,
  });

  final String currentLabel;
  final String previousLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget item(Color dotColor, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        item(color, currentLabel),
        const SizedBox(width: 12),
        item(const Color(0xFFB8C4D1), previousLabel),
      ],
    );
  }
}

class AnalysisAnimatedComparisonBars extends StatelessWidget {
  const AnalysisAnimatedComparisonBars({
    required this.current,
    required this.previous,
    required this.currentLabel,
    required this.previousLabel,
    required this.valueSuffix,
    required this.color,
    super.key,
  });

  final double current;
  final double previous;
  final String currentLabel;
  final String previousLabel;
  final String valueSuffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double maxValue = math.max(current, previous);
    return Column(
      children: <Widget>[
        _AnimatedBarLine(
          label: currentLabel,
          value: current,
          maxValue: maxValue,
          valueSuffix: valueSuffix,
          color: color,
        ),
        const SizedBox(height: 8),
        _AnimatedBarLine(
          label: previousLabel,
          value: previous,
          maxValue: maxValue,
          valueSuffix: valueSuffix,
          color: const Color(0xFFB8C4D1),
        ),
      ],
    );
  }
}

class _AnimatedBarLine extends StatelessWidget {
  const _AnimatedBarLine({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.valueSuffix,
    required this.color,
  });

  final String label;
  final double value;
  final double maxValue;
  final String valueSuffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue <= 0 ? 0.0 : value / maxValue;
    final displayValue = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return Row(
      children: <Widget>[
        if (label.isNotEmpty)
          SizedBox(
            width: 68,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: Container(
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFFE6EDF4),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: fraction.clamp(0.0, 1.0).toDouble(),
              ),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder:
                  (
                    BuildContext context,
                    double animatedFraction,
                    Widget? child,
                  ) {
                    return FractionallySizedBox(
                      widthFactor: animatedFraction,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    );
                  },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: valueSuffix.isEmpty ? 28 : 66,
          child: Text(
            '$displayValue$valueSuffix',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
