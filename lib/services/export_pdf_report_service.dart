import 'dart:io';

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

/// PDF 리포트에 포함할 데이터 옵션을 담는다.
///
/// 항목을 확장할 때는 필드를 추가하고 UI 체크박스와 PDF 섹션을 함께 늘리면 된다.
class ReportOptions {
  const ReportOptions({
    this.includeDetailedData = true,
    this.includeTop10 = true,
    this.includeFixedExpenses = true,
    this.includePaymentSummary = true,
  });

  final bool includeDetailedData;
  final bool includeTop10;
  final bool includeFixedExpenses;
  final bool includePaymentSummary;
}

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
typedef _TsFn = pw.TextStyle Function(
    {double size, bool bold, PdfColor color});

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
        .where((File f) =>
            f.path.endsWith('.pdf') &&
            f.path.split(Platform.pathSeparator).last
                .startsWith('Household_ledger_report_'))
        .toList()
      ..sort((File a, File b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));
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
  }) async {
    final String localeCode = ledger.settings.localeCode;
    final String currency = strings['currencyUnit'] ?? '₩';
    final String name = ledger.userProfile.name;

    // ── UI 폰트: 로케일 언어(JP or KO)용 ──
    final pw.Font uiFont = await _loadFont(localeCode);
    final pw.Font uiBoldFont = await _loadBoldFont(localeCode);

    // ── 데이터 폰트: 사용자 입력 한국어 콘텐츠(설명·태그명·이름)용 ──
    // JP 로케일에서도 데이터는 한국어이므로 KR 폰트를 별도 로드한다.
    final pw.Font dataFont =
        localeCode == 'jp' ? await _loadFont('ko') : uiFont;
    final pw.Font dataBoldFont =
        localeCode == 'jp' ? await _loadBoldFont('ko') : uiBoldFont;

    // ts : UI 문자열(언어팩, 컬럼 헤더, 섹션 제목)에 사용하는 스타일 팩토리
    pw.TextStyle ts({
      double size = 10,
      bool bold = false,
      PdfColor color = _kDark,
    }) =>
        pw.TextStyle(
          font: bold ? uiBoldFont : uiFont,
          fontSize: size,
          color: color,
        );

    // tsD : 사용자 입력 데이터(한국어 설명·카테고리명·이름)에 사용하는 스타일 팩토리
    pw.TextStyle tsD({
      double size = 10,
      bool bold = false,
      PdfColor color = _kDark,
    }) =>
        pw.TextStyle(
          font: bold ? dataBoldFont : dataFont,
          fontSize: size,
          color: color,
        );

    // ── 집계 ──
    final int expenseTotal =
        expenses.fold(0, (int s, ExpenseEntry e) => s + e.amount);
    final int fixedTotal =
        fixedExpenses.fold(0, (int s, FixedExpense f) => s + f.amount);
    final int incomeTotal =
        incomes.fold(0, (int s, IncomeEntry i) => s + i.amount);
    final int combinedExpense = expenseTotal + fixedTotal;
    final int balance = incomeTotal - combinedExpense;

    // ── 카테고리 집계 ──
    final Map<String, int> catSums = <String, int>{};
    for (final ExpenseEntry e in expenses) {
      catSums.update(e.categoryCode, (int v) => v + e.amount,
          ifAbsent: () => e.amount);
    }
    final List<MapEntry<String, int>> catSorted = catSums.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));

    // ── 소비수단 집계 ──
    final Map<String, int> pmSums = <String, int>{};
    for (final ExpenseEntry e in expenses) {
      if (e.paymentMethodCode.isNotEmpty) {
        pmSums.update(e.paymentMethodCode, (int v) => v + e.amount,
            ifAbsent: () => e.amount);
      }
    }
    final List<MapEntry<String, int>> pmSorted = pmSums.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));

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

    // ── PDF 문서 생성 ──
    final pw.Document pdf = pw.Document(
      title: 'Household Ledger Report',
      author: name,
      subject: periodLabel,
    );

    // 1. 표지 (단일 페이지)
    pdf.addPage(_buildCoverPage(
      name: name,
      email: email,
      period: periodLabel,
      strings: strings,
      ts: ts,
      tsD: tsD,
    ));

    // 2. 개요 (멀티페이지)
    pdf.addPage(pw.MultiPage(
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
      ),
    ));

    // 3. Top 10
    if (options.includeTop10) {
      final List<ExpenseEntry> top10 = (List<ExpenseEntry>.from(expenses)
            ..sort((ExpenseEntry a, ExpenseEntry b) =>
                b.amount.compareTo(a.amount)))
          .take(10)
          .toList();
      pdf.addPage(pw.MultiPage(
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
      ));
    }

    // 4. 전체 거래내역 (부록)
    if (options.includeDetailedData) {
      pdf.addPage(pw.MultiPage(
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
      ));
    }

    // ── 저장 ──
    final List<int> bytes = await pdf.save();
    final String safeName =
        name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final String safePeriod =
        periodLabel.replaceAll(RegExp(r'[/\\:*?"<>| ]'), '_');
    final String fileName =
        'Household_ledger_report_${safeName}_$safePeriod.pdf';
    final Directory dir = await _getReportDirectory();
    final File file =
        File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ─── 표지 ────────────────────────────────────────────────────────

  pw.Page _buildCoverPage({
    required String name,
    required String email,
    required String period,
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
                pw.Text('Household Ledger',
                    style: ts(size: 28, bold: true, color: _kWhite),
                    textAlign: pw.TextAlign.center),
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
                  horizontal: 56, vertical: 48),
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
                  _coverRow(
                      strings['pdfGeneratedAt'] ?? '생성 일시', now, ts, tsD),
                ],
              ),
            ),
          ),
          // 하단 푸터 바
          pw.Container(
            height: 44,
            color: _kLightGrey,
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 48, vertical: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[
                pw.Text('Household Ledger App',
                    style: ts(size: 8, color: _kGrey)),
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
  pw.Widget _coverRow(
    String label,
    String value,
    _TsFn ts,
    _TsFn tsD,
  ) =>
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          pw.SizedBox(
              width: 88,
              child: pw.Text(label, style: ts(size: 11, color: _kGrey))),
          pw.Container(width: 2, height: 18, color: _kBlue),
          pw.SizedBox(width: 14),
          pw.Expanded(
              child: pw.Text(value, style: tsD(size: 13, bold: true))),
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
  ) =>
      pw.Column(
        children: <pw.Widget>[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text('Household Ledger Report',
                  style: ts(size: 8, color: _kGrey)),
              // 이름은 한국어일 수 있으므로 tsD 사용
              pw.Text('$name | $period',
                  style: tsD(size: 8, color: _kGrey)),
            ],
          ),
          pw.Container(
              height: 1,
              color: _kBorder,
              margin: const pw.EdgeInsets.only(top: 4, bottom: 8)),
        ],
      );

  /// 멀티페이지 하단 푸터를 생성한다.
  pw.Widget _pageFooter(pw.Context ctx, _TsFn ts) => pw.Column(
        children: <pw.Widget>[
          pw.Container(
              height: 1,
              color: _kBorder,
              margin: const pw.EdgeInsets.only(bottom: 4)),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(DateFormat('yyyy/MM/dd').format(DateTime.now()),
                  style: ts(size: 8, color: _kGrey)),
              pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: ts(size: 8, color: _kGrey)),
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
                  ts)),
          pw.SizedBox(width: 8),
          pw.Expanded(
              child: _summaryBox(
                  strings['pdfTotalIncome'] ?? '총 수입액',
                  '$currency${_fmtAmount(incomeTotal)}',
                  _kGreen,
                  ts)),
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
      final double pct =
          combinedExpense > 0 ? amount / combinedExpense * 100 : 0;
      out.add(pw.Padding(
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
      ));
    }

    // ── 고정지출 ──
    if (options.includeFixedExpenses && fixedExpenses.isNotEmpty) {
      out
        ..add(_sectionHeader(
            strings['pdfFixedExpenseSection'] ?? '고정지출 내역', ts))
        ..add(pw.SizedBox(height: 8))
        ..add(pw.TableHelper.fromTextArray(
          headers: <String>[
            strings['pdfColDescription'] ?? '내용',
            strings['pdfColAmount'] ?? '금액',
          ],
          data: fixedExpenses
              .map((FixedExpense f) => <String>[
                    f.description,
                    '$currency${_fmtAmount(f.amount)}',
                  ])
              .toList(),
          border: pw.TableBorder.all(color: _kBorder, width: 0.5),
          headerStyle: ts(size: 9, bold: true, color: _kWhite),
          headerDecoration: const pw.BoxDecoration(color: _kBlue),
          // 고정지출 설명은 한국어 사용자 데이터 → tsD
          cellStyle: tsD(size: 9),
          cellAlignments: <int, pw.Alignment>{
            1: pw.Alignment.centerRight,
          },
          cellPadding: const pw.EdgeInsets.all(5),
          oddRowDecoration: const pw.BoxDecoration(color: _kLightGrey),
        ))
        ..add(pw.SizedBox(height: 20));
    }

    // ── 소비수단 요약 ──
    if (options.includePaymentSummary && pmSorted.isNotEmpty) {
      out
        ..add(_sectionHeader(
            strings['pdfPaymentSummary'] ?? '소비수단 별 요약', ts))
        ..add(pw.SizedBox(height: 8));
      for (int i = 0; i < pmSorted.length; i++) {
        final int amount = pmSorted[i].value;
        final double pct =
            expenseTotal > 0 ? amount / expenseTotal * 100 : 0;
        out.add(pw.Padding(
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
        ));
      }
      out.add(pw.SizedBox(height: 20));
    }

    // ── 일별 지출 추이 (Top 5) ──
    if (expenses.isNotEmpty) {
      final Map<String, int> daily = <String, int>{};
      for (final ExpenseEntry e in expenses) {
        final String key = DateFormat('MM/dd').format(e.spentAt);
        daily.update(key, (int v) => v + e.amount,
            ifAbsent: () => e.amount);
      }
      final List<MapEntry<String, int>> top5 =
          (daily.entries.toList()
                ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
                    b.value.compareTo(a.value)))
              .take(5)
              .toList();

      if (top5.isNotEmpty) {
        out
          ..add(_sectionHeader(
              strings['pdfDailyTrend'] ?? '일별 지출 추이 (Top 5 지출일)', ts))
          ..add(pw.SizedBox(height: 8));
        final int topAmt = top5.first.value;
        for (int i = 0; i < top5.length; i++) {
          final int amt = top5[i].value;
          final int pctInt =
              (topAmt > 0 ? amt / topAmt * 100 : 0).round().clamp(1, 99);
          out.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(
              children: <pw.Widget>[
                // 날짜는 숫자/슬래시 → ts
                pw.SizedBox(
                    width: 44,
                    child: pw.Text(top5[i].key, style: ts(size: 9))),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Row(
                    children: <pw.Widget>[
                      pw.Expanded(
                          flex: pctInt,
                          child: pw.Container(height: 12, color: _kBlue)),
                      pw.Expanded(
                          flex: 100 - pctInt,
                          child:
                              pw.Container(height: 12, color: _kLightGrey)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.SizedBox(
                  width: 80,
                  child: pw.Text('$currency${_fmtAmount(amt)}',
                      style: ts(size: 9),
                      textAlign: pw.TextAlign.right),
                ),
              ],
            ),
          ));
        }
      }
    }

    return out;
  }

  // ─── Top 10 섹션 ─────────────────────────────────────────────────

  List<pw.Widget> _buildTop10Widgets({
    required List<ExpenseEntry> top10,
    required String currency,
    required String Function(MetadataTagType, String) tagLabel,
    required Map<String, String> strings,
    required _TsFn ts,
    required _TsFn tsD,
  }) =>
      <pw.Widget>[
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
              .map((MapEntry<int, ExpenseEntry> e) => <String>[
                    '${e.key + 1}',
                    DateFormat('yyyy/MM/dd').format(e.value.spentAt),
                    tagLabel(MetadataTagType.category, e.value.categoryCode),
                    e.value.description,
                    '$currency${_fmtAmount(e.value.amount)}',
                  ])
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

    for (final ExpenseEntry e in (List<ExpenseEntry>.from(expenses)
      ..sort((ExpenseEntry a, ExpenseEntry b) =>
          b.spentAt.compareTo(a.spentAt)))) {
      rows.add(<String>[
        DateFormat('yyyy/MM/dd').format(e.spentAt),
        strings['pdfTypeExpense'] ?? '지출',
        tagLabel(MetadataTagType.category, e.categoryCode),
        e.description,
        '-$currency${_fmtAmount(e.amount)}',
      ]);
    }
    for (final IncomeEntry i in (List<IncomeEntry>.from(incomes)
      ..sort((IncomeEntry a, IncomeEntry b) =>
          b.earnedAt.compareTo(a.earnedAt)))) {
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
          strings['pdfSectionAllTransactions'] ?? '전체 거래내역 (부록)', ts),
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
          cellAlignments: <int, pw.Alignment>{
            4: pw.Alignment.centerRight,
          },
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
  pw.Widget _summaryBox(
    String label,
    String value,
    PdfColor color,
    _TsFn ts,
  ) =>
      pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1.5),
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(6)),
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
          child: pw.Text(label,
              style: tsD(size: 9), overflow: pw.TextOverflow.clip),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Row(
            children: <pw.Widget>[
              pw.Expanded(
                  flex: filled,
                  child: pw.Container(height: 10, color: barColor)),
              pw.Expanded(
                  flex: empty,
                  child: pw.Container(height: 10, color: _kLightGrey)),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.SizedBox(
            width: 28,
            child: pw.Text('${pct.round()}%',
                style: ts(size: 9), textAlign: pw.TextAlign.right)),
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 80,
          child: pw.Text('$currency${_fmtAmount(amount)}',
              style: ts(size: 9, bold: true),
              textAlign: pw.TextAlign.right),
        ),
      ],
    );
  }
}
