import 'package:flutter/material.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/widgets/expense_entry_tile.dart';

/// 이번 달 지출 중 최근 5건을 날짜별로 묶어 표시하는 위젯이다.
class RecentExpensesList extends StatelessWidget {
  const RecentExpensesList({
    required this.entries,
    required this.categoryTags,
    required this.subcategoryTags,
    required this.paymentTags,
    required this.currency,
    required this.strings,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<ExpenseEntry> entries;
  final List<MetadataTag> categoryTags;
  final List<MetadataTag> subcategoryTags;
  final List<MetadataTag> paymentTags;
  final String currency;
  final Map<String, String> strings;
  final ValueChanged<ExpenseEntry> onTap;
  final ValueChanged<ExpenseEntry> onEdit;
  final ValueChanged<ExpenseEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(strings['emptyData'] ?? '데이터가 없습니다.'),
        ),
      );
    }

    final List<ExpenseEntry> sorted = entries.toList()
      ..sort(
        (ExpenseEntry a, ExpenseEntry b) => b.spentAt.compareTo(a.spentAt),
      );
    final List<ExpenseEntry> recent = sorted.take(5).toList();

    final Map<DateTime, List<ExpenseEntry>> grouped =
        <DateTime, List<ExpenseEntry>>{};
    for (final ExpenseEntry e in recent) {
      final DateTime day =
          DateTime(e.spentAt.year, e.spentAt.month, e.spentAt.day);
      grouped.putIfAbsent(day, () => <ExpenseEntry>[]).add(e);
    }
    final List<MapEntry<DateTime, List<ExpenseEntry>>> groupedList =
        grouped.entries.toList()
          ..sort(
            (
              MapEntry<DateTime, List<ExpenseEntry>> a,
              MapEntry<DateTime, List<ExpenseEntry>> b,
            ) => b.key.compareTo(a.key),
          );

    final String daySectionTemplate =
        strings['expenseRecordDaySectionLabel'] ?? '{month}월 {day}일';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final MapEntry<DateTime, List<ExpenseEntry>> section
            in groupedList) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
            child: Text(
              daySectionTemplate
                  .replaceAll(
                    '{month}',
                    section.key.month.toString().padLeft(2, '0'),
                  )
                  .replaceAll(
                    '{day}',
                    section.key.day.toString().padLeft(2, '0'),
                  ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1F3A5F),
              ),
            ),
          ),
          for (final ExpenseEntry entry in section.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ExpenseEntryTile(
                entry: entry,
                categoryLabel: categoryTags.labelFor(entry.categoryCode),
                currency: currency,
                editTooltip: strings['edit'] ?? '수정',
                deleteTooltip: strings['delete'] ?? '삭제',
                onTap: () => onTap(entry),
                onEdit: () => onEdit(entry),
                onDelete: () => onDelete(entry),
              ),
            ),
        ],
      ],
    );
  }
}
