import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/services/imexporting_file/export_pdf_report_service.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

/// 기간 선택 모드를 정의한다.
///
/// [monthly]는 특정 달을 단위로 선택하고,
/// [range]는 시작일~종료일을 직접 지정하는 모드다.
enum _PeriodMode {
  /// 월 단위 선택 모드.
  monthly,

  /// 날짜 범위 직접 지정 모드.
  range,
}

/// PDF 리포트를 설정하고 생성하는 페이지다.
///
/// 사용자는 이 페이지에서 기간·이메일·포함 데이터를 설정한 뒤
/// [ExportPdfReportService]를 통해 PDF 파일을 생성할 수 있다.
/// 생성된 파일은 하단 목록에 자동으로 추가된다.
class GeneratingReportPage extends ConsumerStatefulWidget {
  /// [GeneratingReportPage]를 생성한다.
  const GeneratingReportPage({super.key});

  @override
  ConsumerState<GeneratingReportPage> createState() =>
      _GeneratingReportPageState();
}

class _GeneratingReportPageState extends ConsumerState<GeneratingReportPage> {
  /// 이메일 입력 컨트롤러.
  final TextEditingController _emailCtrl = TextEditingController();

  /// PDF 암호 입력 컨트롤러 (현재 버전에서 암호화 미지원, UI 예약용).
  final TextEditingController _passwordCtrl = TextEditingController();

  /// 폼 유효성 검사에 사용하는 GlobalKey.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// 현재 선택된 기간 모드.
  _PeriodMode _periodMode = _PeriodMode.monthly;

  /// 월간 모드에서 선택된 달.
  DateTime _selectedMonth = DateTime.now();

  /// 범위 모드에서 선택된 날짜 범위.
  DateTimeRange? _selectedRange;

  /// Top 10 지출 내역 포함 여부.
  bool _includeTop10 = true;

  /// 고정지출 내역 포함 여부.
  bool _includeFixedExpenses = true;

  /// 소비수단 별 요약 포함 여부.
  bool _includePaymentSummary = true;

  /// 전체 거래내역(부록) 포함 여부.
  bool _includeDetailedData = true;

  /// PDF 생성 중 여부를 나타내는 플래그.
  bool _isGenerating = false;

  /// 마지막 생성 시각 (5초 쿨다운 계산에 사용).
  DateTime? _lastGenerateTime;

  /// 이미 생성된 PDF 리포트 파일 목록.
  List<File> _existingReports = <File>[];

  /// 기존 리포트 목록 로딩 중 여부.
  bool _loadingReports = true;

  /// PDF 리포트 생성 서비스.
  final ExportPdfReportService _service = ExportPdfReportService();

  // ─── 라이프사이클 ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // 현재 달의 1일로 초기화한다.
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadExistingReports();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── 상태 메서드 ────────────────────────────────────────────────

  /// 기존에 생성된 PDF 리포트 목록을 서비스에서 불러와 상태를 갱신한다.
  Future<void> _loadExistingReports() async {
    final List<File> reports = await _service.getExistingReports();
    if (mounted) {
      setState(() {
        _existingReports = reports;
        _loadingReports = false;
      });
    }
  }

  /// 현재 PDF 생성 버튼을 활성화할 수 있는지 판단한다.
  ///
  /// 생성 중이거나 마지막 생성으로부터 5초가 지나지 않은 경우 [false]를 반환한다.
  bool get _canGenerate {
    if (_isGenerating) {
      return false;
    }
    if (_lastGenerateTime != null &&
        DateTime.now().difference(_lastGenerateTime!).inSeconds < 5) {
      return false;
    }
    return true;
  }

  /// [strings] 맵에서 [key]에 해당하는 로컬라이즈 문자열을 반환한다.
  ///
  /// 키가 없으면 [fallback] 문자열을 반환한다.
  String _t(Map<String, String> strings, String key, String fallback) =>
      strings[key] ?? fallback;

  /// 현재 기간 설정을 파일명과 PDF 표지에 쓸 문자열로 변환한다.
  ///
  /// 월간 모드: `yyyy-MM` 형식, 범위 모드: `yyyy-MM-dd~yyyy-MM-dd` 형식.
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

