import 'dart:io';
import 'dart:math' as math;

import 'package:household_ledger/model/reporting/report_options.dart';
import 'package:household_ledger/features/reporting/calculators/report_summary_calculator.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─── PDF 공통 색상 ─────────────────────────────────────────────────
const PdfColor _kBlue = PdfColor.fromInt(0xFF0D6EFD);
const PdfColor _kRed = PdfColor.fromInt(0xFFDC3545);
const PdfColor _kGreen = PdfColor.fromInt(0xFF198754);
const PdfColor _kDark = PdfColor.fromInt(0xFF212529);
const PdfColor _kGrey = PdfColor.fromInt(0xFF6C757D);
const PdfColor _kLightGrey = PdfColor.fromInt(0xFFF0F1F3);
const PdfColor _kBorder = PdfColor.fromInt(0xFFDEE2E6);
const PdfColor _kWhite = PdfColors.white;
const List<PdfColor> _kPalette = <PdfColor>[
  PdfColor.fromInt(0xFF1ABC9C),
  PdfColor.fromInt(0xFF3498DB),
  PdfColor.fromInt(0xFF9B59B6),
  PdfColor.fromInt(0xFFE74C3C),
  PdfColor.fromInt(0xFFF39C12),
  PdfColor.fromInt(0xFF27AE60),
  PdfColor.fromInt(0xFFE67E22),
  PdfColor.fromInt(0xFF2980B9),
];

PdfColor _paletteColor(int index) => _kPalette[index % _kPalette.length];
String _fmtAmount(int amount) => NumberFormat('#,###').format(amount.abs());

/// 텍스트 스타일 생성 함수의 타입 별칭이다.
typedef _TsFn = pw.TextStyle Function({double size, bool bold, PdfColor color});

/// PDF 가계부 리포트를 생성하고 파일을 관리하는 서비스다.
class ExportPdfReportService {
  // ─── 파일 경로 ──────────────────────────────────────────────────

