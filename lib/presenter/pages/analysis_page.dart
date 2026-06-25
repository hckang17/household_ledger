import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_expense_tab.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_income_tab.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_period_control_card.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/nav_tab_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/services/mock_data_service.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';

/// 기간 선택 모드를 정의한다.
enum _PeriodMode { monthly, range }

/// 지출 분석 화면이다.
///
/// 도넛 차트 캐러샐(소비구분/소비소구분/소비수단), 고정지출 막대, 일별 추이를 제공한다.
class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  late DateTime _selectedMonth;
  DateTimeRange? _selectedRange;
  _PeriodMode _periodMode = _PeriodMode.monthly;
  bool _showExpense = true;

  final GlobalKey _periodControlKey = GlobalKey();
  final GlobalKey _pdfBtnKey = GlobalKey();
  bool _showcaseStarted = false;
  BuildContext? _showcaseContext;

  void _maybeStartShowcase() {
    if (_showcaseStarted) return;
    if (_showcaseContext == null) return;
    final state = ref.read(tutorialProvider);
    if (!state.isActive || state.phase != TutorialPhase.analysis) return;
    _showcaseStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase([
        _periodControlKey,
        _pdfBtnKey,
      ]);
    });
  }

  void _onShowcaseComplete(int? index, GlobalKey key) {
    if (key == _pdfBtnKey) {
      // 분석 튜토리얼 완료 → PDF 리포트 페이지로 이동
      ref.read(tutorialProvider.notifier).setPhase(TutorialPhase.pdfReport);
      Navigator.of(context).pushNamed(AppRouter.generatingReportRoute);
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
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  // ─── 로케일 헬퍼 ────────────────────────────────────────────────

  String _text(
    Map<String, String> strings,
    String key, [
    String fallback = '',
  ]) => strings[key] ?? fallback;

  String _intlLocale(String localeCode) => localeCode == 'jp' ? 'ja' : 'ko';

  String _formatMonth(String localeCode, DateTime month) =>
      DateFormat.yMMMM(_intlLocale(localeCode)).format(month);

  String _formatRange(String localeCode, DateTimeRange range) {
    final DateFormat fmt = DateFormat('MM.dd', _intlLocale(localeCode));
    return '${fmt.format(range.start)} - ${fmt.format(range.end)}';
  }

  // ─── 전월동기 쿼리 ───────────────────────────────────────────────

  DateTime _shiftOneMonthBack(DateTime d) {
    final int year = d.month == 1 ? d.year - 1 : d.year;
    final int month = d.month == 1 ? 12 : d.month - 1;
    final int lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, d.day < lastDay ? d.day : lastDay);
  }

  ExpenseRangeQuery _computeAnalysisPrevQuery() {
    final DateTime now = DateTime.now();
    final bool usingRange =
        _periodMode == _PeriodMode.range && _selectedRange != null;
    if (!usingRange) {
      final bool isCurrentMonth =
          _selectedMonth.year == now.year && _selectedMonth.month == now.month;
      final DateTime refDate = isCurrentMonth
          ? now
          : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      return computePrevSamePeriodQuery(refDate);
    }
    return ExpenseRangeQuery(
      start: _shiftOneMonthBack(_selectedRange!.start),
      endInclusive: _shiftOneMonthBack(_selectedRange!.end),
    );
  }

  // ─── 비교 안내 배너 ──────────────────────────────────────────────

  Widget _buildComparisonBanner({
    required Map<String, String> strings,
    required AsyncValue<List<ExpenseEntry>> expensesAsync,
    required List<ExpenseEntry> prevCategoryExpenses,
    required ExpenseRangeQuery analysisPrevQuery,
  }) {
    final List<ExpenseEntry>? currentExpenses = expensesAsync.asData?.value;
    // 로딩 중이거나 에러면 배너 표시 안 함
    if (currentExpenses == null) return const SizedBox.shrink();

    final String monthSuffix = strings['chartDateMonthSuffix'] ?? '월';
    final String daySuffix = strings['chartDateDaySuffix'] ?? '일';

    final String message;
    final Color bgColor;
    final Color borderColor;
    final IconData icon;
    final Color iconColor;

    if (currentExpenses.isEmpty) {
      message = strings['analysisNoCurrMonthData'] ?? '이번 달 소비 데이터가 없습니다.';
      bgColor = const Color(0xFFFFF8E1);
      borderColor = const Color(0xFFFFE082);
      icon = Icons.info_outline;
      iconColor = const Color(0xFFF9A825);
    } else if (prevCategoryExpenses.isEmpty) {
      message = strings['analysisNoPrevPeriodData'] ?? '전월동기 비교 데이터가 없습니다.';
      bgColor = const Color(0xFFF5F5F5);
      borderColor = const Color(0xFFE0E0E0);
      icon = Icons.compare_arrows;
      iconColor = Colors.grey.shade500;
    } else {
      final DateTime s = analysisPrevQuery.start;
      final DateTime e = analysisPrevQuery.endInclusive;
      final String startStr = '${s.month}$monthSuffix ${s.day}$daySuffix';
      final String endStr = '${e.month}$monthSuffix ${e.day}$daySuffix';
      message = (strings['analysisCompPeriodHint'] ??
              '{start} ~ {end} 기간과 비교한 결과도 표시됩니다.')
          .replaceAll('{start}', startStr)
          .replaceAll('{end}', endStr);
      bgColor = const Color(0xFFE8F4FD);
      borderColor = const Color(0xFFBBDEFB);
      icon = Icons.compare_arrows;
      iconColor = const Color(0xFF1565C0);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 빌드 ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Map<String, String> strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String localeCode = ledger.settings.localeCode;
    final String currency = strings['currencyUnit'] ?? '₩';
    final List<MetadataTag> categoryTags = ledger.tagsByType(
      MetadataTagType.category,
    );
    final List<MetadataTag> subcategoryTags = ledger.tagsByType(
      MetadataTagType.subcategory,
    );
    final List<MetadataTag> paymentTags = ledger.tagsByType(
      MetadataTagType.paymentMethod,
    );

    final bool usingRange =
        _periodMode == _PeriodMode.range && _selectedRange != null;

    final ExpenseRangeQuery? rangeQuery = usingRange
        ? ExpenseRangeQuery(
            start: _selectedRange!.start,
            endInclusive: _selectedRange!.end,
          )
        : null;

    final AsyncValue<List<ExpenseEntry>> expensesAsync = usingRange
        ? ref.watch(rangeExpensesProvider(rangeQuery!))
        : ref.watch(monthlyExpensesProvider(_selectedMonth));

    final ExpenseRangeQuery analysisPrevQuery = _computeAnalysisPrevQuery();
    final List<ExpenseEntry> prevCategoryExpenses =
        ref.watch(rangeExpensesProvider(analysisPrevQuery)).value ??
        const <ExpenseEntry>[];

    final AsyncValue<List<IncomeEntry>> incomesAsync = ref.watch(
      monthlyIncomesProvider(_selectedMonth),
    );

    final List<FixedExpense> monthlyFixed = ledger.fixedExpenses
        .where(
          (FixedExpense f) =>
              f.appliedAt.year == _selectedMonth.year &&
              f.appliedAt.month == _selectedMonth.month,
        )
        .toList();

    final String periodSubtitle = usingRange
        ? _formatRange(localeCode, _selectedRange!)
        : _formatMonth(localeCode, _selectedMonth);

    final DateTime chartRangeStart = usingRange
        ? _selectedRange!.start
        : _selectedMonth;

    // 기간이 바뀌면 탭 섹션 위젯의 상태(차트 모드, 터치 인덱스)를 초기화한다.
    final String periodKey = usingRange
        ? '${_selectedRange!.start}-${_selectedRange!.end}'
        : _selectedMonth.toString();

    final isTutorial = ref.watch(
      tutorialProvider.select(
        (s) => s.isActive && s.phase == TutorialPhase.analysis,
      ),
    );

    ref.listen(currentNavTabProvider, (_, tab) {
      if (tab == 1 &&
          ref.read(tutorialProvider).phase == TutorialPhase.analysis) {
        _showcaseStarted = false;
        _maybeStartShowcase();
      }
    });

    Widget buildInner(BuildContext showcaseCtx) {
      _showcaseContext = showcaseCtx;
      _maybeStartShowcase();

      final page = BootstrapPage(
        title: _text(strings, 'analysis', '지출 분석'),
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
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              // ── 상단 컨트롤 카드 ──
              Showcase(
                key: _periodControlKey,
                title: strings['tutAnalysisPeriodTitle'] ?? '분석 기간 선택',
                description: strings['tutAnalysisPeriodDesc'] ?? '월별 또는 기간별로 지출 데이터를 분석할 수 있어요.\n이전/다음 화살표로 월을 이동하거나 달력 기간을 직접 설정해보세요.',
                tooltipPosition: TooltipPosition.bottom,
                child: AnalysisPeriodControlCard(
              showExpense: _showExpense,
              isRangeMode: _periodMode == _PeriodMode.range,
              selectedMonth: _selectedMonth,
              selectedRange: _selectedRange,
              periodSubtitle: periodSubtitle,
              localeCode: localeCode,
              strings: strings,
              onTabChanged: (bool v) => setState(() => _showExpense = v),
              onMonthPrev: () => setState(
                () => _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                ),
              ),
              onMonthNext: () => setState(
                () => _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                ),
              ),
              onMonthChanged: (DateTime d) =>
                  setState(() => _selectedMonth = d),
              onRangeChanged: (DateTimeRange? r) =>
                  setState(() => _selectedRange = r),
              onModeChanged: (bool isRange) => setState(() {
                _periodMode = isRange ? _PeriodMode.range : _PeriodMode.monthly;
                _selectedRange = null;
              }),
            ),
            ),
              const SizedBox(height: 16),

            // ── 전월동기 비교 안내 배너 (지출 탭에서만 표시) ──
            if (_showExpense)
              _buildComparisonBanner(
                strings: strings,
                expensesAsync: expensesAsync,
                prevCategoryExpenses: prevCategoryExpenses,
                analysisPrevQuery: analysisPrevQuery,
              ),

            // ── 지출 탭 ──
            if (_showExpense)
              expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => Center(child: Text(e.toString())),
                data: (List<ExpenseEntry> expenses) =>
                    AnalysisExpenseTabSection(
                      key: ValueKey('expense-$periodKey'),
                      expenses: expenses,
                      prevCategoryExpenses: prevCategoryExpenses,
                      monthlyFixed: monthlyFixed,
                      categoryTags: categoryTags,
                      subcategoryTags: subcategoryTags,
                      paymentTags: paymentTags,
                      strings: strings,
                      currency: currency,
                      usingRange: usingRange,
                      chartRangeStart: chartRangeStart,
                      prevRangeStart: analysisPrevQuery.start,
                    ),
              ),

            // ── PDF 출력 버튼 (지출 탭에서만 표시) ──
            if (_showExpense)
              Showcase(
                key: _pdfBtnKey,
                title: strings['tutAnalysisPdfBtnTitle'] ?? 'PDF 리포트 출력',
                description: strings['tutAnalysisPdfBtnDesc'] ?? '지출 분석 결과를 PDF로 출력하고 공유할 수 있어요!\n다음 단계에서 PDF 설정 화면을 살펴볼게요.',
                tooltipPosition: TooltipPosition.top,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(AppRouter.generatingReportRoute),
                      icon: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFFDC3545),
                      ),
                      label: Text(
                        _text(strings, 'analysisExportPdf', 'PDF로 출력하기'),
                        style: const TextStyle(color: Color(0xFFDC3545)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFDC3545)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ),

            // ── 수입 탭 ──
            if (!_showExpense)
              incomesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => Center(child: Text(e.toString())),
                data: (List<IncomeEntry> incomes) => AnalysisIncomeTabSection(
                  key: ValueKey('income-$periodKey'),
                  incomes: incomes,
                  strings: strings,
                  currency: currency,
                  chartRangeStart: chartRangeStart,
                ),
              ),
          ],
        ),
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
