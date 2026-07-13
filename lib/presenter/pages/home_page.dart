import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/presenter/common/widgets/comparison_card.dart';
import 'package:household_ledger/presenter/common/widgets/expense_editor_sheet.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/presenter/common/widgets/recent_expenses_list.dart';
import 'package:household_ledger/provider/comparison_provider.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/nav_tab_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/services/mock_data_service.dart';
import 'package:showcaseview/showcaseview.dart';

/// 메인 대시보드 화면이다.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final GlobalKey _totalSpentKey = GlobalKey();
  final GlobalKey _remainingKey = GlobalKey();
  final GlobalKey _compCardKey = GlobalKey();
  final GlobalKey _quickExpenseKey = GlobalKey();
  final GlobalKey _recentListKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();

  bool _showcaseStarted = false;
  BuildContext? _showcaseContext;

  void _maybeStartShowcase() {
    if (_showcaseStarted) return;
    if (_showcaseContext == null) return;
    final state = ref.read(tutorialProvider);
    if (!state.isActive || state.phase != TutorialPhase.home) return;
    _showcaseStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase([
        _totalSpentKey,
        _remainingKey,
        _compCardKey,
        _quickExpenseKey,
        _recentListKey,
        _bottomNavKey,
      ]);
    });
  }

  Future<void> _deleteExpense(
    Map<String, String> strings,
    ExpenseEntry entry,
    String currency,
  ) async {
    final summary =
        '${entry.description} : ${entry.amount.toCurrency()}$currency\n'
        '${strings['deleteAlertCaution'] ?? ''}';
    final confirmed = await showLedgerConfirmDialog(
      context: context,
      title: strings['confirmDelete'] ?? '삭제 확인',
      message: '$summary ${strings['confirmDeleteQuestion'] ?? ''}',
      confirmLabel: strings['delete'] ?? '삭제',
      cancelLabel: strings['cancel'] ?? '취소',
    );
    if (!confirmed) return;
    await ref.read(ledgerProvider.notifier).deleteExpense(entry.id);
    ref.invalidate(monthlyExpensesProvider);
    ref.invalidate(rangeExpensesProvider);
  }

  Future<void> _handleBackDuringTutorial() async {
    if (_showcaseContext != null) {
      try {
        ShowCaseWidget.of(_showcaseContext!).dismiss();
      } catch (_) {}
    }
    final strings = ref.read(localizedStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(strings['tutorialExitTitle'] ?? '튜토리얼 종료'),
        content: Text(
          strings['tutorialExitMessage'] ?? '튜토리얼을 종료하시겠습니까?\n완료로 처리됩니다.',
        ),
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

  void _onShowcaseComplete(int? index, GlobalKey key) {
    if (key == _bottomNavKey) {
      // 홈 튜토리얼이 끝나면 수입 탭으로 이동하고 다음 단계를 시작한다.
      ref.read(currentNavTabProvider.notifier).setTab(0);
      ref.read(tutorialProvider.notifier).setPhase(TutorialPhase.income);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    final compResult = ref.watch(comparisonProvider);
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final monthlyExpense = ledger?.monthlyExpenseTotal(month) ?? 0;
    final monthlyIncomes = ref
        .watch(monthlyIncomesProvider(month))
        .asData
        ?.value;
    final monthlyIncomeTotal = (monthlyIncomes ?? const <IncomeEntry>[])
        .fold<int>(0, (int total, IncomeEntry e) => total + e.amount);
    final monthlyBudget = ledger == null
        ? 0
        : (monthlyIncomeTotal > 0
              ? monthlyIncomeTotal
              : ledger.settings.monthlyBudget);
    final monthlyFixedExpense = ledger?.fixedExpenseTotalForMonth(month) ?? 0;
    final remainingBudget = ledger == null
        ? 0
        : monthlyBudget - monthlyExpense - monthlyFixedExpense;
    final greeting = ledger == null
        ? ''
        : (strings['homepageGreeting'] ?? '{name}').replaceAll(
            '{name}',
            ledger.userProfile.name,
          );

    final recentExpensesAsync = ref.watch(monthlyExpensesProvider(month));
    final currency = strings['currencyUnit'] ?? '';
    final categoryTags =
        ledger?.tagsByType(MetadataTagType.category) ?? const <MetadataTag>[];
    final subcategoryTags =
        ledger?.tagsByType(MetadataTagType.subcategory) ??
        const <MetadataTag>[];
    final diningOccasionTags =
        ledger?.tagsByType(MetadataTagType.diningOccasion) ??
        const <MetadataTag>[];
    final paymentTags =
        ledger?.tagsByType(MetadataTagType.paymentMethod) ??
        const <MetadataTag>[];

    final isTutorial = ref.watch(
      tutorialProvider.select(
        (s) => s.isActive && s.phase == TutorialPhase.home,
      ),
    );

    // 튜토리얼 탭 전환 감지: 이 탭(2)이 선택되고 home 단계면 showcase를 시작한다.
    ref.listen(currentNavTabProvider, (_, tab) {
      if (tab == 2 && ref.read(tutorialProvider).phase == TutorialPhase.home) {
        _showcaseStarted = false;
        _maybeStartShowcase();
      }
    });

    Widget buildInner(BuildContext showcaseCtx) {
      _showcaseContext = showcaseCtx;
      _maybeStartShowcase();

      final scrollBody = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BootstrapSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Showcase(
                          key: _totalSpentKey,
                          title: strings['tutHomeTotalSpentTitle'] ?? '총 지출금액',
                          description:
                              strings['tutHomeTotalSpentDesc'] ??
                              '고정지출을 제외한, 이번달 소비금액의 총 합입니다.\n? 아이콘을 탭하면 더 자세한 설명이 보여요.',
                          tooltipPosition: TooltipPosition.bottom,
                          child: BootstrapSummaryTile(
                            label: strings['totalSpent'] ?? 'error_label',
                            value:
                                '${monthlyExpense.toCurrency()} ${strings['currencyUnit'] ?? ''}',
                            color: const Color(0xFFDC3545),
                            tooltipContent: TextSpan(
                              style: const TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                              children: <InlineSpan>[
                                TextSpan(
                                  text:
                                      strings['tooltipTotalSpentFixed'] ??
                                      '고정지출',
                                  style: const TextStyle(
                                    color: Color(0xFF198754),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      strings['tooltipTotalSpentSuffix'] ??
                                      '을 제외한, 이번달 소비금액의 총 합입니다.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Showcase(
                          key: _remainingKey,
                          title: strings['tutHomeRemainingTitle'] ?? '지출가능금액',
                          description:
                              strings['tutHomeRemainingDesc'] ??
                              '이번달 총 소득에서 고정금액과 총 지출금액을 제외한 남은 예산입니다.',
                          tooltipPosition: TooltipPosition.bottom,
                          child: BootstrapSummaryTile(
                            label: strings['remainingBudget'] ?? 'error_label',
                            value:
                                '${remainingBudget.toCurrency()} ${strings['currencyUnit'] ?? ''}',
                            color: const Color(0xFF198754),
                            tooltipContent: TextSpan(
                              style: const TextStyle(
                                color: Color(0xFF333333),
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                              children: <InlineSpan>[
                                TextSpan(
                                  text:
                                      strings['tooltipRemainingPrefix'] ??
                                      '이번달 총 소득에서 ',
                                ),
                                TextSpan(
                                  text:
                                      strings['tooltipRemainingFixed'] ??
                                      '고정금액',
                                  style: const TextStyle(
                                    color: Color(0xFF198754),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: strings['tooltipRemainingMid'] ?? '과 ',
                                ),
                                TextSpan(
                                  text:
                                      strings['tooltipRemainingTotal'] ??
                                      '총 지출금액',
                                  style: const TextStyle(
                                    color: Color(0xFFDC3545),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      strings['tooltipRemainingSuffix'] ??
                                      '을 제외한 금액입니다.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            if (compResult != null) ...<Widget>[
              Showcase(
                key: _compCardKey,
                title: strings['tutHomeCompCardTitle'] ?? '전월 비교 카드',
                description:
                    strings['tutHomeCompCardDesc'] ??
                    '지난달과 이번달 소비를 비교해드려요.\n어느 카테고리에서 지출이 늘었는지 한눈에 확인하세요.',
                tooltipPosition: TooltipPosition.bottom,
                child: ComparisonCard(
                  result: compResult,
                  strings: strings,
                  categoryTags: categoryTags,
                  currency: currency,
                ),
              ),
              const SizedBox(height: 10),
            ] else ...<Widget>[
              Showcase(
                key: _compCardKey,
                title: strings['tutHomeCompCardTitle'] ?? '전월 비교 카드',
                description:
                    strings['tutHomeCompCardNoDataDesc'] ??
                    '전월 데이터가 쌓이면 여기에 전월 대비 소비 비교 카드가 표시됩니다.',
                tooltipPosition: TooltipPosition.bottom,
                child: const SizedBox.shrink(),
              ),
            ],

            Showcase(
              key: _quickExpenseKey,
              title: strings['tutHomeQuickExpenseTitle'] ?? '빠른 지출 기록',
              description:
                  strings['tutHomeQuickExpenseDesc'] ??
                  '홈 화면에서 바로 소비내역을 입력할 수 있어요.\n버튼을 탭하면 입력 시트가 열립니다.',
              tooltipPosition: TooltipPosition.bottom,
              child: BootstrapActionButton(
                label: strings['quickExpense'] ?? '',
                icon: Icons.add_circle_outline_rounded,
                onPressed: () => showExpenseEditorSheet(
                  context: context,
                  ref: ref,
                  initialDate: DateTime.now(),
                  tutorialPreset: isTutorial
                      ? const TutorialExpensePreset(
                          categoryCode: 'F',
                          subcategoryCode: '_',
                          paymentMethodCode: '_s',
                          description: '가계부카페',
                          amount: '1280',
                          note: '기분전환',
                        )
                      : null,
                ),
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: const Color(0xFF102A43),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    strings['homeRecentExpensesTitle'] ?? '최근 소비 기록',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(AppRouter.expenseRecordRoute),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(strings['homeViewAll'] ?? '더보기'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            Showcase(
              key: _recentListKey,
              title: strings['tutHomeRecentListTitle'] ?? '최근 소비 기록',
              description:
                  strings['tutHomeRecentListDesc'] ??
                  '이번달에 기록된 소비 내역이 최신순으로 보입니다.\n항목을 탭하면 상세 정보를, 길게 탭하면 수정·삭제 옵션이 나와요.',
              tooltipPosition: TooltipPosition.bottom,
              child: recentExpensesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object e, _) => const SizedBox.shrink(),
                data: (List<ExpenseEntry> entries) => RecentExpensesList(
                  entries: entries,
                  categoryTags: categoryTags,
                  subcategoryTags: subcategoryTags,
                  paymentTags: paymentTags,
                  currency: currency,
                  strings: strings,
                  onTap: (ExpenseEntry entry) => showExpenseDetailDialog(
                    context: context,
                    entry: entry,
                    categoryTags: categoryTags,
                    subcategoryTags: subcategoryTags,
                    diningOccasionTags: diningOccasionTags,
                    paymentTags: paymentTags,
                    strings: strings,
                    currency: currency,
                  ),
                  onEdit: (ExpenseEntry entry) => showExpenseEditorSheet(
                    context: context,
                    ref: ref,
                    entry: entry,
                    initialDate: entry.spentAt,
                  ),
                  onDelete: (ExpenseEntry entry) =>
                      _deleteExpense(strings, entry, currency),
                ),
              ),
            ),
          ],
        ),
      );

      final page = BootstrapPage(
        title: strings['homeTitle'] ?? '',
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
        bottomNavigationBar: Showcase(
          key: _bottomNavKey,
          title: strings['tutHomeBottomNavTitle'] ?? '하단 내비게이션',
          description:
              strings['tutHomeBottomNavDesc'] ??
              '아이콘을 탭해 수입·분석·홈·소비기록·고정지출 탭으로 이동할 수 있어요.\n다음은 수입 탭을 살펴볼게요!',
          tooltipPosition: TooltipPosition.top,
          child: const SizedBox.shrink(),
        ),
        child: scrollBody,
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
