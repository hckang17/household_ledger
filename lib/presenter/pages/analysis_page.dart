import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_daily_chart.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_donut_chart.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:intl/intl.dart';

/// 고정지출 섹션을 도넛 차트에서 구분하기 위한 내부 카테고리 코드다.
const String _kFixedCode = '__fixed__';

/// 도넛 차트에서 고정지출 섹션에 항상 사용하는 어두운 색상이다.
const Color _kFixedColor = Color(0xFF37474F);

/// 기간 선택 모드를 정의한다.
enum _PeriodMode {
  /// 월 단위로 기간을 선택한다.
  monthly,

  /// 날짜 범위를 직접 지정한다.
  range,
}

/// 지출 분석 화면이다.
///
/// 상단의 기간 선택 영역, 카테고리별 도넛 차트(고정지출 포함),
/// 카테고리 목록, 고정지출 가로 막대 그래프, 일별 지출 추이 꺾은선 그래프를
/// 통합하여 제공한다.
class AnalysisPage extends ConsumerStatefulWidget {
  /// 지출 분석 화면을 생성한다.
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  /// 현재 선택된 월이다(월간 모드에서 사용).
  late DateTime _selectedMonth;

  /// 날짜 범위 선택 모드에서 선택된 기간이다.
  DateTimeRange? _selectedRange;

  /// 기간 선택 모드를 보관한다.
  _PeriodMode _periodMode = _PeriodMode.monthly;

  /// 현재 터치된 도넛 섹션 인덱스다(-1이면 선택 없음).
  int _touchedIndex = -1;

  /// 지출/수입 탭 상태를 보관한다(true = 지출, false = 수입).
  bool _showExpense = true;

  /// 고정지출 가로 막대 섹션의 위치를 추적하는 키다.
  /// 도넛에서 고정지출을 탭할 때 이 위치로 스크롤한다.
  final GlobalKey _fixedSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  // ─── 로케일 헬퍼 ───────────────────────────────────────────────

  String _text(
    Map<String, String> strings,
    String key, [
    String fallback = '',
  ]) {
    return strings[key] ?? fallback;
  }

  String _intlLocale(String localeCode) {
    return localeCode == 'jp' ? 'ja' : 'ko';
  }

  String _formatMonth(String localeCode, DateTime month) {
    return DateFormat.yMMMM(_intlLocale(localeCode)).format(month);
  }

  String _formatRange(String localeCode, DateTimeRange range) {
    final DateFormat fmt = DateFormat('MM.dd', _intlLocale(localeCode));
    return '${fmt.format(range.start)} - ${fmt.format(range.end)}';
  }

  /// 월의 마지막 날을 반환한다.
  int _lastDayOfMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  /// 월간 모드의 기간 표시 문자열을 반환한다("MM.01 - MM.DD" 형식).
  String _monthRangeLabel(DateTime month) {
    final String mm = month.month.toString().padLeft(2, '0');
    final String dd = _lastDayOfMonth(month).toString().padLeft(2, '0');
    return '$mm.01 - $mm.$dd';
  }

