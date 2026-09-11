import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/travel_management_page/travel_delete_button.dart';

/// 여행의 정체성, 비용 요약, 관리 동작을 구분해 보여주는 목록 카드.
class TravelTripCard extends StatelessWidget {
  const TravelTripCard({
    required this.trip,
    required this.isActive,
    required this.totalExpense,
    required this.currency,
    required this.strings,
    required this.onTap,
    required this.onEdit,
    required this.onArchiveChanged,
    required this.onRetry,
    super.key,
  });

  final Trip trip;
  final bool isActive;
  final AsyncValue<int> totalExpense;
  final String currency;
  final Map<String, String> strings;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final ValueChanged<bool> onArchiveChanged;
  final VoidCallback onRetry;

  String _money(int amount) => '${amount.toCurrency()}$currency';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = trip.isArchived
        ? const Color(0xFF64748B)
        : const Color(0xFF0D6EFD);
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isActive
              ? accent.withValues(alpha: 0.55)
              : theme.colorScheme.outlineVariant,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.luggage_outlined, color: accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _badge(_statusLabel(), accent),
                            if (isActive)
                              _badge(
                                strings['travelActiveLabel'] ?? '사용 중',
                                accent,
                                filled: true,
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 22),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    trip.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '${_dateText(trip.startDate)} – ${_dateText(trip.endDate)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: totalExpense.when(
                  skipLoadingOnRefresh: false,
                  skipLoadingOnReload: false,
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings['travelExpenseLoadError'] ??
                            '여행 지출을 불러오지 못했습니다.',
                      ),
                      IconButton(
                        onPressed: onRetry,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).refreshIndicatorSemanticLabel,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  data: (total) => _costSummary(context, total, accent),
                ),
              ),
            ),
          ),
          if (trip.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(
                trip.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: Text(strings['edit'] ?? '수정'),
                ),
                TextButton.icon(
                  onPressed: () => onArchiveChanged(!trip.isArchived),
                  icon: Icon(
                    trip.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    size: 17,
                  ),
                  label: Text(
                    trip.isArchived
                        ? (strings['travelRestoreButton'] ?? '복원')
                        : (strings['travelArchiveButton'] ?? '보관'),
                  ),
                ),
                TravelDeleteButton(trip: trip),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _costSummary(BuildContext context, int total, Color accent) {
    final theme = Theme.of(context);
    final budget = trip.budget;
    final hasBudget = budget != null && budget > 0;
    final remaining = hasBudget ? budget - total : null;
    final overBudget = remaining != null && remaining < 0;
    final color = overBudget ? theme.colorScheme.error : accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings['travelTotalExpenseLabel'] ?? '총 여행 지출',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _money(total),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (hasBudget) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                '${strings['travelBudgetSummaryLabel'] ?? '예산'} ${_money(budget)}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '${(total / budget * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (total / budget).clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: accent.withValues(alpha: 0.12),
              semanticsLabel: strings['travelBudgetSummaryLabel'],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${overBudget ? (strings['travelOverBudgetLabel'] ?? '예산 초과') : (strings['travelRemainingBudgetLabel'] ?? '남은 예산')} ${_money(remaining!.abs())}',
            style: theme.textTheme.labelLarge?.copyWith(color: color),
          ),
        ] else ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: onEdit,
            child: Text(strings['travelSetBudgetButton'] ?? '여행 예산 설정'),
          ),
        ],
      ],
    );
  }

  Widget _badge(String text, Color color, {bool filled = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: filled ? color : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: filled ? Colors.white : color,
      ),
    ),
  );

  String _statusLabel() {
    if (trip.isArchived) return strings['travelArchivedLabel'] ?? '보관됨';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(trip.startDate)) {
      return strings['travelStatusUpcoming'] ?? '예정';
    }
    if (today.isAfter(trip.endDate)) {
      return strings['travelStatusCompleted'] ?? '완료';
    }
    return strings['travelStatusOngoing'] ?? '여행 중';
  }
}

String _dateText(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
