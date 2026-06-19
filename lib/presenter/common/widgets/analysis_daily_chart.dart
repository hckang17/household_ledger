import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';

/// 일별 지출 금액 추이를 꺾은선 그래프로 표시하는 위젯이다.
///
/// X축은 기간 내 일(day) 번호, Y축은 해당일 지출 합계를 나타낸다.
/// 데이터가 없으면 아무것도 렌더링하지 않는다([SizedBox.shrink]).
/// 라인 아래 영역은 반투명 그라디언트로 채워진다.
class AnalysisDailyChart extends StatelessWidget {
  /// 일별 추이 차트를 생성한다.
  const AnalysisDailyChart({
    required this.spots,
    required this.currency,
    required this.title,
    this.rangeStart,
    this.maxLabel,
    this.minLabel,
    super.key,
  });

  /// 그래프에 표시할 데이터 포인트 목록이다.
  /// [FlSpot.x]는 일 번호(1-based), [FlSpot.y]는 해당일 지출액이다.
  final List<FlSpot> spots;

  /// 툴팁에 함께 표시할 통화 기호다(예: "₩").
  final String currency;

  /// 차트 상단에 표시할 섹션 제목이다.
  final String title;

  /// 기간 시작일이다. 최고/최저 지출일의 실제 날짜 계산에 사용된다.
  final DateTime? rangeStart;

  /// 최고 지출일 레이블이다. null이면 최고/최저 지출일 영역을 표시하지 않는다.
  final String? maxLabel;

  /// 최저 지출일 레이블이다. null이면 최고/최저 지출일 영역을 표시하지 않는다.
  final String? minLabel;

  /// Y축에 표시할 금액 약식 문자열을 반환한다(만원 단위).
  static String _yLabel(double v) {
    if (v >= 10000) {
      final double wan = v / 10000;
      return wan == wan.truncateToDouble()
          ? '${wan.toInt()}만'
          : '${wan.toStringAsFixed(1)}만';
    }
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toInt().toString();
  }

  /// [FlSpot.x](1-based 일 번호)를 날짜 문자열로 변환한다.
  String _formatDayLabel(FlSpot spot) {
    if (rangeStart == null) return '${spot.x.toInt()}일';
    final DateTime date = rangeStart!.add(Duration(days: spot.x.toInt() - 1));
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  @override
  Widget build(BuildContext context) {
    /// 유효 데이터가 없으면 아무것도 렌더링하지 않는다.
    if (spots.isEmpty) return const SizedBox.shrink();
    if (spots.every((FlSpot s) => s.y == 0)) return const SizedBox.shrink();

    final double maxY =
        spots
            .map((FlSpot s) => s.y)
            .reduce((double a, double b) => a > b ? a : b) *
        1.3;

    final FlSpot maxSpot =
        spots.reduce((FlSpot a, FlSpot b) => a.y >= b.y ? a : b);
    final FlSpot minSpot =
        spots.reduce((FlSpot a, FlSpot b) => a.y <= b.y ? a : b);

    final bool showMaxMin = maxLabel != null && minLabel != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        /// 차트 섹션 제목 라벨이다.
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),

        /// fl_chart LineChart로 일별 지출 꺾은선 그래프를 그리는 영역이다.
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              /// 데이터 라인 정의: 파란색 곡선에 하단 그라디언트 채우기를 적용한다.
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

              /// X/Y 축 타이틀 설정이다.
              titlesData: FlTitlesData(
                /// Y축 좌측에 만원 단위 금액 라벨을 표시한다.
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
                          _yLabel(value),
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

                /// X축 하단에 일 번호를 5 간격으로 표시한다.
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 5,
                    reservedSize: 22,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              /// 가로 격자선만 표시한다(세로선 숨김).
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (double value) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),

              /// 테두리 선은 표시하지 않는다.
              borderData: FlBorderData(show: false),

              minX: spots.first.x,
              maxX: spots.last.x,
              minY: 0,
              maxY: maxY,

              /// 터치 시 해당 일·금액 툴팁을 표시하는 설정이다.
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (LineBarSpot spot) =>
                      const Color(0xFF222222),
                  getTooltipItems: (List<LineBarSpot> touchedSpots) =>
                      touchedSpots.map((LineBarSpot spot) {
                        return LineTooltipItem(
                          '${spot.x.toInt()}\n${spot.y.toInt().toCurrency()}$currency',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        ),

        /// 최고/최저 지출일 요약 영역이다. maxLabel이 지정된 경우에만 표시한다.
        if (showMaxMin) ...<Widget>[
          const SizedBox(height: 12),
          _buildDayStatRow(
            context,
            label: maxLabel!,
            spot: maxSpot,
            color: const Color(0xFFDC3545),
          ),
          const SizedBox(height: 4),
          _buildDayStatRow(
            context,
            label: minLabel!,
            spot: minSpot,
            color: const Color(0xFF198754),
          ),
        ],
      ],
    );
  }

  /// 최고/최저 지출일 한 줄 표시 행이다(레이블 | 날짜 ... 금액).
  Widget _buildDayStatRow(
    BuildContext context, {
    required String label,
    required FlSpot spot,
    required Color color,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '$label : ${_formatDayLabel(spot)}',
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
  }
}
