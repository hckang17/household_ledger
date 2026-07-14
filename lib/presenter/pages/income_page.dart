import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/controllers/tutorial_showcase_controller.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/nav_tab_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/income_page/income_editor_sheet.dart';
import 'package:household_ledger/presenter/widgets/common/ledger_dialogs.dart';
import 'package:household_ledger/services/mock_data_service.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';

/// 수입 관리 페이지다.
class IncomePage extends ConsumerStatefulWidget {
  /// 수입 관리 페이지를 생성한다.
  const IncomePage({super.key});

  @override
  ConsumerState<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends ConsumerState<IncomePage> {
  late DateTime _focusedMonth;

  final GlobalKey _budgetTileKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final TutorialShowcaseController _showcase = TutorialShowcaseController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  void _maybeStartShowcase() {
    final state = ref.read(tutorialProvider);
    _showcase.startIfReady(
      enabled: state.isActive && state.phase == TutorialPhase.income,
      keys: <GlobalKey>[_budgetTileKey, _fabKey],
      isMounted: () => mounted,
    );
  }

  void _onShowcaseComplete(int? index, GlobalKey key) {
    if (key == _fabKey) {
      // 수입 탭 튜토리얼 완료 → 고정지출 탭으로 이동
      ref.read(currentNavTabProvider.notifier).setTab(4);
      ref.read(tutorialProvider.notifier).setPhase(TutorialPhase.fixedExpense);
    }
  }

  String _text(Map<String, String> strings, String key, String fallback) {
    return strings[key] ?? fallback;
  }

  void _changeFocusedMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  String _monthLabel(DateTime month) {
    return DateFormat('yyyy년 M월').format(month);
  }

  Future<void> _delete(Map<String, String> strings, IncomeEntry item) async {
    final confirmed = await showLedgerConfirmDialog(
      context: context,
      title: _text(strings, 'confirmDelete', '삭제 확인'),
      message:
          '${item.description} : ${item.amount.toCurrency()} ${strings['currencyUnit'] ?? ''}',
      confirmLabel: _text(strings, 'delete', '삭제'),
      cancelLabel: _text(strings, 'cancel', '취소'),
    );
    if (!confirmed) return;
    if (item.id == null) return;

    await ref.read(ledgerProvider.notifier).deleteIncome(item.id!);
    if (!mounted) return;
    ref.invalidate(monthlyIncomesProvider(_focusedMonth));
  }

  Future<void> _handleBackDuringTutorial() async {
    _showcase.dismiss();
    final strings = ref.read(localizedStringsProvider);
    final confirmed = await showTutorialExitConfirmation(
      context: context,
      strings: strings,
    );
    if (confirmed && mounted) {
      await ref.read(mockDataServiceProvider).cleanupMockData(ref);
      await ref.read(tutorialProvider.notifier).exitTutorial();
    } else if (mounted) {
      _showcase.reset();
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
        (s) => s.isActive && s.phase == TutorialPhase.income,
      ),
    );

    ref.listen(currentNavTabProvider, (_, tab) {
      if (tab == 0 &&
          ref.read(tutorialProvider).phase == TutorialPhase.income) {
        _showcase.reset();
        _maybeStartShowcase();
      }
    });

    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final incomeAsync = ref.watch(monthlyIncomesProvider(_focusedMonth));
    if (incomeAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (incomeAsync.hasError) {
      return Scaffold(body: Center(child: Text(incomeAsync.error.toString())));
    }
    final incomes = incomeAsync.asData?.value ?? const <IncomeEntry>[];
    final monthlyIncome = incomes.fold<int>(
      0,
      (int total, IncomeEntry entry) => total + entry.amount,
    );
    final monthlyBudget = monthlyIncome > 0
        ? monthlyIncome
        : ledger.settings.monthlyBudget;

    Widget buildInner(BuildContext showcaseCtx) {
      _showcase.bind(showcaseCtx);
      _maybeStartShowcase();

      final fab = Showcase(
        key: _fabKey,
        title: strings['tutIncomeFabTitle'] ?? '수입 추가',
        description:
            strings['tutIncomeFabDesc'] ??
            '이번달 소득을 기록해보세요!\n버튼을 탭하면 수입 입력 시트가 열립니다.',
        tooltipPosition: TooltipPosition.top,
        child: FloatingActionButton.extended(
          onPressed: () => showIncomeEditorSheet(
            context: context,
            ref: ref,
            focusedMonth: _focusedMonth,
            strings: strings,
          ),
          label: Text(_text(strings, 'addIncome', '소득 추가')),
          icon: const Icon(Icons.add),
        ),
      );

      final page = BootstrapPage(
        title: strings['incomeManage'] ?? '',
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
        floatingActionButton: fab,
        child: Column(
          children: <Widget>[
            BootstrapSectionCard(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => _changeFocusedMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _monthLabel(_focusedMonth),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeFocusedMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Showcase(
                    key: _budgetTileKey,
                    title: strings['tutIncomeSummaryTitle'] ?? '수입 요약',
                    description:
                        strings['tutIncomeSummaryDesc'] ??
                        '이번달 소득 합계와 예산이 표시됩니다.\n소득을 입력하면 홈 화면의 지출가능금액도 자동으로 업데이트돼요.',
                    tooltipPosition: TooltipPosition.bottom,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: BootstrapSummaryTile(
                            label: _text(strings, 'incomeTotal', '월 소득 합계'),
                            value:
                                '${monthlyIncome.toCurrency()} ${strings['currencyUnit'] ?? ''}',
                            color: const Color(0xFF0D6EFD),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BootstrapSummaryTile(
                            label: _text(strings, 'budgetLabel', '월 예산'),
                            value:
                                '${monthlyBudget.toCurrency()} ${strings['currencyUnit'] ?? ''}',
                            color: const Color(0xFF198754),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: incomes.isEmpty
                  ? Center(child: Text(_text(strings, 'emptyData', '데이터 없음')))
                  : ListView.separated(
                      itemCount: incomes.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final item = incomes[index];
                        return BootstrapSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.description,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                ).format(item.earnedAt),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${item.amount.toCurrency()} ${strings['currencyUnit'] ?? ''}',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: <Widget>[
                                  TextButton(
                                    onPressed: () => showIncomeEditorSheet(
                                      context: context,
                                      ref: ref,
                                      focusedMonth: _focusedMonth,
                                      strings: strings,
                                      item: item,
                                    ),
                                    child: Text(_text(strings, 'edit', '수정')),
                                  ),
                                  TextButton(
                                    onPressed: () => _delete(strings, item),
                                    child: Text(_text(strings, 'delete', '삭제')),
                                  ),
                                ],
                              ),
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
