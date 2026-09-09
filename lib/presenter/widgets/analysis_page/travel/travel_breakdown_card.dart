import 'package:flutter/material.dart';
import 'package:household_ledger/features/travel/models/travel_summary.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';

/// 여행 지출의 코드별 금액과 비율을 가로 막대로 표시한다.
class TravelBreakdownCard extends StatelessWidget {
  const TravelBreakdownCard({
    required this.title,
    required this.items,
    required this.tags,
    required this.currency,
    super.key,
  });

  final String title;
  final List<TravelBreakdownItem> items;
  final List<MetadataTag> tags;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text('-')
          else
            for (final item in items) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      tags.labelFor(item.code),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${item.amount.toCurrency()}$currency · ${item.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: (item.percentage / 100).clamp(0.0, 1.0),
                  color: const Color(0xFF6F42C1),
                  backgroundColor: const Color(0xFFE9ECEF),
                ),
              ),
              const SizedBox(height: 13),
            ],
        ],
      ),
    );
  }
}
