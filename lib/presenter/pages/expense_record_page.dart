import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/presenter/common/bottom_navigation_bar.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/widgets/expense_entry_tile.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/presenter/common/widgets/expense_editor_sheet.dart';
import 'package:intl/intl.dart';

/// 소비 기록 페이지다.
class ExpenseRecordPage extends ConsumerStatefulWidget {
  /// 소비 기록 페이지를 생성한다.
  const ExpenseRecordPage({super.key});

  @override
  ConsumerState<ExpenseRecordPage> createState() => _ExpenseRecordPageState();
}

/// 소비 기록 페이지의 날짜 선택 상태를 관리한다.
class _ExpenseRecordPageState extends ConsumerState<ExpenseRecordPage> {
  DateTime _selectedDay = DateTime.now();
  late DateTime _focusedMonth;
  bool _isCalendarExpanded = false;
  bool _filterBySelectedDay = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _currencyUnit(Map<String, String> strings) {
    return strings['currencyUnit'] ?? 'null';
  }

  String _text(Map<String, String> strings, String tag) {
    return strings[tag] ??
        '${strings['failedReadingData'] ?? 'ErrorCode: 4401'}+$tag';
  }

  String _monthLabel(String template, int month) {
    return template.replaceAll('{month}', '$month');
  }

  String _daySectionLabel(Map<String, String> strings, DateTime date) {
    final template = _text(strings, 'expenseRecordDaySectionLabel');
    return template
        .replaceAll('{month}', date.month.toString().padLeft(2, '0'))
        .replaceAll('{day}', date.day.toString().padLeft(2, '0'));
  }

