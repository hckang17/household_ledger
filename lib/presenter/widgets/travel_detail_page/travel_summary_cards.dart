import 'package:flutter/material.dart';
import 'package:household_ledger/features/travel/models/travel_summary.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';

/// 여행 상세 화면의 핵심 지출 요약을 표시한다.
class TravelSummaryCards extends StatelessWidget {
  const TravelSummaryCards({
    required this.summary,
    required this.strings,
    required this.currency,
    super.key,
  });

  final TravelSummary summary;
  final Map<String, String> strings;
  final String currency;

  String _money(int amount) => '${amount.toCurrency()}$currency';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        BootstrapSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings['travelTotalExpenseLabel'] ?? '총 여행 지출',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Text(
                _money(summary.totalExpense),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFFDC3545),
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (summary.budget != null) ...<Widget>[
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${strings['travelBudgetLabel'] ?? '여행 예산'} ${_money(summary.budget!)}',
                      ),
                    ),
                    Text(
                      '${strings['travelRemainingBudgetLabel'] ?? '남은 예산'} ${_money(summary.remainingBudget!)}',
                      style: TextStyle(
                        color: summary.remainingBudget! < 0
                            ? const Color(0xFFDC3545)
                            : const Color(0xFF198754),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: (summary.budgetUsagePercent! / 100).clamp(0.0, 1.0),
                    color: summary.budgetUsagePercent! > 100
                        ? const Color(0xFFDC3545)
                        : const Color(0xFF0D6EFD),
                    backgroundColor: const Color(0xFFE9ECEF),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${summary.budgetUsagePercent!.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final oneColumn = constraints.maxWidth < 360;
            final itemWidth = oneColumn
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _MetricCard(
                  width: itemWidth,
                  icon: Icons.calendar_today_outlined,
                  label: strings['travelDailyAverageLabel'] ?? '하루 평균',
                  value: _money(summary.averagePerTripDay),
                ),
                _MetricCard(
                  width: itemWidth,
                  icon: Icons.receipt_long_outlined,
                  label: strings['travelExpenseCountLabel'] ?? '지출 건수',
                  value:
                      '${summary.expenseCount}${strings['travelExpenseCountUnit'] ?? '건'} · ${summary.tripDayCount}${strings['travelDayUnit'] ?? '일'}',
                ),
                _MetricCard(
                  width: itemWidth,
                  icon: Icons.directions_transit_outlined,
                  label: strings['travelTransportExpenseLabel'] ?? '교통비',
                  value: _money(summary.transportExpense),
                ),
                _MetricCard(
                  width: itemWidth,
                  icon: Icons.hotel_outlined,
                  label: strings['travelAccommodationExpenseLabel'] ?? '숙박비',
                  value: _money(summary.accommodationExpense),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        BootstrapSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings['travelTimingSummaryTitle'] ?? '여행 전후 지출',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _TimingRow(
                label: strings['travelBeforeLabel'] ?? '여행 전',
                amount: _money(summary.beforeTripExpense),
              ),
              _TimingRow(
                label: strings['travelDuringLabel'] ?? '여행 중',
                amount: _money(summary.duringTripExpense),
              ),
              _TimingRow(
                label: strings['travelAfterLabel'] ?? '여행 후',
                amount: _money(summary.afterTripExpense),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: BootstrapSectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: const Color(0xFF0D6EFD), size: 21),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  const _TimingRow({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
