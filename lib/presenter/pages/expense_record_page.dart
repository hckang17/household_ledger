import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/presenter/common/widgets/expense_entry_tile.dart';
import 'package:household_ledger/presenter/common/widgets/expense_calendar_section.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/presenter/common/widgets/expense_editor_sheet.dart';
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

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

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

    final groupedEntries = _groupEntriesByDay(visibleEntries);
    final currency = _currencyUnit(strings);
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
      actions: <Widget>[
        IconButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRouter.dataManageRoute),
          icon: const Icon(Icons.manage_search_rounded),
          tooltip: strings['dataManageTitle'] ?? '데이터 관리',
        ),
        IconButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRouter.settingsRoute),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
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
          ExpenseCalendarSection(
            focusedMonth: _focusedMonth,
            selectedDay: _selectedDay,
            entries: monthEntries,
            currency: currency,
            strings: strings,
            totalSpentLabel: totalSpentLabel,
            remainingBudgetLabel: remainingBudgetLabel,
            monthlySpent: monthlySpent,
            monthlyRemaining: monthlyRemaining,
            onFocusedMonthChanged: (DateTime newMonth) => setState(() {
              _focusedMonth = newMonth;
              _selectedDay = DateTime(newMonth.year, newMonth.month, 1);
              _filterBySelectedDay = false;
            }),
            onSelectedDayChanged: (DateTime day) =>
                setState(() => _selectedDay = day),
            onQueryByDate: () => setState(() => _filterBySelectedDay = true),
            onViewMonthly: () => setState(() => _filterBySelectedDay = false),
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
                                  categoryLabel: categoryTags.labelFor(
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