  // ─── 기간 내비게이션 ─────────────────────────────────────────────

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
      _touchedIndex = -1;
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );
      _touchedIndex = -1;
    });
  }

  Future<void> _pickMonth(
    BuildContext context,
    Map<String, String> strings,
  ) async {
    final DateTime now = DateTime.now();
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;

    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _text(strings, 'selectMonth', '달 선택'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedYear,
                            decoration: InputDecoration(
                              labelText: _text(strings, 'yearLabel', '연도'),
                            ),
                            items: List<DropdownMenuItem<int>>.generate(11, (
                              int i,
                            ) {
                              final int y = now.year - 5 + i;
                              return DropdownMenuItem<int>(
                                value: y,
                                child: Text('$y'),
                              );
                            }),
                            onChanged: (int? v) {
                              if (v != null) setModal(() => selectedYear = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedMonth,
                            decoration: InputDecoration(
                              labelText: _text(strings, 'monthLabel', '월'),
                            ),
                            items: List<DropdownMenuItem<int>>.generate(
                              12,
                              (int i) => DropdownMenuItem<int>(
                                value: i + 1,
                                child: Text('${i + 1}'),
                              ),
                            ),
                            onChanged: (int? v) {
                              if (v != null) setModal(() => selectedMonth = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(_text(strings, 'cancel', '취소')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(DateTime(selectedYear, selectedMonth)),
                          child: Text(_text(strings, 'apply', '적용')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
        _touchedIndex = -1;
      });
    }
  }

  Future<void> _pickDateRange(
    BuildContext context,
    Map<String, String> strings,
    String localeCode,
  ) async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      locale: Locale(_intlLocale(localeCode)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: _selectedRange,
      helpText: _text(strings, 'selectDateRange', '기간 선택'),
      cancelText: _text(strings, 'cancel', '취소'),
      saveText: _text(strings, 'apply', '적용'),
    );
    if (picked != null) {
      setState(() {
        _selectedRange = DateTimeRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        );
        _touchedIndex = -1;
      });
    }
  }

  Future<void> _showPeriodModeMenu(
    BuildContext context,
    Map<String, String> strings,
  ) async {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );
    final RelativeRect position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy,
      overlay.size.width - offset.dx - button.size.width,
      0,
    );

    final String? selected = await showMenu<String>(
      context: context,
      position: position,
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'monthly',
          child: Text(_text(strings, 'analysisPeriodMonthly', '월간')),
        ),
        PopupMenuItem<String>(
          value: 'range',
          child: Text(_text(strings, 'analysisPeriodRange', '기간')),
        ),
      ],
    );
    if (selected == null) return;

    setState(() {
      _periodMode =
          selected == 'monthly' ? _PeriodMode.monthly : _PeriodMode.range;
      _selectedRange = null;
      _touchedIndex = -1;
    });
  }

  // ─── 스크롤 ────────────────────────────────────────────────────

  /// 고정지출 가로 막대 섹션으로 부드럽게 스크롤한다.
  ///
  /// 섹션이 렌더링되어 있지 않으면(기간 모드이거나 데이터 없음) 아무것도 하지 않는다.
  void _scrollToFixedSection() {
    final BuildContext? ctx = _fixedSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  // ─── 데이터 계산 ──────────────────────────────────────────────────

  String _resolveTagLabel(List<MetadataTag> tags, String code) {
    try {
      return tags.firstWhere((MetadataTag t) => t.code == code).label;
    } catch (_) {
      return code;
    }
  }

  /// 지출 목록과 고정지출 목록을 카테고리별로 집계해 도넛 섹션 목록을 만든다.
  ///
  /// 고정지출은 [_kFixedCode] 코드로 하나의 섹션으로 합산되며
  /// [_kFixedColor](어두운 색)을 고정 사용한다.
  List<DonutSection> _buildDonutSections(
    List<ExpenseEntry> expenses,
    List<MetadataTag> categoryTags,
    List<FixedExpense> fixedExpenses,
    Map<String, String> strings,
  ) {
    final Map<String, int> sums = <String, int>{};

    for (final ExpenseEntry e in expenses) {
      sums.update(
        e.categoryCode,
        (int v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
    }

    /// 고정지출을 단일 섹션으로 합산해 도넛에 포함한다.
    if (fixedExpenses.isNotEmpty) {
      final int fixedTotal =
          fixedExpenses.fold(0, (int s, FixedExpense f) => s + f.amount);
      if (fixedTotal > 0) sums[_kFixedCode] = fixedTotal;
    }

    final int total = sums.values.fold(0, (int a, int b) => a + b);
    if (total == 0) return <DonutSection>[];

    final List<MapEntry<String, int>> sorted = sums.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );

    /// 일반 카테고리의 팔레트 인덱스를 고정지출과 독립적으로 증가시킨다.
    int colorIndex = 0;
    return sorted.map((MapEntry<String, int> entry) {
      final String code = entry.key;
      final bool isFixed = code == _kFixedCode;
      final String label = isFixed
          ? _text(strings, 'fixedExpenseCategoryLabel', '고정지출')
          : _resolveTagLabel(categoryTags, code);
      final Color color = isFixed
          ? _kFixedColor
          : kDonutSectionColors[colorIndex++ % kDonutSectionColors.length];
      return DonutSection(
        categoryCode: code,
        label: label,
        amount: entry.value,
        percentage: entry.value / total * 100,
        color: color,
      );
    }).toList();
  }

  /// 지출 목록을 일 단위로 집계해 꺾은선 그래프 점 목록을 만든다.
  List<FlSpot> _buildDailyExpenseSpots(
    List<ExpenseEntry> expenses,
    DateTime rangeStart,
  ) {
    if (expenses.isEmpty) return <FlSpot>[];

    final DateTime base = DateTime(
      rangeStart.year,
      rangeStart.month,
      rangeStart.day,
    );
    final Map<int, int> daily = <int, int>{};
    for (final ExpenseEntry e in expenses) {
      final int offset =
          DateTime(
            e.spentAt.year,
            e.spentAt.month,
            e.spentAt.day,
          ).difference(base).inDays +
          1;
      if (offset < 1) continue;
      daily.update(offset, (int v) => v + e.amount, ifAbsent: () => e.amount);
    }

    if (daily.isEmpty) return <FlSpot>[];
    final List<int> sorted = daily.keys.toList()..sort();
    return sorted
        .map((int k) => FlSpot(k.toDouble(), daily[k]!.toDouble()))
        .toList();
  }

  /// 수입 목록을 일 단위로 집계해 꺾은선 그래프 점 목록을 만든다.
  List<FlSpot> _buildDailyIncomeSpots(
    List<IncomeEntry> incomes,
    DateTime rangeStart,
  ) {
    if (incomes.isEmpty) return <FlSpot>[];

    final DateTime base = DateTime(
      rangeStart.year,
      rangeStart.month,
      rangeStart.day,
    );
    final Map<int, int> daily = <int, int>{};
    for (final IncomeEntry e in incomes) {
      final int offset =
          DateTime(
            e.earnedAt.year,
            e.earnedAt.month,
            e.earnedAt.day,
          ).difference(base).inDays +
          1;
      if (offset < 1) continue;
      daily.update(offset, (int v) => v + e.amount, ifAbsent: () => e.amount);
    }

    if (daily.isEmpty) return <FlSpot>[];
    final List<int> sorted = daily.keys.toList()..sort();
    return sorted
        .map((int k) => FlSpot(k.toDouble(), daily[k]!.toDouble()))
        .toList();
  }

  // ─── 카테고리 상세 바텀시트 ────────────────────────────────────────

  /// 선택된 카테고리의 지출 내역을 바텀시트로 표시한다.
  void _showCategoryDetail(
    BuildContext context,
    DonutSection section,
    List<ExpenseEntry> expenses,
    Map<String, String> strings,
    String currency,
  ) {
    final List<ExpenseEntry> filtered =
        expenses
            .where((ExpenseEntry e) => e.categoryCode == section.categoryCode)
            .toList()
          ..sort(
            (ExpenseEntry a, ExpenseEntry b) => b.spentAt.compareTo(a.spentAt),
          );

    final String detailTitle = _text(
      strings,
      'analysisCategoryDetailTitle',
      '{label} 상세',
    ).replaceAll('{label}', section.label);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (BuildContext ctx2, ScrollController controller) {
            return SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Row(
                            children: <Widget>[
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: section.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  detailTitle,
                                  style: Theme.of(
                                    ctx2,
                                  ).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: <Widget>[
                              Text(
                                '${section.percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: section.color,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${section.amount.toCurrency()}$currency',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${filtered.length}${_text(strings, 'entryCountUnit', '건')}',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                _text(
                                  strings,
                                  'emptyData',
                                  '아직 입력된 데이터가 없습니다.',
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: controller,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              itemBuilder: (BuildContext ctx3, int index) {
                                final ExpenseEntry item = filtered[index];
                                return ListTile(
                                  dense: true,
                                  leading: Text(
                                    DateFormat('MM/dd').format(item.spentAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  title: Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    '${item.amount.toCurrency()}$currency',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFFDC3545),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ), // Container
            ); // SafeArea
          },
        );
      },
    );
  }

  // ─── 빌드 헬퍼 위젯 ───────────────────────────────────────────────

  Widget _buildPeriodHeader(
    BuildContext context,
    Map<String, String> strings,
    String localeCode,
  ) {
    final String modeLabel = _periodMode == _PeriodMode.monthly
        ? _text(strings, 'analysisPeriodMonthly', '월간')
        : _text(strings, 'analysisPeriodRange', '기간');

    return Row(
      children: <Widget>[
        Builder(
          builder: (BuildContext btnCtx) {
            return GestureDetector(
              onTap: () => _showPeriodModeMenu(btnCtx, strings),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      modeLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _periodMode == _PeriodMode.monthly
              ? _buildMonthNavRow(context, strings)
              : _buildRangeNavRow(context, strings, localeCode),
        ),
      ],
    );
  }

  Widget _buildMonthNavRow(BuildContext context, Map<String, String> strings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          onPressed: _prevMonth,
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
          splashRadius: 20,
        ),
        GestureDetector(
          onTap: () => _pickMonth(context, strings),
          child: Text(
            _monthRangeLabel(_selectedMonth),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        IconButton(
          onPressed: _nextMonth,
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _buildRangeNavRow(
    BuildContext context,
    Map<String, String> strings,
    String localeCode,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _pickDateRange(context, strings, localeCode),
            icon: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(
              _selectedRange == null
                  ? _text(strings, 'selectDateRange', '기간 선택')
                  : _formatRange(localeCode, _selectedRange!),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        if (_selectedRange != null) ...<Widget>[
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => setState(() {
              _selectedRange = null;
              _touchedIndex = -1;
            }),
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: _text(strings, 'clearSelection', '선택 초기화'),
          ),
        ],
      ],
    );
  }

  /// 카테고리별 지출 비율을 한 행으로 표시하는 위젯이다.
  ///
  /// 색상 점 | 카테고리명 | 비율 | 금액 | > 버튼 구성이다.
  Widget _buildCategoryRow({
    required BuildContext context,
    required DonutSection section,
    required String currency,
    required VoidCallback onDetailTap,
    required VoidCallback onRowTap,
  }) {
    return GestureDetector(
      onTap: onRowTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: section.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Text(
                section.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${section.percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: section.color,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${section.amount.toCurrency()}$currency',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),

            /// 상세 보기 버튼(>)이다.
            /// 고정지출이면 아래 막대그래프 섹션으로 스크롤, 그 외엔 내역 바텀시트를 연다.
            IconButton(
              onPressed: onDetailTap,
              icon: const Icon(Icons.chevron_right, size: 20),
              visualDensity: VisualDensity.compact,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  /// 고정지출 항목을 가로 막대 그래프로 페이지에 직접 표시하는 카드다.
  ///
  /// 카테고리 목록 바로 아래에 배치되며 월간 모드에서만 표시된다.
  /// 제목 옆에는 전체 지출 대비 고정지출의 비율을 함께 표시한다.
  Widget _buildFixedExpenseBarSection({
    required List<FixedExpense> items,
    required String currency,
    required Map<String, String> strings,
    required int totalAmount,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final int maxAmount = items
        .map((FixedExpense f) => f.amount)
        .reduce((int a, int b) => a > b ? a : b);
    final int fixedTotal = items.fold(0, (int s, FixedExpense f) => s + f.amount);
    final double fixedPercentage =
        totalAmount > 0 ? fixedTotal / totalAmount * 100 : 0.0;

    return BootstrapSectionCard(
      key: _fixedSectionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          /// 고정지출 섹션 제목 + 전체 대비 비율 + 합계 금액이다.
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _text(
                    strings,
                    'analysisFixedExpenseSectionTitle',
                    '이번 달 고정지출',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${fixedPercentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _kFixedColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${fixedTotal.toCurrency()}$currency',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF0D6EFD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          /// 고정지출 항목별 가로 막대 그래프 목록이다.
          ...items.asMap().entries.map((MapEntry<int, FixedExpense> entry) {
            final FixedExpense item = entry.value;
            final double ratio =
                maxAmount > 0 ? item.amount / maxAmount : 0.0;
            final Color barColor =
                kDonutSectionColors[entry.key % kDonutSectionColors.length];

            /// 항목명 + 금액 + 가로 막대 한 행이다.
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${item.amount.toCurrency()}$currency',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  /// 금액 비율을 나타내는 가로 막대 인디케이터다.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 12,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 메인 빌드 ────────────────────────────────────────────────────

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

    // ── 활성 기간 결정 ──
    final bool usingRange =
        _periodMode == _PeriodMode.range && _selectedRange != null;

    final ExpenseRangeQuery? rangeQuery = usingRange
        ? ExpenseRangeQuery(
            start: _selectedRange!.start,
            endInclusive: _selectedRange!.end,
          )
        : null;

    // ── 지출 데이터 로드 ──
    final AsyncValue<List<ExpenseEntry>> expensesAsync = usingRange
        ? ref.watch(rangeExpensesProvider(rangeQuery!))
        : ref.watch(monthlyExpensesProvider(_selectedMonth));

    // ── 수입 데이터 로드 ──
    final AsyncValue<List<IncomeEntry>> incomesAsync = ref.watch(
      monthlyIncomesProvider(_selectedMonth),
    );

    // ── 이달 고정지출(월간 모드에서만 표시) ──
    final List<FixedExpense> monthlyFixed = ledger.fixedExpenses
        .where(
          (FixedExpense f) =>
              f.appliedAt.year == _selectedMonth.year &&
              f.appliedAt.month == _selectedMonth.month,
        )
        .toList();

    // ── 기간 표시 문자열 ──
    final String periodSubtitle = usingRange
        ? _formatRange(localeCode, _selectedRange!)
        : _formatMonth(localeCode, _selectedMonth);

    // ── 차트 시작 날짜 ──
    final DateTime chartRangeStart =
        usingRange ? _selectedRange!.start : _selectedMonth;

    return BootstrapPage(
      title: _text(strings, 'analysis', '지출 분석'),
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            /// ── 상단 컨트롤 카드 ──
            BootstrapSectionCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: <Widget>[
                  /// 지출/수입 탭 전환 SegmentedButton이다.
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      expandedInsets: EdgeInsets.zero,
                      selected: <bool>{_showExpense},
                      segments: <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: true,
                          label: Text(
                            _text(strings, 'analysisTabExpense', '지출'),
                          ),
                          icon: const Icon(Icons.trending_down_rounded),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text(
                            _text(strings, 'analysisTabIncome', '수입'),
                          ),
                          icon: const Icon(Icons.trending_up_rounded),
                        ),
                      ],
                      onSelectionChanged: (Set<bool> val) {
                        setState(() {
                          _showExpense = val.first;
                          _touchedIndex = -1;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildPeriodHeader(context, strings, localeCode),
                  const SizedBox(height: 4),
                  Text(
                    periodSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─────────────────────────────────────────
            // 지출 탭 내용이다.
            // ─────────────────────────────────────────
            if (_showExpense)
              expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => Center(child: Text(e.toString())),
                data: (List<ExpenseEntry> expenses) {
                  final List<DonutSection> sections = _buildDonutSections(
                    expenses,
                    categoryTags,
                    !usingRange ? monthlyFixed : const <FixedExpense>[],
                    strings,
                  );

                  /// 도넛 총계 = 일반 지출 + 고정지출
                  final int expenseTotal = expenses.fold(
                    0,
                    (int s, ExpenseEntry e) => s + e.amount,
                  );
                  final int fixedTotal = !usingRange
                      ? monthlyFixed.fold(
                          0,
                          (int s, FixedExpense f) => s + f.amount,
                        )
                      : 0;
                  final int totalAmount = expenseTotal + fixedTotal;

                  final List<FlSpot> dailySpots = _buildDailyExpenseSpots(
                    expenses,
                    chartRangeStart,
                  );

                  return Column(
                    children: <Widget>[
                      /// ── 도넛 차트 카드 ──
                      /// 카테고리별 지출 비율과 고정지출을 도넛 그래프로 시각화한다.
                      /// 고정지출 섹션을 탭하면 아래의 막대그래프 섹션으로 스크롤된다.
                      BootstrapSectionCard(
                        child: Column(
                          children: <Widget>[
                            AnalysisDonutChart(
                              sections: sections,
                              touchedIndex: _touchedIndex,
                              onTouchUpdate: (int index) {
                                setState(() => _touchedIndex = index);
                              },
                              /// 고정지출 섹션을 탭하면 막대그래프 카드로 스크롤한다.
                              onSectionTap: (int index) {
                                if (index >= 0 &&
                                    index < sections.length &&
                                    sections[index].categoryCode ==
                                        _kFixedCode) {
                                  _scrollToFixedSection();
                                }
                              },
                              totalLabel: _text(
                                strings,
                                'analysisTotalLabel',
                                '전체',
                              ),
                              totalAmount:
                                  '${totalAmount.toCurrency()}$currency',
                              currency: currency,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  _text(strings, 'analysisTotalLabel', '전체'),
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${totalAmount.toCurrency()}$currency',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// ── 카테고리 목록 카드 ──
                      /// 고정지출 행의 ">" 탭은 바텀시트 대신 막대그래프 카드로 스크롤한다.
                      if (sections.isNotEmpty)
                        BootstrapSectionCard(
                          child: Column(
                            children: <Widget>[
                              ...sections.asMap().entries.map((
                                MapEntry<int, DonutSection> entry,
                              ) {
                                final bool isFixed =
                                    entry.value.categoryCode == _kFixedCode;
                                return Column(
                                  children: <Widget>[
                                    _buildCategoryRow(
                                      context: context,
                                      section: entry.value,
                                      currency: currency,
                                      onRowTap: () {
                                        setState(
                                          () => _touchedIndex =
                                              _touchedIndex == entry.key
                                              ? -1
                                              : entry.key,
                                        );
                                        /// 고정지출 행 탭 시 막대그래프 카드로 스크롤한다.
                                        if (isFixed) _scrollToFixedSection();
                                      },
                                      onDetailTap: () {
                                        if (isFixed) {
                                          _scrollToFixedSection();
                                        } else {
                                          _showCategoryDetail(
                                            context,
                                            entry.value,
                                            expenses,
                                            strings,
                                            currency,
                                          );
                                        }
                                      },
                                    ),
                                    if (entry.key < sections.length - 1)
                                      const Divider(height: 1),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      if (sections.isNotEmpty) const SizedBox(height: 16),

                      /// ── 고정지출 가로 막대 그래프 카드 ──
                      /// 카테고리 목록 바로 아래에 위치하며 월간 모드에서만 표시된다.
                      /// 제목 옆에 전체 대비 비율(%)을 함께 표시한다.
                      if (!usingRange)
                        _buildFixedExpenseBarSection(
                          items: monthlyFixed,
                          currency: currency,
                          strings: strings,
                          totalAmount: totalAmount,
                        ),
                      if (!usingRange && monthlyFixed.isNotEmpty)
                        const SizedBox(height: 16),

                      /// ── 일별 지출 추이 카드 ──
                      if (dailySpots.isNotEmpty)
                        BootstrapSectionCard(
                          child: AnalysisDailyChart(
                            spots: dailySpots,
                            currency: currency,
                            title: _text(
                              strings,
                              'analysisDailyTrendTitle',
                              '일별 지출 추이',
                            ),
                            rangeStart: chartRangeStart,
                            maxLabel: _text(
                              strings,
                              'analysisDailyMaxLabel',
                              '가장 지출이 많은 날',
                            ),
                            minLabel: _text(
                              strings,
                              'analysisDailyMinLabel',
                              '가장 지출이 적은 날',
                            ),
                          ),
                        ),
                      if (dailySpots.isNotEmpty) const SizedBox(height: 16),

                      if (sections.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              _text(strings, 'emptyData', '아직 입력된 데이터가 없습니다.'),
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

            // ─────────────────────────────────────────
            // 수입 탭 내용이다.
            // ─────────────────────────────────────────
            if (!_showExpense)
              incomesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, _) => Center(child: Text(e.toString())),
                data: (List<IncomeEntry> incomes) {
                  final int incomeTotal = incomes.fold(
                    0,
                    (int s, IncomeEntry e) => s + e.amount,
                  );
                  final List<FlSpot> incomeSpots = _buildDailyIncomeSpots(
                    incomes,
                    chartRangeStart,
                  );

                  return Column(
                    children: <Widget>[
                      BootstrapSectionCard(
                        child: BootstrapSummaryTile(
                          label: _text(strings, 'analysisIncomeTotal', '수입 합계'),
                          value: '${incomeTotal.toCurrency()}$currency',
                          color: const Color(0xFF198754),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (incomes.isNotEmpty)
                        BootstrapSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _text(strings, 'incomeTotal', '수입 내역'),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              ...incomes.map((IncomeEntry item) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 7,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Text(
                                        DateFormat('MM/dd').format(
                                          item.earnedAt,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item.description,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${item.amount.toCurrency()}$currency',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF198754),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      if (incomes.isNotEmpty) const SizedBox(height: 16),
                      if (incomeSpots.isNotEmpty)
                        BootstrapSectionCard(
                          child: AnalysisDailyChart(
                            spots: incomeSpots,
                            currency: currency,
                            title: _text(
                              strings,
                              'analysisIncomeDailyTrendTitle',
                              '일별 수입 추이',
                            ),
                            rangeStart: chartRangeStart,
                          ),
                        ),
                      if (incomeSpots.isNotEmpty) const SizedBox(height: 16),
                      if (incomes.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              _text(strings, 'emptyData', '아직 입력된 데이터가 없습니다.'),
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