  Future<Directory> _getReportDirectory() async {
    final Directory base;
    if (Platform.isAndroid) {
      final Directory? ext = await getExternalStorageDirectory();
      base = Directory('${ext!.path}/HouseLedger');
    } else {
      final Directory doc = await getApplicationDocumentsDirectory();
      base = Directory('${doc.path}/HouseLedger');
    }
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  /// 이전에 생성된 PDF 리포트 목록을 최신순으로 반환한다.
  Future<List<File>> getExistingReports() async {
    final Directory dir = await _getReportDirectory();
    if (!await dir.exists()) return <File>[];
    return dir
        .listSync()
        .whereType<File>()
        .where(
          (File f) =>
              f.path.endsWith('.pdf') &&
              f.path
                  .split(Platform.pathSeparator)
                  .last
                  .startsWith('Household_ledger_report_'),
        )
        .toList()
      ..sort(
        (File a, File b) =>
            b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
  }

  // ─── 폰트 로딩 ──────────────────────────────────────────────────

  /// 로케일에 맞는 기본 폰트를 로드한다.
  Future<pw.Font> _loadFont(String localeCode) async {
    try {
      return localeCode == 'jp'
          ? await PdfGoogleFonts.notoSansJPRegular()
          : await PdfGoogleFonts.notoSansKRRegular();
    } catch (_) {
      return pw.Font.helvetica();
    }
  }

  /// 로케일에 맞는 볼드 폰트를 로드한다.
  Future<pw.Font> _loadBoldFont(String localeCode) async {
    try {
      return localeCode == 'jp'
          ? await PdfGoogleFonts.notoSansJPBold()
          : await PdfGoogleFonts.notoSansKRBold();
    } catch (_) {
      return pw.Font.helveticaBold();
    }
  }

  // ─── 메인 생성 메서드 ────────────────────────────────────────────

  /// PDF 리포트를 생성하고 저장된 파일 경로를 반환한다.
  ///
  /// [periodLabel]은 표지 및 파일명에 쓰인다 (예: "2026-06" 또는 "2026-06-01~2026-06-30").
  ///
  /// ### 폰트 전략
  /// JP 로케일에서는 UI 문자열(일본어 헤더·섹션 제목)에 NotoSansJP를,
  /// 사용자 입력 데이터(한국어 설명·카테고리명·이름)에 NotoSansKR을 분리해 사용해
  /// 한글 깨짐을 방지한다.  KO 로케일에서는 두 폰트가 동일하다.
  Future<String> generateReport({
    required List<ExpenseEntry> expenses,
    required List<FixedExpense> fixedExpenses,
    required List<IncomeEntry> incomes,
    required LedgerState ledger,
    required String email,
    required ReportOptions options,
    required String periodLabel,
    required Map<String, String> strings,
    List<ExpenseEntry> prevExpenses = const <ExpenseEntry>[],
    DateTime? periodStart,
    DateTime? prevPeriodStart,
    String reportTitle = 'Household Ledger',
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.02);
    final String localeCode = ledger.settings.localeCode;
    final String currency = strings['currencyUnit'] ?? '₩';
    final String name = ledger.userProfile.name;

    // ── UI 폰트: 로케일 언어(JP or KO)용 ──
    final pw.Font uiFont = await _loadFont(localeCode);
    final pw.Font uiBoldFont = await _loadBoldFont(localeCode);
    onProgress?.call(0.12);

    // ── 데이터 폰트: 사용자 입력 한국어 콘텐츠(설명·태그명·이름)용 ──
    // JP 로케일에서도 데이터는 한국어이므로 KR 폰트를 별도 로드한다.
    final pw.Font dataFont = localeCode == 'jp'
        ? await _loadFont('ko')
        : uiFont;
    final pw.Font dataBoldFont = localeCode == 'jp'
        ? await _loadBoldFont('ko')
        : uiBoldFont;
    onProgress?.call(0.24);

    // ts : UI 문자열(언어팩, 컬럼 헤더, 섹션 제목)에 사용하는 스타일 팩토리
    pw.TextStyle ts({
      double size = 10,
      bool bold = false,
      PdfColor color = _kDark,
    }) => pw.TextStyle(
      font: bold ? uiBoldFont : uiFont,
      fontSize: size,
      color: color,
    );

    // tsD : 사용자 입력 데이터(한국어 설명·카테고리명·이름)에 사용하는 스타일 팩토리
    pw.TextStyle tsD({
      double size = 10,
      bool bold = false,
      PdfColor color = _kDark,
    }) => pw.TextStyle(
      font: bold ? dataBoldFont : dataFont,
      fontSize: size,
      color: color,
    );

    // ── UI·PDF 레이아웃과 무관한 리포트 집계 ──
    final summary = const ReportSummaryCalculator().calculate(
      expenses: expenses,
      fixedExpenses: fixedExpenses,
      incomes: incomes,
    );
    final int expenseTotal = summary.expenseTotal;
    final int fixedTotal = summary.fixedTotal;
    final int incomeTotal = summary.incomeTotal;
    final int combinedExpense = summary.combinedExpense;
    final int balance = summary.balance;
    final List<MapEntry<String, int>> catSorted = summary.categoryTotalsSorted;
    final List<MapEntry<String, int>> pmSorted =
        summary.paymentMethodTotalsSorted;
    onProgress?.call(0.32);

    // ── 태그 라벨 조회 ──
    String tagLabel(MetadataTagType type, String code) {
      try {
        return ledger
            .tagsByType(type)
            .firstWhere((MetadataTag t) => t.code == code)
            .label;
      } catch (_) {
        return code;
      }
    }

    // ── 차트용 데이터 계산 (tagLabel 선언 이후) ──
    // 카테고리별 건수 집계
    final Map<String, int> catCounts = summary.categoryCounts;

    // 도넛 차트 슬라이스: (label, amount, color, count)
    final List<(String, int, PdfColor, int)> pieSlices = catSorted
        .asMap()
        .entries
        .map(
          (MapEntry<int, MapEntry<String, int>> e) => (
            tagLabel(MetadataTagType.category, e.value.key),
            e.value.value,
            _paletteColor(e.key),
            catCounts[e.value.key] ?? 0,
          ),
        )
        .toList();

    // 일별 지출 집계: day → amount (period 기준)
    final List<MapEntry<int, int>> currDailyData = periodStart != null
        ? _groupExpensesByDay(expenses, periodStart)
        : <MapEntry<int, int>>[];
    final List<MapEntry<int, int>> prevDailyData =
        prevPeriodStart != null && prevExpenses.isNotEmpty
        ? _groupExpensesByDay(prevExpenses, prevPeriodStart)
        : <MapEntry<int, int>>[];

    // ── PDF 문서 생성 ──
    final pw.Document pdf = pw.Document(
      title: 'Household Ledger Report',
      author: name,
      subject: periodLabel,
    );

    // 1. 표지 (단일 페이지)
    pdf.addPage(
      _buildCoverPage(
        name: name,
        email: email,
        period: periodLabel,
        reportTitle: reportTitle,
        strings: strings,
        ts: ts,
        tsD: tsD,
      ),
    );
    onProgress?.call(0.40);

    // 2. 개요 (멀티페이지)
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (pw.Context ctx) => _pageHeader(name, periodLabel, ts, tsD),
        footer: (pw.Context ctx) => _pageFooter(ctx, ts),
        build: (pw.Context ctx) => _buildOverviewWidgets(
          expenses: expenses,
          fixedExpenses: fixedExpenses,
          expenseTotal: expenseTotal,
          fixedTotal: fixedTotal,
          incomeTotal: incomeTotal,
          combinedExpense: combinedExpense,
          balance: balance,
          catSorted: catSorted,
          pmSorted: pmSorted,
          currency: currency,
          tagLabel: tagLabel,
          options: options,
          strings: strings,
          ts: ts,
          tsD: tsD,
          pieSlices: pieSlices,
          currDailyData: currDailyData,
          prevDailyData: prevDailyData,
        ),
      ),
    );
    onProgress?.call(0.50);

    // 3. Top 10
    if (options.includeTop10) {
      final List<ExpenseEntry> top10 =
          (List<ExpenseEntry>.from(expenses)..sort(
                (ExpenseEntry a, ExpenseEntry b) =>
                    b.amount.compareTo(a.amount),
              ))
              .take(10)
              .toList();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (pw.Context ctx) => _pageHeader(name, periodLabel, ts, tsD),
          footer: (pw.Context ctx) => _pageFooter(ctx, ts),
          build: (pw.Context ctx) => _buildTop10Widgets(
            top10: top10,
            currency: currency,
            tagLabel: tagLabel,
            strings: strings,
            ts: ts,
            tsD: tsD,
          ),
        ),
      );
    }
    onProgress?.call(0.56);

    // 4. 전월동기 소비 비교
    if (options.includePrevComparison && prevExpenses.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (pw.Context ctx) => _pageHeader(name, periodLabel, ts, tsD),
          footer: (pw.Context ctx) => _pageFooter(ctx, ts),
          build: (pw.Context ctx) => _buildPrevComparisonWidgets(
            expenses: expenses,
            prevExpenses: prevExpenses,
            currency: currency,
            strings: strings,
            ts: ts,
          ),
        ),
      );
    }
    onProgress?.call(0.62);

    // 5. 카테고리별 전월동기 비교
    if (options.includePrevCategoryAnalysis && prevExpenses.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (pw.Context ctx) => _pageHeader(name, periodLabel, ts, tsD),
          footer: (pw.Context ctx) => _pageFooter(ctx, ts),
          build: (pw.Context ctx) => _buildPrevCategoryAnalysisWidgets(
            expenses: expenses,
            prevExpenses: prevExpenses,
            currency: currency,
            tagLabel: tagLabel,
            strings: strings,
            ts: ts,
            tsD: tsD,
          ),
        ),
      );
    }
    onProgress?.call(0.68);

    // 6. 전체 거래내역 (부록)
    if (options.includeDetailedData) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (pw.Context ctx) => _pageHeader(name, periodLabel, ts, tsD),
          footer: (pw.Context ctx) => _pageFooter(ctx, ts),
          build: (pw.Context ctx) => _buildAllTransactionsWidgets(
            expenses: expenses,
            fixedExpenses: fixedExpenses,
            incomes: incomes,
            currency: currency,
            tagLabel: tagLabel,
            strings: strings,
            ts: ts,
            tsD: tsD,
          ),
        ),
      );
    }
    onProgress?.call(0.75);

    // ── 저장 ──
    final List<int> bytes = await pdf.save();
    onProgress?.call(0.92);
    final String safeName = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final String safePeriod = periodLabel.replaceAll(
      RegExp(r'[/\\:*?"<>| ]'),
      '_',
    );
    final String fileName =
        'Household_ledger_report_${safeName}_$safePeriod.pdf';
    final Directory dir = await _getReportDirectory();
    onProgress?.call(0.96);
    final File file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    onProgress?.call(1.0);
    return file.path;
  }

  // ─── 표지 ────────────────────────────────────────────────────────

  pw.Page _buildCoverPage({
    required String name,
    required String email,
    required String period,
    required String reportTitle,
    required Map<String, String> strings,
    required _TsFn ts,
    required _TsFn tsD,
  }) {
    final String now = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          // 파란 헤더
          pw.Container(
            height: 220,
            color: _kBlue,
            padding: const pw.EdgeInsets.all(48),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: <pw.Widget>[
                pw.Text(
                  reportTitle,
                  style: ts(size: 28, bold: true, color: _kWhite),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  strings['pdfCoverSubtitle'] ?? '가계부 리포트',
                  style: ts(size: 16, color: _kWhite),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
          pw.Container(height: 5, color: const PdfColor.fromInt(0xFF0856C8)),
          // 정보 영역: 라벨은 ts(UI 언어), 값은 tsD(사용자 데이터)
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 56,
                vertical: 48,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: <pw.Widget>[
                  _coverRow(strings['pdfName'] ?? '이름', name, ts, tsD),
                  pw.SizedBox(height: 20),
                  _coverRow(strings['pdfEmail'] ?? '이메일', email, ts, tsD),
                  pw.SizedBox(height: 20),
                  _coverRow(strings['pdfPeriod'] ?? '기간', period, ts, tsD),
                  pw.SizedBox(height: 20),
                  _coverRow(strings['pdfGeneratedAt'] ?? '생성 일시', now, ts, tsD),
                ],
              ),
            ),
          ),
          // 하단 푸터 바
          pw.Container(
            height: 44,
            color: _kLightGrey,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 48,
              vertical: 10,
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text(reportTitle, style: ts(size: 8, color: _kGrey)),
                pw.Text(now, style: ts(size: 8, color: _kGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 표지의 라벨-값 한 행을 생성한다.
  ///
  /// [label]은 UI 언어 폰트([ts]), [value]는 데이터 폰트([tsD])를 사용한다.
  pw.Widget _coverRow(String label, String value, _TsFn ts, _TsFn tsD) =>
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 88,
            child: pw.Text(label, style: ts(size: 11, color: _kGrey)),
          ),
          pw.Container(width: 2, height: 18, color: _kBlue),
          pw.SizedBox(width: 14),
          pw.Expanded(child: pw.Text(value, style: tsD(size: 13, bold: true))),
        ],
      );

  // ─── 페이지 헤더 / 푸터 ──────────────────────────────────────────

  /// 멀티페이지 상단 헤더를 생성한다.
  ///
  /// 우측의 이름·기간 문자열은 사용자 데이터이므로 [tsD]를 사용한다.
  pw.Widget _pageHeader(
    String name,
    String period,
    _TsFn ts,
    _TsFn tsD,
  ) => pw.Column(
    children: <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text('Household Ledger Report', style: ts(size: 8, color: _kGrey)),
          // 이름은 한국어일 수 있으므로 tsD 사용
          pw.Text('$name | $period', style: tsD(size: 8, color: _kGrey)),
        ],
      ),
      pw.Container(
        height: 1,
        color: _kBorder,
        margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
      ),
    ],
  );

  /// 멀티페이지 하단 푸터를 생성한다.
  pw.Widget _pageFooter(pw.Context ctx, _TsFn ts) => pw.Column(
    children: <pw.Widget>[
      pw.Container(
        height: 1,
        color: _kBorder,
        margin: const pw.EdgeInsets.only(bottom: 4),
      ),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            DateFormat('yyyy/MM/dd').format(DateTime.now()),
            style: ts(size: 8, color: _kGrey),
          ),
          pw.Text(
            '${ctx.pageNumber} / ${ctx.pagesCount}',
            style: ts(size: 8, color: _kGrey),
          ),
        ],
      ),
    ],
  );

  // ─── 개요 섹션 ───────────────────────────────────────────────────

  List<pw.Widget> _buildOverviewWidgets({
    required List<ExpenseEntry> expenses,
    required List<FixedExpense> fixedExpenses,
    required int expenseTotal,
    required int fixedTotal,
    required int incomeTotal,
    required int combinedExpense,
    required int balance,
    required List<MapEntry<String, int>> catSorted,
    required List<MapEntry<String, int>> pmSorted,
    required String currency,
    required String Function(MetadataTagType, String) tagLabel,
    required ReportOptions options,
    required Map<String, String> strings,
    required _TsFn ts,
    required _TsFn tsD,
    required List<(String, int, PdfColor, int)> pieSlices,
    required List<MapEntry<int, int>> currDailyData,
    required List<MapEntry<int, int>> prevDailyData,
  }) {
    final List<pw.Widget> out = <pw.Widget>[
      _sectionHeader(strings['pdfSectionOverview'] ?? '이번 달 한눈에 보기', ts),
      pw.SizedBox(height: 12),
      // ── 요약 박스 3개 ──
      pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: _summaryBox(
              strings['pdfTotalExpense'] ?? '총 지출액',
              '$currency${_fmtAmount(combinedExpense)}',
              _kRed,
              ts,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _summaryBox(
              strings['pdfTotalIncome'] ?? '총 수입액',
              '$currency${_fmtAmount(incomeTotal)}',
              _kGreen,
              ts,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _summaryBox(
              strings['pdfBalance'] ?? '잔액',
              '$currency${_fmtAmount(balance)}',
              balance >= 0 ? _kGreen : _kRed,
              ts,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 20),
      // ── 카테고리별 지출 ──
      _sectionHeader(strings['pdfCategoryBreakdown'] ?? '카테고리별 지출', ts),
      pw.SizedBox(height: 8),
    ];

    for (int i = 0; i < catSorted.length; i++) {
      final String code = catSorted[i].key;
      final int amount = catSorted[i].value;
      final double pct = combinedExpense > 0
          ? amount / combinedExpense * 100
          : 0;
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          // 카테고리명은 사용자 데이터(한국어) → tsD
          child: _progressRow(
            tagLabel(MetadataTagType.category, code),
            amount,
            pct,
            currency,
            _paletteColor(i),
            ts,
            tsD,
          ),
        ),
      );
    }

    // ── 소비구분 분석 차트 (도넛) ──
    if (pieSlices.isNotEmpty) {
      out
        ..add(pw.SizedBox(height: 12))
        ..add(
          _sectionHeader(
            strings['pdfSectionCategoryChart'] ?? '소비구분 분석 차트',
            ts,
          ),
        )
        ..add(pw.SizedBox(height: 8))
        ..add(
          _buildPieChartWidget(
            pieSlices,
            combinedExpense,
            currency,
            strings,
            ts,
            tsD,
          ),
        )
        ..add(pw.SizedBox(height: 16));
    }

    // ── 고정지출 ──
    if (options.includeFixedExpenses && fixedExpenses.isNotEmpty) {
      out
        ..add(
          _sectionHeader(strings['pdfFixedExpenseSection'] ?? '고정지출 내역', ts),
        )
        ..add(pw.SizedBox(height: 8))
        ..add(
          pw.TableHelper.fromTextArray(
            headers: <String>[
              strings['pdfColDescription'] ?? '내용',
              strings['pdfColAmount'] ?? '금액',
            ],
            data: fixedExpenses
                .map(
                  (FixedExpense f) => <String>[
                    f.description,
                    '$currency${_fmtAmount(f.amount)}',
                  ],
                )
                .toList(),
            border: pw.TableBorder.all(color: _kBorder, width: 0.5),
            headerStyle: ts(size: 9, bold: true, color: _kWhite),
            headerDecoration: const pw.BoxDecoration(color: _kBlue),
            // 고정지출 설명은 한국어 사용자 데이터 → tsD
            cellStyle: tsD(size: 9),
            cellAlignments: <int, pw.Alignment>{1: pw.Alignment.centerRight},
            cellPadding: const pw.EdgeInsets.all(5),
            oddRowDecoration: const pw.BoxDecoration(color: _kLightGrey),
          ),
        )
        ..add(pw.SizedBox(height: 20));
    }

    // ── 소비수단 요약 ──
    if (options.includePaymentSummary && pmSorted.isNotEmpty) {
      out
        ..add(_sectionHeader(strings['pdfPaymentSummary'] ?? '소비수단 별 요약', ts))
        ..add(pw.SizedBox(height: 8));
      for (int i = 0; i < pmSorted.length; i++) {
        final int amount = pmSorted[i].value;
        final double pct = expenseTotal > 0 ? amount / expenseTotal * 100 : 0;
        out.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            // 소비수단명은 사용자 데이터(한국어) → tsD
            child: _progressRow(
              tagLabel(MetadataTagType.paymentMethod, pmSorted[i].key),
              amount,
              pct,
              currency,
              _paletteColor(i),
              ts,
              tsD,
            ),
          ),
        );
      }
      out.add(pw.SizedBox(height: 20));
    }

    // ── 일별 지출 추이 (Top 5) ──
    if (expenses.isNotEmpty) {
      final Map<String, int> daily = <String, int>{};
      for (final ExpenseEntry e in expenses) {
        final String key = DateFormat('MM/dd').format(e.spentAt);
        daily.update(key, (int v) => v + e.amount, ifAbsent: () => e.amount);
      }
      final List<MapEntry<String, int>> top5 =
          (daily.entries.toList()..sort(
                (MapEntry<String, int> a, MapEntry<String, int> b) =>
                    b.value.compareTo(a.value),
              ))
              .take(5)
              .toList();

      if (top5.isNotEmpty) {
        out
          ..add(
            _sectionHeader(
              strings['pdfDailyTrend'] ?? '일별 지출 추이 (Top 5 지출일)',
              ts,
            ),
          )
          ..add(pw.SizedBox(height: 8));
        final int topAmt = top5.first.value;
        for (int i = 0; i < top5.length; i++) {
          final int amt = top5[i].value;
          final int pctInt = (topAmt > 0 ? amt / topAmt * 100 : 0)
              .round()
              .clamp(1, 99);
          out.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                children: <pw.Widget>[
                  // 날짜는 숫자/슬래시 → ts
                  pw.SizedBox(
                    width: 44,
                    child: pw.Text(top5[i].key, style: ts(size: 9)),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Row(
                      children: <pw.Widget>[
                        pw.Expanded(
                          flex: pctInt,
                          child: pw.Container(height: 12, color: _kBlue),
                        ),
                        pw.Expanded(
                          flex: 100 - pctInt,
                          child: pw.Container(height: 12, color: _kLightGrey),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                    width: 80,
                    child: pw.Text(
                      '$currency${_fmtAmount(amt)}',
                      style: ts(size: 9),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    // ── 일별 지출 추이 차트 ──
    if (currDailyData.isNotEmpty) {
      out
        ..add(
          _sectionHeader(strings['pdfSectionDailyChart'] ?? '일별 지출 추이 차트', ts),
        )
        ..add(pw.SizedBox(height: 8))
        ..add(
          _buildLineChartWidget(
            currDailyData,
            prevDailyData,
            currency,
            strings,
            ts,
          ),
        )
        ..add(pw.SizedBox(height: 16));
    }

    return out;
  }

  // ─── 도넛(파이) 차트 위젯 ────────────────────────────────────────

  pw.Widget _buildPieChartWidget(
    List<(String, int, PdfColor, int)> slices,
    int total,
    String currency,
    Map<String, String> strings,
    _TsFn ts,
    _TsFn tsD,
  ) {
    final List<(int, PdfColor)> drawData = slices
        .map((s) => (s.$2, s.$3))
        .toList();
    final String countUnit = strings['pdfChartCountUnit'] ?? '건';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.CustomPaint(
          size: const PdfPoint(120, 120),
          painter: (PdfGraphics canvas, PdfPoint size) {
            final int tot = drawData.fold(
              0,
              (int s, (int, PdfColor) e) => s + e.$1,
            );
            if (tot == 0) return;
            final double cx = size.x / 2;
            final double cy = size.y / 2;
            final double r = math.min(cx, cy) * 0.90;
            final double innerR = r * 0.52;
            // π/2 = 12시 방향, 음수 sweep = 시계방향
            double startAngle = math.pi / 2;
            for (final (int amount, PdfColor color) in drawData) {
              if (amount == 0) continue;
              final double sweep = -(amount / tot * 2 * math.pi);
              final int steps = math.max(
                8,
                (sweep.abs() / math.pi * 30).ceil(),
              );
              final double dt = sweep / steps;
              canvas.setFillColor(color);
              canvas.moveTo(cx, cy);
              canvas.lineTo(
                cx + r * math.cos(startAngle),
                cy + r * math.sin(startAngle),
              );
              for (int i = 1; i <= steps; i++) {
                final double a = startAngle + dt * i;
                canvas.lineTo(cx + r * math.cos(a), cy + r * math.sin(a));
              }
              canvas.closePath();
              canvas.fillPath();
              startAngle += sweep;
            }
            // 도넛 구멍
            const double k = 0.5523;
            canvas.setFillColor(PdfColors.white);
            canvas.moveTo(cx + innerR, cy);
            canvas.curveTo(
              cx + innerR,
              cy + innerR * k,
              cx + innerR * k,
              cy + innerR,
              cx,
              cy + innerR,
            );
            canvas.curveTo(
              cx - innerR * k,
              cy + innerR,
              cx - innerR,
              cy + innerR * k,
              cx - innerR,
              cy,
            );
            canvas.curveTo(
              cx - innerR,
              cy - innerR * k,
              cx - innerR * k,
              cy - innerR,
              cx,
              cy - innerR,
            );
            canvas.curveTo(
              cx + innerR * k,
              cy - innerR,
              cx + innerR,
              cy - innerR * k,
              cx + innerR,
              cy,
            );
            canvas.closePath();
            canvas.fillPath();
          },
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: slices.map((s) {
              final double pct = total > 0 ? s.$2 / total * 100 : 0;
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  children: <pw.Widget>[
                    pw.Container(width: 8, height: 8, color: s.$3),
                    pw.SizedBox(width: 5),
                    pw.Expanded(
                      child: pw.Text(
                        s.$1,
                        style: tsD(size: 8),
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                    pw.Text(
                      '${s.$4}$countUnit  ${pct.round()}%  $currency${_fmtAmount(s.$2)}',
                      style: ts(size: 8),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── 꺾은선 차트 위젯 ────────────────────────────────────────────

  pw.Widget _buildLineChartWidget(
    List<MapEntry<int, int>> currData,
    List<MapEntry<int, int>> prevData,
    String currency,
    Map<String, String> strings,
    _TsFn ts,
  ) {
    const PdfColor prevColor = PdfColor.fromInt(0xFFFF8C42);
    const double canvasW = 446;
    const double canvasH = 100;
    const double yLabelW = 48;
    const double pT = 6.0;
    const double pB = 6.0;
    const double chartBottom = pB;
    const double chartTop = canvasH - pT;
    const double chartH = chartTop - chartBottom;

    final int maxDay = math.max(
      currData.isEmpty ? 1 : currData.last.key,
      prevData.isEmpty ? 1 : prevData.last.key,
    );
    final int maxAmt = math.max(
      currData.isEmpty
          ? 0
          : currData.map((MapEntry<int, int> e) => e.value).reduce(math.max),
      prevData.isEmpty
          ? 0
          : prevData.map((MapEntry<int, int> e) => e.value).reduce(math.max),
    );

    MapEntry<int, int>? maxOf(List<MapEntry<int, int>> d) =>
        d.isEmpty ? null : d.reduce((a, b) => a.value >= b.value ? a : b);
    MapEntry<int, int>? minOf(List<MapEntry<int, int>> d) =>
        d.isEmpty ? null : d.reduce((a, b) => a.value <= b.value ? a : b);

    final MapEntry<int, int>? currMax = maxOf(currData);
    final MapEntry<int, int>? currMin = minOf(currData);
    final MapEntry<int, int>? prevMax = maxOf(prevData);
    final MapEntry<int, int>? prevMin = minOf(prevData);

    final String daySuffix = strings['chartDateDaySuffix'] ?? '일';
    final String maxLabel = strings['analysisDailyMaxLabel'] ?? '가장 지출이 많은 날';
    final String minLabel = strings['analysisDailyMinLabel'] ?? '가장 지출이 적은 날';
    final String currLbl = strings['analysisDailyCurrMonth'] ?? '이번달';
    final String prevLbl = strings['analysisDailyPrevMonth'] ?? '전월';

    final List<pw.Widget> stats = <pw.Widget>[];
    if (currMax != null) {
      stats.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            '$currLbl  $maxLabel : ${currMax.key}$daySuffix  $currency${_fmtAmount(currMax.value)}',
            style: ts(size: 8, color: _kRed),
          ),
        ),
      );
    }
    if (currMin != null) {
      stats.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            '$currLbl  $minLabel : ${currMin.key}$daySuffix  $currency${_fmtAmount(currMin.value)}',
            style: ts(size: 8, color: _kGreen),
          ),
        ),
      );
    }
    if (prevMax != null) {
      stats.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            '$prevLbl  $maxLabel : ${prevMax.key}$daySuffix  $currency${_fmtAmount(prevMax.value)}',
            style: ts(size: 8, color: _kRed),
          ),
        ),
      );
    }
    if (prevMin != null) {
      stats.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            '$prevLbl  $minLabel : ${prevMin.key}$daySuffix  $currency${_fmtAmount(prevMin.value)}',
            style: ts(size: 8, color: _kGreen),
          ),
        ),
      );
    }

    // Y축 레이블 (pw.Positioned 오버레이 — canvas.drawString 불필요)
    final List<pw.Widget> yLabels = <pw.Widget>[];
    if (maxAmt > 0) {
      for (int i = 4; i >= 1; i--) {
        final double canvasY = chartBottom + chartH * i / 4;
        final double widgetTop = canvasH - canvasY - 4;
        yLabels.add(
          pw.Positioned(
            right: 2,
            top: widgetTop,
            child: pw.Text(
              _pdfYLabelAscii((maxAmt * i / 4).round()),
              style: ts(size: 6, color: _kGrey),
            ),
          ),
        );
      }
    }

    // X축 레이블
    final List<pw.Widget> xLabels = _computeXLabelDays(maxDay).map((int day) {
      final double x = maxDay <= 1 ? 0.0 : (day - 1) / (maxDay - 1) * canvasW;
      return pw.Positioned(
        left: math.max(0.0, x - 4),
        top: 0,
        child: pw.Text('$day', style: ts(size: 6, color: _kGrey)),
      );
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            // Y축 레이블 오버레이
            pw.SizedBox(
              width: yLabelW,
              height: canvasH,
              child: pw.Stack(children: yLabels),
            ),
            pw.SizedBox(width: 4),
            // 차트 캔버스 (격자·선·점만 — 텍스트 없음)
            pw.CustomPaint(
              size: const PdfPoint(canvasW, canvasH),
              painter: (PdfGraphics canvas, PdfPoint size) {
                if (maxAmt == 0) return;
                final double w = size.x;

                double px(int day) =>
                    maxDay <= 1 ? 0.0 : (day - 1) / (maxDay - 1) * w;
                double py(int amount) =>
                    chartBottom + (amount / maxAmt) * chartH;

                // Y 격자선
                canvas.setLineWidth(0.4);
                for (int i = 1; i <= 4; i++) {
                  final double y = chartBottom + chartH * i / 4;
                  canvas.setStrokeColor(const PdfColor.fromInt(0xFFE0E0E0));
                  canvas.drawLine(0, y, w, y);
                }

                // X축선
                canvas.setStrokeColor(const PdfColor.fromInt(0xFFAAAAAA));
                canvas.setLineWidth(0.6);
                canvas.drawLine(0, chartBottom, w, chartBottom);

                // 전월 선 + 점
                if (prevData.isNotEmpty) {
                  canvas.setStrokeColor(prevColor);
                  canvas.setLineWidth(1.0);
                  for (int i = 0; i < prevData.length - 1; i++) {
                    canvas.drawLine(
                      px(prevData[i].key),
                      py(prevData[i].value),
                      px(prevData[i + 1].key),
                      py(prevData[i + 1].value),
                    );
                  }
                  canvas.setFillColor(prevColor);
                  for (final MapEntry<int, int> e in prevData) {
                    _drawDot(canvas, px(e.key), py(e.value), 1.8);
                  }
                }

                // 이번달 선 + 점
                if (currData.length >= 2) {
                  canvas.setStrokeColor(_kBlue);
                  canvas.setLineWidth(1.8);
                  for (int i = 0; i < currData.length - 1; i++) {
                    canvas.drawLine(
                      px(currData[i].key),
                      py(currData[i].value),
                      px(currData[i + 1].key),
                      py(currData[i + 1].value),
                    );
                  }
                }
                canvas.setFillColor(_kBlue);
                for (final MapEntry<int, int> e in currData) {
                  _drawDot(canvas, px(e.key), py(e.value), 2.2);
                }
              },
            ),
          ],
        ),
        // X축 레이블 행
        pw.Row(
          children: <pw.Widget>[
            pw.SizedBox(width: yLabelW + 4),
            pw.SizedBox(
              width: canvasW,
              height: 14,
              child: pw.Stack(children: xLabels),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        // 범례
        pw.Row(
          children: <pw.Widget>[
            pw.Container(width: 16, height: 3, color: _kBlue),
            pw.SizedBox(width: 4),
            pw.Text(currLbl, style: ts(size: 8)),
            if (prevData.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(width: 12),
              pw.Container(width: 16, height: 3, color: prevColor),
              pw.SizedBox(width: 4),
              pw.Text(prevLbl, style: ts(size: 8)),
            ],
          ],
        ),
        if (stats.isNotEmpty) ...<pw.Widget>[pw.SizedBox(height: 8), ...stats],
      ],
    );
  }

  // ─── 전월동기 소비 비교 섹션 ──────────────────────────────────────

  List<pw.Widget> _buildPrevComparisonWidgets({
    required List<ExpenseEntry> expenses,
    required List<ExpenseEntry> prevExpenses,
    required String currency,
    required Map<String, String> strings,
    required _TsFn ts,
  }) {
    final int currTotal = expenses.fold(
      0,
      (int s, ExpenseEntry e) => s + e.amount,
    );
    final int prevTotal = prevExpenses.fold(
      0,
      (int s, ExpenseEntry e) => s + e.amount,
    );
    final int diff = currTotal - prevTotal;
    final String diffStr =
        '${diff >= 0 ? '+' : ''}$currency${_fmtAmount(diff)}';
    final PdfColor diffColor = diff > 0 ? _kRed : _kGreen;

    return <pw.Widget>[
      _sectionHeader(strings['pdfSectionPrevComparison'] ?? '전월동기 소비 비교', ts),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: <String>[
          strings['pdfColType'] ?? '구분',
          strings['pdfCurrentPeriod'] ?? '이번 달',
          strings['pdfPrevPeriod'] ?? '전월동기',
          strings['pdfDiffLabel'] ?? '차이',
        ],
        data: <List<String>>[
          <String>[
            strings['pdfTotalExpense'] ?? '총 지출액',
            '$currency${_fmtAmount(currTotal)}',
            '$currency${_fmtAmount(prevTotal)}',
            diffStr,
          ],
        ],
        border: pw.TableBorder.all(color: _kBorder, width: 0.5),
        headerStyle: ts(size: 9, bold: true, color: _kWhite),
        headerDecoration: const pw.BoxDecoration(color: _kBlue),
        cellStyle: ts(size: 10),
        cellAlignments: <int, pw.Alignment>{
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        cellPadding: const pw.EdgeInsets.all(6),
      ),
      pw.SizedBox(height: 16),
      // 요약 박스
      pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: _summaryBox(
              strings['pdfCurrentPeriod'] ?? '이번 달',
              '$currency${_fmtAmount(currTotal)}',
              _kBlue,
              ts,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _summaryBox(
              strings['pdfPrevPeriod'] ?? '전월동기',
              '$currency${_fmtAmount(prevTotal)}',
              _kGrey,
              ts,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _summaryBox(
              strings['pdfDiffLabel'] ?? '차이',
              diffStr,
              diffColor,
              ts,
            ),
          ),
        ],
      ),
    ];
  }

  // ─── 카테고리별 전월동기 비교 섹션 ───────────────────────────────

  List<pw.Widget> _buildPrevCategoryAnalysisWidgets({
    required List<ExpenseEntry> expenses,
    required List<ExpenseEntry> prevExpenses,
    required String currency,
    required String Function(MetadataTagType, String) tagLabel,
    required Map<String, String> strings,
    required _TsFn ts,
    required _TsFn tsD,
  }) {
    final Map<String, int> currCat = <String, int>{};
    for (final ExpenseEntry e in expenses) {
      currCat.update(
        e.categoryCode,
        (int v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
    }
    final Map<String, int> prevCat = <String, int>{};
    for (final ExpenseEntry e in prevExpenses) {
      prevCat.update(
        e.categoryCode,
        (int v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
    }

    final Set<String> allCodes = <String>{...currCat.keys, ...prevCat.keys};
    final List<(String, int, int)> rows =
        allCodes
            .map(
              (String code) => (
                tagLabel(MetadataTagType.category, code),
                currCat[code] ?? 0,
                prevCat[code] ?? 0,
              ),
            )
            .toList()
          ..sort(
            ((String, int, int) a, (String, int, int) b) =>
                b.$2.compareTo(a.$2),
          );

    return <pw.Widget>[
      _sectionHeader(
        strings['pdfSectionPrevCategoryAnalysis'] ?? '카테고리별 전월동기 비교',
        ts,
      ),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: <String>[
          strings['categoryLabel'] ?? '카테고리',
          strings['pdfCurrentPeriod'] ?? '이번 달',
          strings['pdfPrevPeriod'] ?? '전월동기',
          strings['pdfDiffLabel'] ?? '차이',
        ],
        data: rows.map(((String, int, int) r) {
          final int diff = r.$2 - r.$3;
          return <String>[
            r.$1,
            '$currency${_fmtAmount(r.$2)}',
            '$currency${_fmtAmount(r.$3)}',
            '${diff >= 0 ? '+' : ''}$currency${_fmtAmount(diff)}',
          ];
        }).toList(),
        border: pw.TableBorder.all(color: _kBorder, width: 0.5),
        headerStyle: ts(size: 9, bold: true, color: _kWhite),
        headerDecoration: const pw.BoxDecoration(color: _kBlue),
        cellStyle: tsD(size: 9),
        cellAlignments: <int, pw.Alignment>{
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        cellPadding: const pw.EdgeInsets.all(5),
        oddRowDecoration: const pw.BoxDecoration(color: _kLightGrey),
      ),
    ];
  }

  // ─── 헬퍼: 일별 지출 집계 ────────────────────────────────────────

  static List<MapEntry<int, int>> _groupExpensesByDay(
    List<ExpenseEntry> expenses,
    DateTime periodStart,
  ) {
    final DateTime base = DateTime(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );
    final Map<int, int> daily = <int, int>{};
    for (final ExpenseEntry e in expenses) {
      final int day =
          DateTime(
            e.spentAt.year,
            e.spentAt.month,
            e.spentAt.day,
          ).difference(base).inDays +
          1;
      if (day < 1) continue;
      daily.update(day, (int v) => v + e.amount, ifAbsent: () => e.amount);
    }
    return daily.entries.toList()..sort(
      (MapEntry<int, int> a, MapEntry<int, int> b) => a.key.compareTo(b.key),
    );
  }

  // ─── Top 10 섹션 ─────────────────────────────────────────────────

  List<pw.Widget> _buildTop10Widgets({
    required List<ExpenseEntry> top10,
    required String currency,
    required String Function(MetadataTagType, String) tagLabel,
    required Map<String, String> strings,
    required _TsFn ts,
    required _TsFn tsD,
  }) => <pw.Widget>[
    _sectionHeader(strings['pdfSectionTop10'] ?? '지출 Top 10', ts),
    pw.SizedBox(height: 12),
    pw.TableHelper.fromTextArray(
      headers: <String>[
        strings['pdfColNo'] ?? '순위',
        strings['pdfColDate'] ?? '날짜',
        strings['pdfColCategory'] ?? '카테고리',
        strings['pdfColDescription'] ?? '내용',
        strings['pdfColAmount'] ?? '금액',
      ],
      data: top10
          .asMap()
          .entries
          .map(
            (MapEntry<int, ExpenseEntry> e) => <String>[
              '${e.key + 1}',
              DateFormat('yyyy/MM/dd').format(e.value.spentAt),
              tagLabel(MetadataTagType.category, e.value.categoryCode),
              e.value.description,
              '$currency${_fmtAmount(e.value.amount)}',
            ],
          )
          .toList(),
      border: pw.TableBorder.all(color: _kBorder, width: 0.5),
      headerStyle: ts(size: 9, bold: true, color: _kWhite),
      headerDecoration: const pw.BoxDecoration(color: _kBlue),
      // 카테고리명·설명은 한국어 사용자 데이터 → tsD
      cellStyle: tsD(size: 9),
      cellAlignments: <int, pw.Alignment>{
        0: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.all(5),
      oddRowDecoration: const pw.BoxDecoration(color: _kLightGrey),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FixedColumnWidth(28),
        1: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(80),
      },
    ),
  ];

  // ─── 전체 거래내역 (부록) ─────────────────────────────────────────

  List<pw.Widget> _buildAllTransactionsWidgets({
    required List<ExpenseEntry> expenses,
    required List<FixedExpense> fixedExpenses,
    required List<IncomeEntry> incomes,
    required String currency,
    required String Function(MetadataTagType, String) tagLabel,
    required Map<String, String> strings,
    required _TsFn ts,
    required _TsFn tsD,
  }) {
    final List<List<String>> rows = <List<String>>[];

    for (final ExpenseEntry e
        in (List<ExpenseEntry>.from(expenses)..sort(
          (ExpenseEntry a, ExpenseEntry b) => b.spentAt.compareTo(a.spentAt),
        ))) {
      rows.add(<String>[
        DateFormat('yyyy/MM/dd').format(e.spentAt),
        strings['pdfTypeExpense'] ?? '지출',
        tagLabel(MetadataTagType.category, e.categoryCode),
        e.description,
        '-$currency${_fmtAmount(e.amount)}',
      ]);
    }
    for (final IncomeEntry i
        in (List<IncomeEntry>.from(incomes)..sort(
          (IncomeEntry a, IncomeEntry b) => b.earnedAt.compareTo(a.earnedAt),
        ))) {
      rows.add(<String>[
        DateFormat('yyyy/MM/dd').format(i.earnedAt),
        strings['pdfTypeIncome'] ?? '수입',
        '-',
        i.description,
        '+$currency${_fmtAmount(i.amount)}',
      ]);
    }
    for (final FixedExpense f in fixedExpenses) {
      rows.add(<String>[
        DateFormat('yyyy/MM').format(f.appliedAt),
        strings['pdfTypeFixed'] ?? '고정지출',
        tagLabel(MetadataTagType.category, f.categoryCode),
        f.description,
        '-$currency${_fmtAmount(f.amount)}',
      ]);
    }

    return <pw.Widget>[
      _sectionHeader(
        strings['pdfSectionAllTransactions'] ?? '전체 거래내역 (부록)',
        ts,
      ),
      pw.SizedBox(height: 12),
      if (rows.isEmpty)
        pw.Text('-', style: ts(size: 9, color: _kGrey))
      else
        pw.TableHelper.fromTextArray(
          headers: <String>[
            strings['pdfColDate'] ?? '날짜',
            strings['pdfColType'] ?? '구분',
            strings['pdfColCategory'] ?? '카테고리',
            strings['pdfColDescription'] ?? '내용',
            strings['pdfColAmount'] ?? '금액',
          ],
          data: rows,
          border: pw.TableBorder.all(color: _kBorder, width: 0.5),
          headerStyle: ts(size: 8, bold: true, color: _kWhite),
          headerDecoration: const pw.BoxDecoration(color: _kDark),
          // 카테고리명·설명은 한국어 사용자 데이터 → tsD
          // 구분('지출'/'수입'/'고정지출')은 한자이므로 KR 폰트로 렌더링 가능
          cellStyle: tsD(size: 8),
          cellAlignments: <int, pw.Alignment>{4: pw.Alignment.centerRight},
          cellPadding: const pw.EdgeInsets.all(4),
          oddRowDecoration: const pw.BoxDecoration(color: _kLightGrey),
          columnWidths: <int, pw.TableColumnWidth>{
            0: const pw.FixedColumnWidth(60),
            1: const pw.FixedColumnWidth(44),
            4: const pw.FixedColumnWidth(72),
          },
        ),
    ];
  }

  // ─── 공통 위젯 빌더 ──────────────────────────────────────────────

  /// 섹션 제목과 구분선을 생성한다.
  pw.Widget _sectionHeader(String title, _TsFn ts) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.SizedBox(height: 8),
      pw.Text(title, style: ts(size: 14, bold: true, color: _kBlue)),
      pw.Container(
        height: 2,
        color: _kBlue,
        margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
      ),
    ],
  );

  /// 요약 수치 박스를 생성한다.
  pw.Widget _summaryBox(String label, String value, PdfColor color, _TsFn ts) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(label, style: ts(size: 8, color: _kGrey)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: ts(size: 12, bold: true, color: color)),
          ],
        ),
      );

  // ─── 차트 헬퍼 ───────────────────────────────────────────────────

  /// 베지어 근사로 원형 점을 그린다.
  static void _drawDot(PdfGraphics canvas, double x, double y, double r) {
    const double k = 0.5523;
    canvas.moveTo(x + r, y);
    canvas.curveTo(x + r, y + r * k, x + r * k, y + r, x, y + r);
    canvas.curveTo(x - r * k, y + r, x - r, y + r * k, x - r, y);
    canvas.curveTo(x - r, y - r * k, x - r * k, y - r, x, y - r);
    canvas.curveTo(x + r * k, y - r, x + r, y - r * k, x + r, y);
    canvas.closePath();
    canvas.fillPath();
  }

  /// 금액을 ASCII 약식 표현으로 변환한다 (예: 1200000 → "1.2M", 45000 → "45K").
  static String _pdfYLabelAscii(int amount) {
    if (amount == 0) return '0';
    if (amount >= 1000000) {
      final double m = amount / 1000000;
      return '${m % 1 == 0 ? m.round() : m.toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      final double k = amount / 1000;
      return '${k % 1 == 0 ? k.round() : k.toStringAsFixed(1)}K';
    }
    return '$amount';
  }

  /// X축에 표시할 대표 날짜 목록을 반환한다.
  static List<int> _computeXLabelDays(int maxDay) {
    if (maxDay <= 7) {
      return List<int>.generate(maxDay, (int i) => i + 1);
    }
    const List<int> candidates = <int>[1, 5, 10, 15, 20, 25, 31];
    return candidates.where((int d) => d <= maxDay).toList();
  }

  /// 가로 바 형태의 진행률 행을 생성한다.
  ///
  /// [label]은 사용자 정의 태그명(한국어)이므로 [tsD]를 사용한다.
  /// 수치·퍼센트는 숫자이므로 [ts]를 사용해도 무방하다.
  pw.Widget _progressRow(
    String label,
    int amount,
    double pct,
    String currency,
    PdfColor barColor,
    _TsFn ts,
    _TsFn tsD,
  ) {
    final int filled = pct.round().clamp(1, 99);
    final int empty = 100 - filled;
    return pw.Row(
      children: <pw.Widget>[
        pw.SizedBox(
          width: 80,
          // 카테고리·소비수단명은 한국어 → tsD
          child: pw.Text(
            label,
            style: tsD(size: 9),
            overflow: pw.TextOverflow.clip,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Row(
            children: <pw.Widget>[
              pw.Expanded(
                flex: filled,
                child: pw.Container(height: 10, color: barColor),
              ),
              pw.Expanded(
                flex: empty,
                child: pw.Container(height: 10, color: _kLightGrey),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 28,
          child: pw.Text(
            '${pct.round()}%',
            style: ts(size: 9),
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 80,
          child: pw.Text(
            '$currency${_fmtAmount(amount)}',
            style: ts(size: 9, bold: true),
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }
}
