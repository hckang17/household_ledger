import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/monthly_spending_forecast_provider.dart';
import 'package:intl/intl.dart';

/// 월별·이번 달 조건은 계산 결과의 null 여부로 통일해 숨김 조건을 유지한다.
class AnalysisForecastCard extends ConsumerWidget {
  const AnalysisForecastCard({
    required this.input,
    required this.strings,
    required this.currency,
    this.monthlyBudget = const AsyncData(0),
    super.key,
  });

  final MonthlySpendingForecastInput input;
  final Map<String, String> strings;
  final String currency;
  final AsyncValue<int> monthlyBudget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(monthlySpendingForecastProvider(input));
    if (result == null) return const SizedBox.shrink();
    final actualColor = Theme.of(context).colorScheme.primary;
    const forecastColor = Color(0xFFB56000);
    const budgetColor = Color(0xFF21805B);
    // 예산 로딩/실패를 0원으로 오인하지 않고 확인된 양수 예산만 그린다.
    final budget = monthlyBudget.asData?.value;
    String money(int amount) => '${amount.toCurrency()}$currency';
    final compactAmount = NumberFormat.compact(
      locale:
          Localizations.localeOf(context).languageCode == 'ja' ||
              currency == '円'
          ? 'ja'
          : 'ko',
    );
    // 금액 크기와 무관하게 네 구간의 읽기 쉬운 눈금을 만든다.
    final targetStep =
        math.max(math.max(result.monthEndAmount, budget ?? 0), 100) / 3;
    final magnitude = math
        .pow(10, (math.log(targetStep) / math.ln10).floor())
        .toDouble();
    final step = (targetStep / magnitude).ceil() * magnitude;
    final todayX = input.today.day.toDouble();
    final actualLine = LineChartBarData(
      spots: result.actual
          .map((p) => FlSpot(p.dayOffset.toDouble(), p.amount.toDouble()))
          .toList(),
      color: actualColor,
      barWidth: 3,
      showingIndicators: [result.actual.length - 1],
      dotData: FlDotData(
        checkToShowDot: (spot, _) => spot.x == todayX,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: 5,
          color: actualColor,
          strokeWidth: 2,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            actualColor.withValues(alpha: 0.16),
            actualColor.withValues(alpha: 0.02),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BootstrapSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings['forecastTitle']!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            for (final metric in <(String, int)>[
              ('forecastActual', result.accumulatedAmount),
              ('forecastFixed', result.fixedAmount),
              ('forecastAverage', result.dailyAverage),
              ('forecastRemaining', result.remainingAmount),
              ('forecastMonthEnd', result.monthEndAmount),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 12,
                  children: [
                    Text(strings[metric.$1]!),
                    Text(
                      money(metric.$2),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            Text(strings['forecastLegend']!),
            monthlyBudget.when(
              loading: () => Text(strings['forecastBudgetLoading']!),
              error: (_, _) => Text(strings['forecastBudgetError']!),
              data: (amount) => amount > 0
                  ? Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(width: 24, height: 3, color: budgetColor),
                        Text(
                          '${strings['forecastBudget']!} ${money(amount)}',
                          style: const TextStyle(
                            color: budgetColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: result.daysInMonth.toDouble(),
                  minY: 0,
                  maxY: step * 4,
                  showingTooltipIndicators: [
                    ShowingTooltipIndicators([
                      LineBarSpot(actualLine, 0, actualLine.spots.last),
                    ]),
                  ],
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (budget != null && budget > 0)
                        HorizontalLine(
                          y: budget.toDouble(),
                          color: budgetColor,
                          strokeWidth: 3,
                        ),
                    ],
                    verticalLines: [
                      VerticalLine(
                        x: todayX,
                        color: actualColor.withValues(alpha: 0.4),
                        strokeWidth: 1,
                        dashArray: [3, 4],
                      ),
                    ],
                  ),
                  lineBarsData: [
                    actualLine,
                    if (result.projected.isNotEmpty)
                      LineChartBarData(
                        spots: result.projected
                            .map(
                              (p) => FlSpot(
                                p.dayOffset.toDouble(),
                                p.amount.toDouble(),
                              ),
                            )
                            .toList(),
                        color: forecastColor,
                        barWidth: 3,
                        dashArray: [6, 4],
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        currency,
                        style: const TextStyle(fontSize: 11),
                      ),
                      axisNameSize: 22,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        interval: step,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            compactAmount.format(value),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
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
                        interval: 7,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${value.toInt()}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: step,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300),
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    // 기본 터치 처리가 상시 툴팁을 덮어쓰지 않도록 한다.
                    handleBuiltInTouches: false,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF25344A),
                      tooltipRoundedRadius: 10,
                      tooltipMargin: 12,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              spot.x == todayX && spot.barIndex == 0
                                  ? '${strings['todayDateCompact']!.replaceAll('{date}', '${input.today.month}/${input.today.day}')}\n${strings['forecastCumulativeSpending']!}\n${money(spot.y.round())}'
                                  : '${strings[spot.barIndex == 0 ? 'forecastCumulativeSpending' : 'forecastEstimate']}\n${spot.x.toInt()}${strings['chartDateDaySuffix']!}\n${money(spot.y.round())}',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                // 기간 전환 시 실적선과 예측선이 보간되어 섞이지 않도록 한다.
                duration: Duration.zero,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings['forecastExplanation']!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (result.variableAmount == 0)
              Text(
                strings['forecastNoSpending']!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