  /// 'PDF 생성하기' 버튼이 눌렸을 때 실행되는 핸들러다.
  ///
  /// 쿨다운·폼 유효성·기간 선택을 검증한 뒤 [ExportPdfReportService.generateReport]를
  /// 호출하고, 성공 시 성공 다이얼로그를 표시하고 기존 파일 목록을 새로고침한다.
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

    setState(() => _isGenerating = true);
    _lastGenerateTime = DateTime.now();

    try {
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

      // .future 를 사용해 Riverpod 캐시 여부와 무관하게 DB에서 직접 조회한다.
      // (.asData?.value 는 캐시에 없으면 null을 반환해 데이터가 누락된다.)
      final List<ExpenseEntry> expenses = usingRange
          ? await ref.read(rangeExpensesProvider(rangeQuery!).future)
          : await ref.read(monthlyExpensesProvider(_selectedMonth).future);

      // 수입은 항상 DB에서 직접 조회한다.
      // 범위 모드일 때는 범위 내 모든 달의 수입을 합산한다.
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
          // 선택 범위 내 날짜의 항목만 포함한다.
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

      // 고정지출은 월간 모드에서만 포함한다 (분석 페이지와 동일한 정책).
      final List<FixedExpense> fixedExpenses = !usingRange
          ? ledger.fixedExpenses
                .where(
                  (FixedExpense f) =>
                      f.appliedAt.year == _selectedMonth.year &&
                      f.appliedAt.month == _selectedMonth.month,
                )
                .toList()
          : <FixedExpense>[];

      final String path = await _service.generateReport(
        expenses: expenses,
        fixedExpenses: fixedExpenses,
        incomes: incomes,
        ledger: ledger,
        email: _emailCtrl.text.trim(),
        options: ReportOptions(
          includeDetailedData: _includeDetailedData,
          includeTop10: _includeTop10,
          includeFixedExpenses: _includeFixedExpenses,
          includePaymentSummary: _includePaymentSummary,
        ),
        periodLabel: _periodLabel(),
        strings: strings,
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

  // ─── 다이얼로그 ─────────────────────────────────────────────────

  /// PDF 생성 성공 시 파일명과 열기·공유 버튼을 담은 다이얼로그를 표시한다.
  ///
  /// [path]는 생성된 PDF 파일의 절대 경로다.
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
            // 저장된 파일명 표시
            Text(
              fileName,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // '저장된 경로' 보조 라벨
            Text(
              _t(strings, 'reportSavedPath', '저장된 경로'),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: <Widget>[
          // 공유 버튼: OS 공유 시트를 열어 PDF를 전송한다.
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Share.shareXFiles([XFile(path, mimeType: 'application/pdf')]);
            },
            child: Text(_t(strings, 'reportShareFile', '공유')),
          ),
          // 열기 버튼: 기기 기본 PDF 뷰어로 파일을 연다.
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

  // ─── 기간 선택 다이얼로그 ────────────────────────────────────────

  /// 월 선택 다이얼로그를 표시한다.
  ///
  /// 좌우 화살표로 이전·다음 달을 탐색하며, '적용'을 누르면 [_selectedMonth]가 갱신된다.
  /// 현재 달 이후로는 이동하지 못하도록 우측 버튼을 비활성화한다.
  Future<void> _pickMonth(
    BuildContext context,
    Map<String, String> strings,
  ) async {
    final DateTime now = DateTime.now();
    DateTime picked = _selectedMonth;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx2, StateSetter setS) => AlertDialog(
          title: Text(_t(strings, 'selectMonth', '달 선택')),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // 이전 달 이동 버튼
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setS(
                  () => picked = DateTime(picked.year, picked.month - 1),
                ),
              ),
              // 선택된 연월 표시
              Text(
                DateFormat('yyyy.MM').format(picked),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // 다음 달 이동 버튼 (현재 달 이후 비활성화)
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed:
                    picked.year > now.year ||
                        (picked.year == now.year && picked.month >= now.month)
                    ? null
                    : () => setS(
                        () => picked = DateTime(picked.year, picked.month + 1),
                      ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_t(strings, 'cancel', '취소')),
            ),
            FilledButton(
              onPressed: () {
                setState(
                  () => _selectedMonth = DateTime(picked.year, picked.month),
                );
                Navigator.of(ctx).pop();
              },
              child: Text(_t(strings, 'apply', '적용')),
            ),
          ],
        ),
      ),
    );
  }

  /// 날짜 범위 선택 피커를 표시한다.
  ///
  /// 선택이 완료되면 [_selectedRange]를 갱신해 UI에 반영한다.
  Future<void> _pickRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
    );
    if (picked != null) setState(() => _selectedRange = picked);
  }

  // ─── 빌드 ────────────────────────────────────────────────────────

  /// 페이지 전체 UI를 빌드한다.
  ///
  /// Riverpod으로 [localizedStringsProvider]와 [ledgerProvider]를 구독해
  /// 로컬라이즈 문자열과 원장 데이터를 얻는다.
  @override
  Widget build(BuildContext context) {
    final Map<String, String> strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;

    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String localeCode = ledger.settings.localeCode;

    return BootstrapPage(
      title: _t(strings, 'reportPageTitle', 'PDF 리포트 생성'),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── 기간 설정 카드 ────────────────────────────
              /// 월간·범위 모드를 전환하고 날짜를 선택하는 섹션이다.
              BootstrapSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    /// 섹션 제목: '기간 설정 (필수)'
                    Text(
                      _t(strings, 'reportPeriodLabel', '기간 설정 (필수)'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    /// 월간 / 기간 모드 선택 토글 버튼.
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<_PeriodMode>(
                        expandedInsets: EdgeInsets.zero,
                        selected: <_PeriodMode>{_periodMode},
                        segments: <ButtonSegment<_PeriodMode>>[
                          ButtonSegment<_PeriodMode>(
                            value: _PeriodMode.monthly,
                            label: Text(
                              _t(strings, 'analysisPeriodMonthly', '월간'),
                            ),
                          ),
                          ButtonSegment<_PeriodMode>(
                            value: _PeriodMode.range,
                            label: Text(
                              _t(strings, 'analysisPeriodRange', '기간'),
                            ),
                          ),
                        ],
                        onSelectionChanged: (Set<_PeriodMode> val) =>
                            setState(() => _periodMode = val.first),
                      ),
                    ),
                    const SizedBox(height: 12),

                    /// 월간 모드: 달 선택 버튼. 탭하면 [_pickMonth]를 호출한다.
                    if (_periodMode == _PeriodMode.monthly)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickMonth(context, strings),
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(
                            DateFormat('yyyy.MM').format(_selectedMonth),
                          ),
                        ),
                      ),

                    /// 범위 모드: 날짜 범위 선택 버튼. 탭하면 [_pickRange]를 호출한다.
                    if (_periodMode == _PeriodMode.range)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickRange(context),
                          icon: const Icon(Icons.date_range_rounded),
                          label: Text(
                            _selectedRange != null
                                ? '${DateFormat('yyyy-MM-dd').format(_selectedRange!.start)} ~ ${DateFormat('yyyy-MM-dd').format(_selectedRange!.end)}'
                                : _t(
                                    strings,
                                    'exportRangeStartDateLabel',
                                    '기간을 선택해주세요',
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── 이메일 입력 카드 ──────────────────────────
              /// PDF 표지에 기재될 이메일 주소를 입력하는 섹션이다.
              /// 이메일 형식 검증을 포함한다.
              BootstrapSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    /// 섹션 제목: '이메일 (필수)'
                    Text(
                      _t(strings, 'reportEmailLabel', '이메일 (필수)'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    /// 이메일 텍스트 입력 필드.
                    /// 비어 있거나 형식이 맞지 않으면 유효성 오류를 표시한다.
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
              const SizedBox(height: 12),

              // ── 암호 입력 카드 ────────────────────────────
              /// PDF 암호를 입력하는 섹션이다.
              /// 현재 버전은 PDF 암호화를 지원하지 않으므로 UI만 예약한다.
              BootstrapSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    /// 섹션 제목: 'PDF 암호 (선택)'
                    Text(
                      _t(strings, 'reportPasswordLabel', 'PDF 암호 (선택)'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    /// 암호 텍스트 입력 필드 (obscureText 적용).
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

                    /// 현재 암호화 미지원 안내 문구.
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

              // ── 포함할 데이터 체크박스 카드 ───────────────
              /// PDF에 포함할 섹션을 체크박스로 선택하는 카드다.
              /// 항목을 추가할 때는 [ReportOptions]에 필드를 추가하고
              /// 이 섹션에 [CheckboxListTile]을 하나 더 추가하면 된다.
              BootstrapSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    /// 섹션 제목: '포함할 데이터'
                    Text(
                      _t(strings, 'reportIncludeDataTitle', '포함할 데이터'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    /// Top 10 지출 내역 포함 여부 체크박스.
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _t(strings, 'reportIncludeTop10', 'Top 10 지출 내역'),
                      ),
                      value: _includeTop10,
                      onChanged: (bool? v) =>
                          setState(() => _includeTop10 = v ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    /// 고정지출 내역 포함 여부 체크박스.
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _t(strings, 'reportIncludeFixedExpenses', '고정지출 내역'),
                      ),
                      value: _includeFixedExpenses,
                      onChanged: (bool? v) =>
                          setState(() => _includeFixedExpenses = v ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    /// 소비수단 별 요약 포함 여부 체크박스.
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _t(strings, 'reportIncludePaymentSummary', '소비수단 별 요약'),
                      ),
                      value: _includePaymentSummary,
                      onChanged: (bool? v) =>
                          setState(() => _includePaymentSummary = v ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    /// 전체 거래내역(부록) 포함 여부 체크박스.
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _t(
                          strings,
                          'reportIncludeDetailedData',
                          '전체 거래내역 (부록)',
                        ),
                      ),
                      value: _includeDetailedData,
                      onChanged: (bool? v) =>
                          setState(() => _includeDetailedData = v ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── PDF 생성하기 버튼 ─────────────────────────
              /// 폼 유효성 검사 통과 및 쿨다운 해제 시 활성화되는 생성 버튼이다.
              /// 생성 중에는 스피너 아이콘과 '생성 중...' 텍스트를 표시한다.
              SizedBox(
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
              const SizedBox(height: 32),

              // ── 이전에 생성된 리포트 목록 ──────────────────
              /// 이전에 생성한 PDF 리포트 파일을 최신순으로 보여 주는 섹션이다.
              /// 각 항목에서 파일을 열거나 OS 공유 시트로 공유할 수 있다.
              Text(
                _t(strings, 'reportPreviousFiles', '이전에 생성된 리포트'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              /// 목록 로딩 중 표시.
              if (_loadingReports)
                const Center(child: CircularProgressIndicator())
              /// 생성된 파일이 없을 때 안내 문구.
              else if (_existingReports.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _t(strings, 'reportNoPreviousFiles', '이전에 생성된 파일이 없습니다'),
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              /// 파일 목록: 파일명·생성 일시·열기·공유 버튼을 포함하는 카드 목록.
              else
                ..._existingReports.map((File file) {
                  final String name = file.path
                      .split(Platform.pathSeparator)
                      .last;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      /// PDF 아이콘 (빨간색).
                      leading: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFFDC3545),
                      ),

                      /// 파일명 텍스트 (길면 말줄임표 처리).
                      title: Text(
                        name,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),

                      /// 파일 마지막 수정 일시 표시.
                      subtitle: Text(
                        DateFormat(
                          'yyyy/MM/dd HH:mm',
                        ).format(file.lastModifiedSync()),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          /// 열기 버튼: 기기 기본 PDF 뷰어로 파일을 연다.
                          IconButton(
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 20,
                            ),
                            tooltip: _t(strings, 'reportOpenFile', '열기'),
                            onPressed: () => OpenFile.open(file.path),
                          ),

                          /// 공유 버튼: OS 공유 시트를 통해 파일을 전송한다.
                          IconButton(
                            icon: const Icon(Icons.share_rounded, size: 20),
                            tooltip: _t(strings, 'reportShareFile', '공유'),
                            onPressed: () => Share.shareXFiles([
                              XFile(file.path, mimeType: 'application/pdf'),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
