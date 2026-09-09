import 'package:flutter/material.dart';
import 'package:household_ledger/features/travel/calculators/travel_summary_calculator.dart';
import 'package:household_ledger/features/travel/models/travel_expense_timing.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/common/expense_entry_tile.dart';

/// 여행 지출을 여행 전·여행 중·여행 후로 나누어 표시한다.
class TravelExpenseList extends StatelessWidget {
  const TravelExpenseList({
    required this.trip,
    required this.expenses,
    required this.categoryTags,
    required this.currency,
    required this.strings,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final Trip trip;
  final List<ExpenseEntry> expenses;
  final List<MetadataTag> categoryTags;
  final String currency;
  final Map<String, String> strings;
  final ValueChanged<ExpenseEntry> onTap;
  final ValueChanged<ExpenseEntry> onEdit;
  final ValueChanged<ExpenseEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            strings['travelExpenseEmptyMessage'] ?? '이 여행에 연결된 지출이 없습니다.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final groups = <TravelExpenseTiming, List<ExpenseEntry>>{
      for (final timing in TravelExpenseTiming.values) timing: <ExpenseEntry>[],
    };
    for (final entry in expenses) {
      groups[const TravelSummaryCalculator().timingOf(entry.spentAt, trip)]!
          .add(entry);
    }
    for (final group in groups.values) {
      group.sort(
        (ExpenseEntry left, ExpenseEntry right) =>
            right.spentAt.compareTo(left.spentAt),
      );
    }

    return Column(
      children: <Widget>[
        for (final timing in TravelExpenseTiming.values)
          if (groups[timing]!.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Row(
                children: <Widget>[
                  Text(
                    _timingLabel(timing),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${groups[timing]!.length}${strings['travelExpenseCountUnit'] ?? '건'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            for (final dateGroup in _groupByDate(groups[timing]!)) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _dateLabel(dateGroup.key),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF6C757D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              for (final entry in dateGroup.value) ...<Widget>[
                ExpenseEntryTile(
                  entry: entry,
                  categoryLabel: categoryTags.labelFor(entry.categoryCode),
                  currency: currency,
                  editTooltip: strings['edit'] ?? '수정',
                  deleteTooltip: strings['delete'] ?? '삭제',
                  onTap: () => onTap(entry),
                  onEdit: () => onEdit(entry),
                  onDelete: () => onDelete(entry),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
      ],
    );
  }

  String _timingLabel(TravelExpenseTiming timing) => switch (timing) {
    TravelExpenseTiming.before => strings['travelBeforeLabel'] ?? '여행 전',
    TravelExpenseTiming.during => strings['travelDuringLabel'] ?? '여행 중',
    TravelExpenseTiming.after => strings['travelAfterLabel'] ?? '여행 후',
  };

  List<MapEntry<DateTime, List<ExpenseEntry>>> _groupByDate(
    List<ExpenseEntry> entries,
  ) {
    final grouped = <DateTime, List<ExpenseEntry>>{};
    for (final entry in entries) {
      final date = DateTime(
        entry.spentAt.year,
        entry.spentAt.month,
        entry.spentAt.day,
      );
      grouped.putIfAbsent(date, () => <ExpenseEntry>[]).add(entry);
    }
    final dates = grouped.keys.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));
    return dates
        .map(
          (DateTime date) =>
              MapEntry<DateTime, List<ExpenseEntry>>(date, grouped[date]!),
        )
        .toList(growable: false);
  }

  String _dateLabel(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
