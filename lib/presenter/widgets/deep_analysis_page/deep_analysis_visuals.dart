import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:household_ledger/features/analysis/models/deep_analysis_report.dart';

const deepInk = Color(0xFF173D39);
const deepTeal = Color(0xFF258477);
const deepCoral = Color(0xFFBF6149);
const deepTrack = Color(0xFFE5F0EC);
const deepMutedStyle = TextStyle(
  color: Color(0xFF63736F),
  fontSize: 13,
  height: 1.5,
);

class DeepCard extends StatelessWidget {
  const DeepCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });
  final String number, title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE4EAE7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: deepTeal,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: deepInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: deepMutedStyle),
        const SizedBox(height: 24),
        child,
      ],
    ),
  );
}

class DeepLabelValue extends StatelessWidget {
  const DeepLabelValue({
    required this.label,
    required this.value,
    this.color = deepInk,
    super.key,
  });
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(label, style: deepMutedStyle),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class DeepDivergingBar extends StatelessWidget {
  const DeepDivergingBar({
    required this.value,
    required this.maximum,
    super.key,
  });
  final int value, maximum;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: value < 0 ? value.abs() / maximum : 0,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: deepTeal,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
      Container(width: 1, height: 16, color: const Color(0xFFCED9D5)),
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value > 0 ? value / maximum : 0,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: deepCoral,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class DeepLegend extends StatelessWidget {
  const DeepLegend({required this.color, required this.text, super.key});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 8, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(text, style: deepMutedStyle)),
    ],
  );
}

class DeepTrendChart extends StatelessWidget {
  const DeepTrendChart({
    required this.points,
    required this.average,
    required this.money,
    super.key,
  });
  final List<DeepAnalysisMonth> points;
  final int? average;
  final String Function(int) money;
  @override
  Widget build(BuildContext context) {
    final max = points.fold<int>(
      average ?? 1,
      (v, p) => p.amount > v ? p.amount : v,
    );
    return Semantics(
      label: points
          .map((p) => '${p.month.year}/${p.month.month}: ${money(p.amount)}')
          .join(', '),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: max * 1.2,
            minY: 0,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= points.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${points[i].month.month}',
                        style: deepMutedStyle,
                      ),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (average != null)
                  HorizontalLine(
                    y: average!.toDouble(),
                    color: deepCoral,
                    strokeWidth: 2,
                    dashArray: [5, 4],
                  ),
              ],
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      money(rod.toY.round()),
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: points[i].amount.toDouble(),
                      width: 16,
                      color: i == points.length - 1
                          ? deepInk
                          : deepTeal.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