  void _changeFocusedMonth(int monthDelta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + monthDelta,
      );
      _selectedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      _filterBySelectedDay = false;
    });
  }

  List<DateTime?> _calendarCells(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final total = leading + daysInMonth;
    final trailing = (7 - (total % 7)) % 7;

    return <DateTime?>[
      for (int i = 0; i < leading; i++) null,
      for (int day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
      for (int i = 0; i < trailing; i++) null,
    ];
  }

  Map<int, int> _dailyTotals(List<ExpenseEntry> entries) {
    final totals = <int, int>{};
    for (final entry in entries) {
      if (entry.spentAt.year == _focusedMonth.year &&
          entry.spentAt.month == _focusedMonth.month) {
        totals.update(
          entry.spentAt.day,
          (int value) => value + entry.amount,
          ifAbsent: () => entry.amount,
        );
      }
    }
    return totals;
  }

  List<MapEntry<DateTime, List<ExpenseEntry>>> _groupEntriesByDay(
    List<ExpenseEntry> entries,
  ) {
    final grouped = <DateTime, List<ExpenseEntry>>{};
    for (final entry in entries) {
      final key = _dateOnly(entry.spentAt);
      grouped.putIfAbsent(key, () => <ExpenseEntry>[]).add(entry);
    }

    final keys = grouped.keys.toList()
      ..sort((DateTime left, DateTime right) => right.compareTo(left));
    return keys
        .map(
          (DateTime key) =>
              MapEntry<DateTime, List<ExpenseEntry>>(key, grouped[key]!),
        )
        .toList();
  }

  /// 소비 기록 삭제 여부를 확인한 뒤 삭제한다.
  Future<void> _delete(ExpenseEntry entry) async {
    final strings = ref.read(localizedStringsProvider);
    final currency = _currencyUnit(strings);
    final summary =
        '${entry.description} : ${entry.amount.toCurrency()}$currency\n${_text(strings, 'deleteAlertCaution')}';
    final confirmed = await showLedgerConfirmDialog(
      context: context,
      title: _text(strings, 'confirmDelete'),
      message: '$summary ${_text(strings, 'confirmDeleteQuestion')}',
      confirmLabel: _text(strings, 'delete'),
      cancelLabel: _text(strings, 'cancel'),
    );
    if (!confirmed) {
      return;
    }

    await ref.read(ledgerProvider.notifier).deleteExpense(entry.id);
    ref.invalidate(monthlyExpensesProvider);
    ref.invalidate(rangeExpensesProvider);
  }

  /// 코드에 해당하는 태그 라벨을 반환한다. <- 반복되는 코드임.
  String _resolveTagLabel(List<MetadataTag> tags, String code) {
    final match = tags.where((MetadataTag tag) => tag.code == code);
    if (match.isEmpty) {
      return code;
    }

    return match.first.label;
  }

  void _showDetail(
    ExpenseEntry entry,
    List<MetadataTag> categoryTags,
    List<MetadataTag> subcategoryTags,
    List<MetadataTag> paymentTags,
    Map<String, String> strings,
  ) {
    showExpenseDetailDialog(
      context: context,
      entry: entry,
      categoryTags: categoryTags,
      subcategoryTags: subcategoryTags,
      paymentTags: paymentTags,
      strings: strings,
      currency: _currencyUnit(strings),
    );
  }

  /// Builder에서 소비 기록 데이터를 로딩하여 화면에 표시한다.
  @override
  Widget build(BuildContext context) {
    /// 로컬라이징 문자열 프로바이더를 읽어온다.
    final strings = ref.watch(localizedStringsProvider);

    /// 가계부 데이터 프로바이더를 읽어온다.
    final ledger = ref.watch(ledgerProvider).asData?.value;
    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    /// 선택된 월의 소비 기록과 수입 기록을 로딩한다. 로딩 중이거나 에러가 발생하면 로딩 인디케이터 또는 에러 메시지를 표시한다.
    final monthEntriesAsync = ref.watch(monthlyExpensesProvider(_focusedMonth));
    if (monthEntriesAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    /// 에러가 발생한 경우 에러 메시지를 표시한다.
    if (monthEntriesAsync.hasError) {
      return Scaffold(
        body: Center(child: Text(monthEntriesAsync.error.toString())),
      );
    }
    final monthEntries =
        monthEntriesAsync.asData?.value ?? const <ExpenseEntry>[];
    final incomeEntriesAsync = ref.watch(monthlyIncomesProvider(_focusedMonth));
    if (incomeEntriesAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (incomeEntriesAsync.hasError) {
      return Scaffold(
        body: Center(child: Text(incomeEntriesAsync.error.toString())),
      );
    }
    final monthlyIncomeEntries =
        incomeEntriesAsync.asData?.value ?? const <IncomeEntry>[];

    /// 선택된 날짜로 소비 기록을 필터링한다.
    final visibleEntries = _filterBySelectedDay
        ? monthEntries
              .where(
                (ExpenseEntry entry) => _sameDay(entry.spentAt, _selectedDay),
              )
              .toList()
        : monthEntries;

    /// 달력 셀, 일별 합계, 날짜별 소비 기록 그룹, 통화 단위를 계산한다.
    final calendarCells = _calendarCells(_focusedMonth);
    final dailyTotals = _dailyTotals(monthEntries);
    final groupedEntries = _groupEntriesByDay(visibleEntries);
    final currency = _currencyUnit(strings);
    final todayText = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final categoryTags = ledger.tagsByType(MetadataTagType.category);
    final subcategoryTags = ledger.tagsByType(MetadataTagType.subcategory);
    final paymentTags = ledger.tagsByType(MetadataTagType.paymentMethod);
    final totalSpentLabel = _monthLabel(
      strings['monthlyTotalSpentLabel'] ?? '{month} total spent(error)',
      _focusedMonth.month,
    );
    final remainingBudgetLabel = _monthLabel(
      strings['monthlyRemainingBudgetLabel'] ??
          '{month} remaining budget(error)',
      _focusedMonth.month,
    );
    final monthlySpent = monthEntries.fold<int>(
      0,
      (int total, ExpenseEntry entry) => total + entry.amount,
    );
    final monthlyIncome = monthlyIncomeEntries.fold<int>(
      0,
      (int total, IncomeEntry entry) => total + entry.amount,
    );
    final monthlyBudget = monthlyIncome > 0
        ? monthlyIncome
        : ledger.settings.monthlyBudget;
    final monthlyFixedExpense = ledger.fixedExpenseTotalForMonth(_focusedMonth);
    final monthlyRemaining = monthlyBudget - monthlySpent - monthlyFixedExpense;

    /// 페이지를 렌더링한다.
    return BootstrapPage(
      title: _text(strings, 'expenseRecordTitle'),
      bottomNavigationBar: const LedgerBottomNavBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseEditorSheet(
          context: context,
          ref: ref,
          initialDate: _selectedDay,
        ),
        label: Text(_text(strings, 'addExpense')),
        icon: const Icon(Icons.add),
      ),
      child: Column(
        children: <Widget>[
          /// 달력과 일별/월별 보기 토글 버튼을 렌더링한다.
          BootstrapSectionCard(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        (strings['todayDateCompact'] ??
                                '${strings['failedReadingData']}+todayDateCompact')
                            .replaceAll('{date}', todayText),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: _isCalendarExpanded
                          ? (strings['calendarFold'] ??
                                "${strings['failedReadingData']}+calendarFold")
                          : (strings['calendarUnfold'] ??
                                "${strings['failedReadingData']}+calendarUnfold"),
                      onPressed: () {
                        setState(() {
                          _isCalendarExpanded = !_isCalendarExpanded;
                        });
                      },
                      icon: Icon(
                        _isCalendarExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
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
                            // const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                IconButton(
                                  onPressed: () => _changeFocusedMonth(-1),
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      DateFormat(
                                        'yyyy-MM',
                                      ).format(_focusedMonth),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _changeFocusedMonth(1),
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                            // const SizedBox(height: 8),
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
                                final date = calendarCells[index];
                                if (date == null) {
                                  return const SizedBox.shrink();
                                }

                                final isSelected = _sameDay(date, _selectedDay);
                                final amount = dailyTotals[date.day] ?? 0;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedDay = _dateOnly(date);
                                    });
                                  },
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
                                                  '${amount.toCurrency()}$currency',
                                                  maxLines: 1,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: const Color(
                                                          0xFF0D6EFD,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                    onPressed: () {
                                      setState(() {
                                        _filterBySelectedDay = true;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: BootstrapActionButton(
                                    label: strings['viewMonthly'] ?? '월 전체 보기',
                                    icon: Icons.view_list,
                                    onPressed: () {
                                      setState(() {
                                        _filterBySelectedDay = false;
                                      });
                                    },
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
                    /// 월 총 지출 표시 타일
                    Expanded(
                      child: BootstrapSummaryTile(
                        label: totalSpentLabel,
                        value: '${monthlySpent.toCurrency()} $currency',
                        color: const Color(0xFFDC3545),
                      ),
                    ),
                    const SizedBox(width: 12),

                    /// 잔여 예산 표시 타일
                    Expanded(
                      child: BootstrapSummaryTile(
                        label: remainingBudgetLabel,
                        value: '${monthlyRemaining.toCurrency()} $currency',
                        color: const Color(0xFF198754),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          /// 소비 기록 리스트를 렌더링한다. 기록이 없으면 안내 메시지를 표시한다.
          Expanded(
            child: visibleEntries.isEmpty
                ? Center(child: Text(_text(strings, 'emptyData')))
                : ListView.builder(
                    itemCount: groupedEntries.length,
                    itemBuilder: (BuildContext context, int sectionIndex) {
                      final section = groupedEntries[sectionIndex];
                      final sectionDate = section.key;
                      final sectionItems = section.value;
                      final sectionLabel = _daySectionLabel(
                        strings,
                        sectionDate,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                              ),
                              child: Text(
                                sectionLabel,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1F3A5F),
                                    ),
                              ),
                            ),
                            ...sectionItems.map((ExpenseEntry entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: ExpenseEntryTile(
                                  entry: entry,
                                  categoryLabel: _resolveTagLabel(
                                    categoryTags,
                                    entry.categoryCode,
                                  ),
                                  currency: currency,
                                  editTooltip: _text(strings, 'edit'),
                                  deleteTooltip: _text(strings, 'delete'),
                                  onTap: () => _showDetail(
                                    entry,
                                    categoryTags,
                                    subcategoryTags,
                                    paymentTags,
                                    strings,
                                  ),
                                  onEdit: () => showExpenseEditorSheet(
                                    context: context,
                                    ref: ref,
                                    entry: entry,
                                    initialDate: _selectedDay,
                                  ),
                                  onDelete: () => _delete(entry),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
