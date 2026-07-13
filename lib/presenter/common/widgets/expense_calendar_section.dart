import 'package:flutter/material.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:intl/intl.dart';

/// 달력 그리드, 월 네비게이션, 월 요약 타일을 묶은 섹션 카드다.
///
/// [_isCalendarExpanded] 만 내부 상태로 관리한다. 나머지 상태 및 데이터는
/// 부모로부터 props 로 받고, 변경 사항은 콜백으로 돌려준다.
class ExpenseCalendarSection extends StatefulWidget {
  const ExpenseCalendarSection({
    required this.focusedMonth,
    required this.selectedDay,
    required this.entries,
    required this.currency,
    required this.strings,
    required this.totalSpentLabel,
    required this.remainingBudgetLabel,
    required this.monthlySpent,
    required this.monthlyRemaining,
    required this.onFocusedMonthChanged,
    required this.onSelectedDayChanged,
    required this.onQueryByDate,
    required this.onViewMonthly,
    super.key,
  });

  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<ExpenseEntry> entries;
  final String currency;
  final Map<String, String> strings;
  final String totalSpentLabel;
  final String remainingBudgetLabel;
  final int monthlySpent;
  final int monthlyRemaining;
  final ValueChanged<DateTime> onFocusedMonthChanged;
  final ValueChanged<DateTime> onSelectedDayChanged;
  final VoidCallback onQueryByDate;
  final VoidCallback onViewMonthly;

  @override
  State<ExpenseCalendarSection> createState() => _ExpenseCalendarSectionState();
}

class _ExpenseCalendarSectionState extends State<ExpenseCalendarSection> {
  bool _isCalendarExpanded = true;

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  List<DateTime?> _calendarCells(DateTime month) {
    final DateTime first = DateTime(month.year, month.month, 1);
    final int leading = first.weekday % 7;
    final int daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final int total = leading + daysInMonth;
    final int trailing = (7 - (total % 7)) % 7;
    return <DateTime?>[
      for (int i = 0; i < leading; i++) null,
      for (int day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
      for (int i = 0; i < trailing; i++) null,
    ];
  }

  Map<int, int> _dailyTotals(List<ExpenseEntry> entries) {
    final Map<int, int> totals = <int, int>{};
    for (final ExpenseEntry entry in entries) {
      if (entry.spentAt.year == widget.focusedMonth.year &&
          entry.spentAt.month == widget.focusedMonth.month) {
        totals.update(
          entry.spentAt.day,
          (int value) => value + entry.amount,
          ifAbsent: () => entry.amount,
        );
      }
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime?> calendarCells = _calendarCells(widget.focusedMonth);
    final Map<int, int> dailyTotals = _dailyTotals(widget.entries);
    final String todayText = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final Map<String, String> strings = widget.strings;

    return BootstrapSectionCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  (strings['todayDateCompact'] ??
                          '${strings['failedReadingData']}+todayDateCompact')
                      .replaceAll('{date}', todayText),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: _isCalendarExpanded
                    ? (strings['calendarFold'] ??
                          '${strings['failedReadingData']}+calendarFold')
                    : (strings['calendarUnfold'] ??
                          '${strings['failedReadingData']}+calendarUnfold'),
                onPressed: () =>
                    setState(() => _isCalendarExpanded = !_isCalendarExpanded),
                icon: Icon(
                  _isCalendarExpanded ? Icons.expand_less : Icons.expand_more,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _isCalendarExpanded
                ? Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () => widget.onFocusedMonthChanged(
                              DateTime(
                                widget.focusedMonth.year,
                                widget.focusedMonth.month - 1,
                              ),
                            ),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                DateFormat('yyyy-MM').format(widget.focusedMonth),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => widget.onFocusedMonthChanged(
                              DateTime(
                                widget.focusedMonth.year,
                                widget.focusedMonth.month + 1,
                              ),
                            ),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      Row(
                        children: const <Widget>[
                          Expanded(child: Center(child: Text('Sun'))),
                          Expanded(child: Center(child: Text('Mon'))),
                          Expanded(child: Center(child: Text('Tue'))),
                          Expanded(child: Center(child: Text('Wed'))),
                          Expanded(child: Center(child: Text('Thu'))),
                          Expanded(child: Center(child: Text('Fri'))),
                          Expanded(child: Center(child: Text('Sat'))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: calendarCells.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisExtent: 40,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                            ),
                        itemBuilder: (BuildContext context, int index) {
                          final DateTime? date = calendarCells[index];
                          if (date == null) return const SizedBox.shrink();

                          final bool isSelected =
                              _sameDay(date, widget.selectedDay);
                          final int amount = dailyTotals[date.day] ?? 0;

                          return InkWell(
                            onTap: () =>
                                widget.onSelectedDayChanged(_dateOnly(date)),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE7F1FF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 2,
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Text(
                                    '${date.day}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: amount != 0
                                        ? Text(
                                            '${amount.toCurrency()}${widget.currency}',
                                            maxLines: 1,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color:
                                                      const Color(0xFF0D6EFD),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 9,
                                                  height: 1,
                                                ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: BootstrapActionButton(
                              label: strings['queryByDate'] ?? '조회하기',
                              icon: Icons.search,
                              onPressed: widget.onQueryByDate,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: BootstrapActionButton(
                              label: strings['viewMonthly'] ?? '월 전체 보기',
                              icon: Icons.view_list,
                              onPressed: widget.onViewMonthly,
                              backgroundColor: const Color(0xFF6C757D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: BootstrapSummaryTile(
                  label: widget.totalSpentLabel,
                  value: '${widget.monthlySpent.toCurrency()} ${widget.currency}',
                  color: const Color(0xFFDC3545),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BootstrapSummaryTile(
                  label: widget.remainingBudgetLabel,
                  value:
                      '${widget.monthlyRemaining.toCurrency()} ${widget.currency}',
                  color: const Color(0xFF198754),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
