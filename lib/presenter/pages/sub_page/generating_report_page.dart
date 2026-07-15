// """ MVVM 계층: View / Sub Feature Page """
// """ 역할: PDF 리포트 범위·옵션 설정과 생성 파일 관리를 제공 """

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/services/imexporting_file/pdf_report_generation_service.dart';
import 'package:household_ledger/model/reporting/report_generation_request.dart';
import 'package:household_ledger/model/reporting/report_options.dart';
import 'package:household_ledger/presenter/controllers/tutorial_showcase_controller.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/widgets/generating_report_page/report_file_list.dart';
import 'package:household_ledger/presenter/widgets/generating_report_page/report_option_selector.dart';
import 'package:household_ledger/presenter/widgets/generating_report_page/report_period_selector.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/services/mock_data_service.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:showcaseview/showcaseview.dart';

/// 기간 선택 모드를 정의한다.
enum _PeriodMode { monthly, range }

/// PDF 리포트를 설정하고 생성하는 페이지다.
class GeneratingReportPage extends ConsumerStatefulWidget {
  const GeneratingReportPage({super.key});

  @override
  ConsumerState<GeneratingReportPage> createState() =>
      _GeneratingReportPageState();
}

class _GeneratingReportPageState extends ConsumerState<GeneratingReportPage> {
  final TextEditingController _titleCtrl = TextEditingController(
    text: 'Household Ledger',
  );
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final GlobalKey _periodSelectorKey = GlobalKey();
  final GlobalKey _titleFieldKey = GlobalKey();
  final GlobalKey _emailFieldKey = GlobalKey();
  final GlobalKey _optionSelectorKey = GlobalKey();
  final GlobalKey _generateBtnKey = GlobalKey();
  final TutorialShowcaseController _showcase = TutorialShowcaseController();

  _PeriodMode _periodMode = _PeriodMode.monthly;
  DateTime _selectedMonth = DateTime.now();
  DateTimeRange? _selectedRange;

  bool _includeTop10 = true;
  bool _includeFixedExpenses = true;
  bool _includePaymentSummary = true;
  bool _includeDetailedData = true;
  bool _includePrevComparison = false;
  bool _includePrevCategoryAnalysis = false;

  bool _isGenerating = false;
  double _generationProgress = 0;
  DateTime? _lastGenerateTime;

  List<File> _existingReports = <File>[];
  bool _loadingReports = true;

  final PdfReportGenerationService _reportService =
      PdfReportGenerationService();

  // ─── 라이프사이클 ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadExistingReports();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── 튜토리얼 ──────────────────────────────────────────────────

  void _maybeStartShowcase() {
    final state = ref.read(tutorialProvider);
    _showcase.startIfReady(
      enabled: state.isActive && state.phase == TutorialPhase.pdfReport,
      keys: <GlobalKey>[
        _periodSelectorKey,
        _titleFieldKey,
        _emailFieldKey,
        _optionSelectorKey,
        _generateBtnKey,
      ],
      isMounted: () => mounted,
    );
  }

  void _onShowcaseComplete(int? index, GlobalKey key) {
    if (key == _generateBtnKey) {
      ref.read(tutorialProvider.notifier).setPhase(TutorialPhase.dataManage);
      Navigator.of(context).pushNamed(AppRouter.dataManageRoute);
    }
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

  // ─── 상태 메서드 ────────────────────────────────────────────────

  Future<void> _loadExistingReports() async {
    final List<File> reports = await _reportService.getExistingReports();
    if (mounted) {
      setState(() {
        _existingReports = reports;
        _loadingReports = false;
      });
    }
  }

  bool get _canGenerate {
    if (_isGenerating) return false;
    if (_lastGenerateTime != null &&
        DateTime.now().difference(_lastGenerateTime!).inSeconds < 5) {
      return false;
    }
    return true;
  }

  String _t(Map<String, String> strings, String key, String fallback) =>
      strings[key] ?? fallback;

  void _updateGenerationProgress(double value) {
    if (!mounted) return;
    final double next = value.clamp(0.0, 1.0);
    if (next <= _generationProgress) return;
    setState(() => _generationProgress = next);
  }

  DateTime _shiftOneMonthBack(DateTime d) {
    final int year = d.month == 1 ? d.year - 1 : d.year;
    final int month = d.month == 1 ? 12 : d.month - 1;
    final int lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, d.day < lastDay ? d.day : lastDay);
  }

