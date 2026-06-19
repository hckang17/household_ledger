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
    super.key,
  });

  /// 그래프에 표시할 데이터 포인트 목록이다.
  /// [FlSpot.x]는 일 번호(1-based), [FlSpot.y]는 해당일 지출액이다.
  final List<FlSpot> spots;

  /// 툴팁에 함께 표시할 통화 기호다(예: "₩").
  final String currency;

  /// 차트 상단에 표시할 섹션 제목이다.
  final String title;

  @override
  Widget build(BuildContext context) {
    /// 유효 데이터가 없으면 아무것도 렌더링하지 않는다.
    if (spots.isEmpty) return const SizedBox.shrink();
    if (spots.every((FlSpot s) => s.y == 0)) return const SizedBox.shrink();

    final double maxY = spots.map((FlSpot s) => s.y).reduce(
          (double a, double b) => a > b ? a : b,
        ) *
        1.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        /// 차트 섹션 제목 라벨이다.
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
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

              /// X/Y 축 타이틀 설정이다. 좌우·상단은 숨기고 하단만 표시한다.
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
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
      ],
    );
  }
}
