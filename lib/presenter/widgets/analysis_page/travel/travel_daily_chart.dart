import 'package:flutter/material.dart';
import 'package:household_ledger/features/travel/models/travel_summary.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';

/// 실제 여행 기간 안의 일자별 지출을 비교 가능한 막대로 표시한다.
class TravelDailyChart extends StatelessWidget {
  const TravelDailyChart({
    required this.items,
    required this.currency,
    required this.strings,
    super.key,
  });

  final List<TravelDailyAmount> items;
  final String currency;
  final Map<String, String> strings;

  @override
  Widget build(BuildContext context) {
    final maxAmount = items.fold<int>(
      0,
      (int current, TravelDailyAmount item) =>
          item.amount > current ? item.amount : current,
    );
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings['travelDailyChartTitle'] ?? '여행 중 일자별 지출',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            strings['travelDailyChartDescription'] ??
                '여행 전후에 결제한 금액은 이 차트에서 제외됩니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final item in items) ...<Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 58,
                  child: Text(
                    '${item.dayNumber}${strings['travelDayOrdinalSuffix'] ?? '일차'}',
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 12,
                      value: maxAmount == 0
                          ? 0
                          : (item.amount / maxAmount).clamp(0.0, 1.0),
                      color: const Color(0xFF0D6EFD),
                      backgroundColor: const Color(0xFFE9ECEF),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: Text(
                    '${item.amount.toCurrency()}$currency',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