  ExpenseRangeQuery _computePrevPeriodQuery() {
    final bool usingRange =
        _periodMode == _PeriodMode.range && _selectedRange != null;
    if (!usingRange) {
      final DateTime now = DateTime.now();
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

  String _periodLabel() {
    if (_periodMode == _PeriodMode.monthly) {
      return DateFormat('yyyy-MM').format(_selectedMonth);
    }
    if (_selectedRange != null) {
      final String s = DateFormat('yyyy-MM-dd').format(_selectedRange!.start);
      final String e = DateFormat('yyyy-MM-dd').format(_selectedRange!.end);
      return '$s~$e';
    }
    return DateFormat('yyyy-MM').format(_selectedMonth);
  }

  // ─── 이벤트 핸들러 ──────────────────────────────────────────────

  Future<void> _onGeneratePressed(
    Map<String, String> strings,
    String localeCode,
  ) async {
    if (!_canGenerate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(strings, 'reportCooldownMessage', '잠시 후에 다시 시도해주세요.'),
          ),
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_periodMode == _PeriodMode.range && _selectedRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(strings, 'exportRangeDateRequired', '추출 기간을 선택해주세요.'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generationProgress = 0;
    });
    _lastGenerateTime = DateTime.now();

    try {
      _updateGenerationProgress(0.03);
      final ledger = ref.read(ledgerProvider).asData?.value;
      if (ledger == null) throw Exception('ledger unavailable');

      final bool usingRange =
          _periodMode == _PeriodMode.range && _selectedRange != null;
      final ExpenseRangeQuery? rangeQuery = usingRange
          ? ExpenseRangeQuery(
              start: _selectedRange!.start,
              endInclusive: _selectedRange!.end,
            )
          : null;

      final List<ExpenseEntry> expenses = usingRange
          ? await ref.read(rangeExpensesProvider(rangeQuery!).future)
          : await ref.read(monthlyExpensesProvider(_selectedMonth).future);
      _updateGenerationProgress(0.10);

      final List<IncomeEntry> incomes;
      if (usingRange && _selectedRange != null) {
        final List<IncomeEntry> merged = <IncomeEntry>[];
        DateTime cursor = DateTime(
          _selectedRange!.start.year,
          _selectedRange!.start.month,
        );
        final DateTime endMonth = DateTime(
          _selectedRange!.end.year,
          _selectedRange!.end.month,
        );
        while (!cursor.isAfter(endMonth)) {
          final List<IncomeEntry> monthData = await ref.read(
            monthlyIncomesProvider(cursor).future,
          );
          merged.addAll(
            monthData.where(
              (IncomeEntry i) =>
                  !i.earnedAt.isBefore(_selectedRange!.start) &&
                  !i.earnedAt.isAfter(_selectedRange!.end),
            ),
          );
          cursor = DateTime(cursor.year, cursor.month + 1);
        }
        incomes = merged;
      } else {
        incomes = await ref.read(monthlyIncomesProvider(_selectedMonth).future);
      }
      _updateGenerationProgress(0.18);

      final List<FixedExpense> fixedExpenses = !usingRange
          ? ledger.fixedExpenses
                .where(
                  (FixedExpense f) =>
                      f.appliedAt.year == _selectedMonth.year &&
                      f.appliedAt.month == _selectedMonth.month,
                )
                .toList()
          : <FixedExpense>[];

      final ExpenseRangeQuery prevQuery = _computePrevPeriodQuery();
      final List<ExpenseEntry> prevExpenses = await ref.read(
        rangeExpensesProvider(prevQuery).future,
      );
      _updateGenerationProgress(0.25);

      final DateTime periodStart = usingRange
          ? _selectedRange!.start
          : _selectedMonth;

      final String reportTitle = _titleCtrl.text.trim().isEmpty
          ? 'Household Ledger'
          : _titleCtrl.text.trim();

      final String path = await _reportService.generate(
        ReportGenerationRequest(
          expenses: expenses,
          fixedExpenses: fixedExpenses,
          incomes: incomes,
          ledger: ledger,
          email: _emailCtrl.text.trim(),
          reportTitle: reportTitle,
          options: ReportOptions(
            includeDetailedData: _includeDetailedData,
            includeTop10: _includeTop10,
            includeFixedExpenses: _includeFixedExpenses,
            includePaymentSummary: _includePaymentSummary,
            includePrevComparison: _includePrevComparison,
            includePrevCategoryAnalysis: _includePrevCategoryAnalysis,
          ),
          periodLabel: _periodLabel(),
          periodStart: periodStart,
          previousExpenses: prevExpenses,
          previousPeriodStart: prevQuery.start,
          strings: strings,
        ),
        onProgress: (double progress) {
          _updateGenerationProgress(0.25 + (progress * 0.75));
        },
      );

      if (!mounted) return;
      setState(() => _isGenerating = false);
      await _loadExistingReports();
      if (mounted) _showSuccessDialog(strings, path);
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t(strings, 'reportFailed', 'PDF 생성에 실패했습니다.')),
          ),
        );
      }
    }
  }

  void _showSuccessDialog(Map<String, String> strings, String path) {
    final String fileName = path.split(Platform.pathSeparator).last;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF198754),
          size: 40,
        ),
        title: Text(_t(strings, 'reportSuccessTitle', 'PDF 생성 완료!')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              fileName,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _t(strings, 'reportSavedPath', '저장된 경로'),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Share.shareXFiles([XFile(path, mimeType: 'application/pdf')]);
            },
            child: Text(_t(strings, 'reportShareFile', '공유')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              OpenFile.open(path);
            },
            child: Text(_t(strings, 'reportOpenFile', '열기')),
          ),
        ],
      ),
    );
  }

  // ─── 빌드 ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Map<String, String> strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    final isTutorial = ref.watch(
      tutorialProvider.select(
        (s) => s.isActive && s.phase == TutorialPhase.pdfReport,
      ),
    );

    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String localeCode = ledger.settings.localeCode;

    Widget buildInner(BuildContext showcaseCtx) {
      _showcase.bind(showcaseCtx);
      _maybeStartShowcase();

      final page = BootstrapPage(
        title: _t(strings, 'reportPageTitle', 'PDF 리포트 생성'),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── 기간 설정 ──
                Showcase(
                  key: _periodSelectorKey,
                  title: strings['tutReportPeriodTitle'] ?? '리포트 기간 설정',
                  description:
                      strings['tutReportPeriodDesc'] ??
                      '분석 기간을 선택해요.\n월별 또는 직접 날짜 범위를 지정할 수 있습니다.',
                  tooltipPosition: TooltipPosition.bottom,
                  child: ReportPeriodSelector(
                    isRangeMode: _periodMode == _PeriodMode.range,
                    selectedMonth: _selectedMonth,
                    selectedRange: _selectedRange,
                    strings: strings,
                    onModeChanged: (bool isRange) => setState(() {
                      _periodMode = isRange
                          ? _PeriodMode.range
                          : _PeriodMode.monthly;
                      _selectedRange = null;
                    }),
                    onMonthChanged: (DateTime d) =>
                        setState(() => _selectedMonth = d),
                    onRangeChanged: (DateTimeRange r) =>
                        setState(() => _selectedRange = r),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 타이틀 지정 ──
                Showcase(
                  key: _titleFieldKey,
                  title: strings['tutReportTitleFieldTitle'] ?? 'PDF 타이틀',
                  description:
                      strings['tutReportTitleFieldDesc'] ??
                      'PDF 파일에 표시될 제목을 입력해요.\n기본값은 Household Ledger입니다.',
                  tooltipPosition: TooltipPosition.bottom,
                  child: BootstrapSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _t(strings, 'reportTitleLabel', 'PDF 타이틀 지정'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _titleCtrl,
                          decoration: InputDecoration(
                            hintText: _t(
                              strings,
                              'reportTitleHint',
                              '기본값: Household Ledger',
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: const Icon(Icons.title_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 이메일 입력 ──
                Showcase(
                  key: _emailFieldKey,
                  title: strings['tutReportEmailFieldTitle'] ?? '이메일 입력',
                  description:
                      strings['tutReportEmailFieldDesc'] ??
                      'PDF에 표시될 이메일 주소를 입력해요.\n리포트 헤더에 담당자 이메일로 표시됩니다.',
                  tooltipPosition: TooltipPosition.bottom,
                  child: BootstrapSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _t(strings, 'reportEmailLabel', '이메일 (필수)'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'example@email.com',
                            border: OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (String? v) {
                            if (v == null || v.trim().isEmpty) {
                              return _t(
                                strings,
                                'emailFormatError',
                                '이메일 형식을 확인해주세요.',
                              );
                            }
                            if (!RegExp(
                              r'^[^@]+@[^@]+\.[^@]+$',
                            ).hasMatch(v.trim())) {
                              return _t(
                                strings,
                                'emailFormatError',
                                '이메일 형식을 확인해주세요.',
                              );
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── PDF 암호 (예약) ──
                BootstrapSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _t(strings, 'reportPasswordLabel', 'PDF 암호 (선택)'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: _t(
                            strings,
                            'reportPasswordHint',
                            '암호를 설정하면 PDF 열 때 입력이 필요합니다',
                          ),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          strings,
                          'pdfUnsupportWarning',
                          '* 현재 버전에서는 PDF 암호화가 지원되지 않습니다.',
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── 포함할 데이터 ──
                Showcase(
                  key: _optionSelectorKey,
                  title: strings['tutReportOptionTitle'] ?? '리포트 포함 항목',
                  description:
                      strings['tutReportOptionDesc'] ??
                      'PDF에 포함할 데이터 항목을 선택해요.\n필요한 항목만 체크하면 더 간결한 리포트가 생성됩니다.',
                  tooltipPosition: TooltipPosition.bottom,
                  child: ReportOptionSelector(
                    includeTop10: _includeTop10,
                    includeFixedExpenses: _includeFixedExpenses,
                    includePaymentSummary: _includePaymentSummary,
                    includeDetailedData: _includeDetailedData,
                    includePrevComparison: _includePrevComparison,
                    includePrevCategoryAnalysis: _includePrevCategoryAnalysis,
                    strings: strings,
                    onTop10Changed: (bool v) =>
                        setState(() => _includeTop10 = v),
                    onFixedChanged: (bool v) =>
                        setState(() => _includeFixedExpenses = v),
                    onPaymentChanged: (bool v) =>
                        setState(() => _includePaymentSummary = v),
                    onDetailedChanged: (bool v) =>
                        setState(() => _includeDetailedData = v),
                    onPrevComparisonChanged: (bool v) =>
                        setState(() => _includePrevComparison = v),
                    onPrevCategoryAnalysisChanged: (bool v) =>
                        setState(() => _includePrevCategoryAnalysis = v),
                  ),
                ),
                const SizedBox(height: 20),

                // ── PDF 생성하기 버튼 ──
                Showcase(
                  key: _generateBtnKey,
                  title: strings['tutReportGenerateBtnTitle'] ?? 'PDF 생성',
                  description:
                      strings['tutReportGenerateBtnDesc'] ??
                      '설정이 완료되면 이 버튼으로 PDF를 생성해요!\n다음은 데이터 관리 화면을 살펴볼게요.',
                  tooltipPosition: TooltipPosition.top,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _canGenerate
                          ? () => _onGeneratePressed(strings, localeCode)
                          : null,
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded),
                      label: Text(
                        _isGenerating
                            ? _t(strings, 'reportGenerating', 'PDF 생성 중...')
                            : _t(strings, 'reportGenerateButton', 'PDF 생성하기'),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                if (_isGenerating) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F1FF),
                      border: Border.all(color: const Color(0xFFB6D4FE)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 20,
                              color: Color(0xFF084298),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _t(
                                  strings,
                                  'reportGeneratingNotice',
                                  'PDF가 작성될 때까지 앱을 종료하지 말아주세요. '
                                      '열심히 보고서를 작성 중입니다.',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF084298),
                                  fontSize: 13,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _generationProgress,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFD0E2FF),
                            color: const Color(0xFF0D6EFD),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(_generationProgress * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFF084298),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // ── 이전에 생성된 리포트 목록 ──
                ReportFileList(
                  files: _existingReports,
                  isLoading: _loadingReports,
                  strings: strings,
                ),
                const SizedBox(height: 24),
              ],
            ),
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
