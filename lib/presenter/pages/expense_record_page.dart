import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/nav_tab_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/presenter/common/widgets/expense_entry_tile.dart';
import 'package:household_ledger/presenter/common/widgets/expense_calendar_section.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/presenter/common/widgets/expense_editor_sheet.dart';
import 'package:household_ledger/services/mock_data_service.dart';
import 'package:showcaseview/showcaseview.dart';

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

  final GlobalKey _calendarKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  bool _showcaseStarted = false;
  BuildContext? _showcaseContext;

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
    if (!confirmed) return;

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

  void _maybeStartShowcase() {
    if (_showcaseStarted) return;
    if (_showcaseContext == null) return;
    final state = ref.read(tutorialProvider);
    if (!state.isActive || state.phase != TutorialPhase.expenseRecord) return;
    _showcaseStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase([
        _calendarKey,
        _fabKey,
      ]);
    });
  }

  void _onShowcaseComplete(int? index, GlobalKey key) {
    if (key == _fabKey) {
      // 소비기록 튜토리얼 완료 → 분석 탭으로 이동
      ref.read(currentNavTabProvider.notifier).setTab(1);
      ref.read(tutorialProvider.notifier).setPhase(TutorialPhase.analysis);
    }
  }

  Future<void> _handleBackDuringTutorial() async {
    if (_showcaseContext != null) {
      try { ShowCaseWidget.of(_showcaseContext!).dismiss(); } catch (_) {}
    }
    final strings = ref.read(localizedStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(strings['tutorialExitTitle'] ?? '튜토리얼 종료'),
        content: Text(strings['tutorialExitMessage'] ?? '튜토리얼을 종료하시겠습니까?\n완료로 처리됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings['tutorialContinue'] ?? '계속하기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings['tutorialExitConfirm'] ?? '종료'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(mockDataServiceProvider).cleanupMockData(ref);
      await ref.read(tutorialProvider.notifier).exitTutorial();
    } else if (mounted) {
      _showcaseStarted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeStartShowcase();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    final isTutorial = ref.watch(
      tutorialProvider.select(
        (s) => s.isActive && s.phase == TutorialPhase.expenseRecord,
      ),
    );

    ref.listen(currentNavTabProvider, (_, tab) {
      if (tab == 3 &&
          ref.read(tutorialProvider).phase == TutorialPhase.expenseRecord) {
        _showcaseStarted = false;
        _maybeStartShowcase();
      }
    });

    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final monthEntriesAsync = ref.watch(monthlyExpensesProvider(_focusedMonth));
    if (monthEntriesAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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

    Widget buildInner(BuildContext showcaseCtx) {
      _showcaseContext = showcaseCtx;
      _maybeStartShowcase();

      final fab = Showcase(
        key: _fabKey,
        title: strings['tutExpenseFabTitle'] ?? '지출 추가',
        description: strings['tutExpenseFabDesc'] ?? '오늘의 소비를 기록해보세요!\n날짜를 선택한 후 + 버튼을 탭하면 해당 날짜로 입력창이 열려요.',
        tooltipPosition: TooltipPosition.top,
        child: FloatingActionButton.extended(
          onPressed: () => showExpenseEditorSheet(
            context: context,
            ref: ref,
            initialDate: _selectedDay,
          ),
          label: Text(_text(strings, 'addExpense')),
          icon: const Icon(Icons.add),
        ),
      );

      final page = BootstrapPage(
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
            tooltip: strings['settingsTitle'] ?? '설정',
          ),
        ],
        floatingActionButton: fab,
        child: Column(
          children: <Widget>[
            Showcase(
              key: _calendarKey,
              title: strings['tutExpenseCalendarTitle'] ?? '캘린더',
              description: strings['tutExpenseCalendarDesc'] ?? '날짜별로 소비 내역을 확인할 수 있어요.\n날짜를 탭하면 해당 날짜의 지출만 필터링됩니다.',
              tooltipPosition: TooltipPosition.bottom,
              child: ExpenseCalendarSection(
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
                onQueryByDate: () =>
                    setState(() => _filterBySelectedDay = true),
                onViewMonthly: () =>
                    setState(() => _filterBySelectedDay = false),
              ),
            ),

            const SizedBox(height: 4),

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

      if (isTutorial) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBackDuringTutorial();
          },
          child: page,
        );
      }
      return page;
    }

    return ShowCaseWidget(
      onComplete: _onShowcaseComplete,
      enableAutoScroll: true,
      builder: buildInner,
    );
  }
}
