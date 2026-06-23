import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/provider/localization_provider.dart';

/// 일별 지출/수입 금액 추이를 꺾은선 그래프로 표시하는 위젯이다.
///
/// [localizedStringsProvider]를 직접 참조해 Y축 단위(만/万)와
/// 날짜 표기(년·월·일 / 年·月·日)를 로케일에 맞게 처리한다.
///
/// [showDayStats]를 true로 설정하면 그래프 하단에
/// 최고·최저 지출일 요약 행을 표시한다(로케일 문자열 자동 참조).
class AnalysisDailyChart extends ConsumerWidget {
  /// 일별 추이 차트를 생성한다.
  const AnalysisDailyChart({
    required this.spots,
    required this.currency,
    required this.title,
    this.rangeStart,
    this.showDayStats = false,
    super.key,
  });

  /// 그래프에 표시할 데이터 포인트 목록이다.
  /// [FlSpot.x]는 1-based 일 번호, [FlSpot.y]는 해당일 금액이다.
  final List<FlSpot> spots;

  /// 툴팁에 표시할 통화 기호다(예: "₩").
  final String currency;

  /// 차트 상단에 표시할 섹션 제목이다.
  final String title;

  /// 기간 시작일이다. null이면 X축 값을 그대로 일 번호로 표시한다.
  final DateTime? rangeStart;

  /// true이면 그래프 하단에 최고·최저 금액일 요약 행을 표시한다.
  final bool showDayStats;

  // ─── 내부 헬퍼 ──────────────────────────────────────────────────

  /// Y축에 표시할 금액 약식 문자열을 반환한다.
  ///
  /// 1만(10000) 이상은 만/万 단위, 1000 이상은 K 단위, 그 미만은 정수로 표기한다.
  String _yLabel(double v, Map<String, String> strings) {
    final String wan = strings['chartUnitWan'] ?? '만';
    if (v >= 10000) {
      final double w = v / 10000;
      return w == w.truncateToDouble()
          ? '${w.toInt()}$wan'
          : '${w.toStringAsFixed(1)}$wan';
    }
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }

  /// [FlSpot.x](1-based 일 번호)를 로케일에 맞는 날짜 문자열로 변환한다.
  String _formatDayLabel(FlSpot spot, Map<String, String> strings) {
    final String daySuffix = strings['chartDateDaySuffix'] ?? '일';
    if (rangeStart == null) return '${spot.x.toInt()}$daySuffix';
    final DateTime date = rangeStart!.add(Duration(days: spot.x.toInt() - 1));
    final String yearSuffix = strings['chartDateYearSuffix'] ?? '년';
    final String monthSuffix = strings['chartDateMonthSuffix'] ?? '월';
    return '${date.year}$yearSuffix ${date.month}$monthSuffix ${date.day}$daySuffix';
  }

  Widget _buildDayStatRow(
    BuildContext context,
    String label,
    FlSpot spot,
    Color color,
    Map<String, String> strings,
  ) => Row(
    children: <Widget>[
      Expanded(
        child: Text(
          '$label : ${_formatDayLabel(spot, strings)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Text(
        '${spot.y.toInt().toCurrency()}$currency',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );

  // ─── 빌드 ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, String> strings = ref.watch(localizedStringsProvider);

    if (spots.isEmpty) return const SizedBox.shrink();
    if (spots.every((FlSpot s) => s.y == 0)) return const SizedBox.shrink();

    final double maxY =
        spots
            .map((FlSpot s) => s.y)
            .reduce((double a, double b) => a > b ? a : b) *
        1.3;

    final FlSpot maxSpot = spots.reduce(
      (FlSpot a, FlSpot b) => a.y >= b.y ? a : b,
    );
    final FlSpot minSpot = spots.reduce(
      (FlSpot a, FlSpot b) => a.y <= b.y ? a : b,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: const Color(0xFF0D6EFD),
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: <Color>[
                        const Color(0xFF0D6EFD).withValues(alpha: 0.18),
                        const Color(0xFF0D6EFD).withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxY / 4,
                    reservedSize: 46,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          _yLabel(value, strings),
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 5,
                    reservedSize: 22,
                    getTitlesWidget: (double value, TitleMeta meta) =>
                        SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${value.toInt()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (double value) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              minX: spots.first.x,
              maxX: spots.last.x,
              minY: 0,
              maxY: maxY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF222222),
                  getTooltipItems: (List<LineBarSpot> touchedSpots) => touchedSpots
                      .map(
                        (LineBarSpot spot) => LineTooltipItem(
                          '${spot.x.toInt()}\n${spot.y.toInt().toCurrency()}$currency',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),

        /// 최고·최저 금액일 요약 행은 [showDayStats]가 true일 때만 표시된다.
        if (showDayStats) ...<Widget>[
          const SizedBox(height: 12),
          _buildDayStatRow(
            context,
            strings['analysisDailyMaxLabel'] ?? '가장 지출이 많은 날',
            maxSpot,
            const Color(0xFFDC3545),
            strings,
          ),
          const SizedBox(height: 4),
          _buildDayStatRow(
            context,
            strings['analysisDailyMinLabel'] ?? '가장 지출이 적은 날',
            minSpot,
            const Color(0xFF198754),
            strings,
          ),
        ],
      ],
    );
  }
}
