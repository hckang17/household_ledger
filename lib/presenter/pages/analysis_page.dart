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

/// 기간 선택 모드를 정의한다.
enum _PeriodMode {
  /// 월 단위로 기간을 선택한다.
  monthly,

  /// 날짜 범위를 직접 지정한다.
  range,
}

/// 지출 분석 화면이다.
///
/// 상단의 기간 선택 영역, 카테고리별 도넛 차트, 카테고리 목록,
/// 일별 지출 추이 꺾은선 그래프를 통합하여 제공한다.
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

  /// 이전 달로 이동한다.
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

  /// 다음 달로 이동한다.
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

  /// 월 선택 바텀시트를 표시한다.
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
                              if (v != null) {
                                setModal(() => selectedYear = v);
                              }
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
                              if (v != null) {
                                setModal(() => selectedMonth = v);
                              }
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

  /// 날짜 범위 선택 다이얼로그를 표시한다.
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

  /// 기간 선택 모드 메뉴(월간/기간)를 보여준다.
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
      _periodMode = selected == 'monthly'
          ? _PeriodMode.monthly
          : _PeriodMode.range;
      _selectedRange = null;
      _touchedIndex = -1;
    });
  }

  // ─── 데이터 계산 ──────────────────────────────────────────────────

  /// 태그 코드에 해당하는 태그 라벨을 반환한다.
  String _resolveTagLabel(List<MetadataTag> tags, String code) {
    try {
      return tags.firstWhere((MetadataTag t) => t.code == code).label;
    } catch (_) {
      return code;
    }
  }

  /// 지출 목록을 카테고리별로 집계해 도넛 섹션 목록을 만든다.
  List<DonutSection> _buildDonutSections(
    List<ExpenseEntry> expenses,
    List<MetadataTag> categoryTags,
  ) {
    if (expenses.isEmpty) return <DonutSection>[];

    final Map<String, int> sums = <String, int>{};
    for (final ExpenseEntry e in expenses) {
      sums.update(
        e.categoryCode,
        (int v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
    }

    final int total = sums.values.fold(0, (int a, int b) => a + b);
    if (total == 0) return <DonutSection>[];

    final List<MapEntry<String, int>> sorted = sums.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );

    return sorted.asMap().entries.map((MapEntry<int, MapEntry<String, int>> e) {
      return DonutSection(
        categoryCode: e.value.key,
        label: _resolveTagLabel(categoryTags, e.value.key),
        amount: e.value.value,
        percentage: e.value.value / total * 100,
        color: kDonutSectionColors[e.key % kDonutSectionColors.length],
      );
    }).toList();
  }

  /// 지출 목록을 일 단위로 집계해 꺾은선 그래프 점 목록을 만든다.
  ///
  /// [rangeStart]를 기준으로 상대 일수(1-based)를 X축 값으로 사용한다.
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
  ///
  /// 날짜·내용·금액을 목록 형태로 보여준다.
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
                    /// 카테고리 상세 바텀시트의 헤더 영역이다.
                    /// 카테고리 이름, 비율, 합계 금액을 표시한다.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          /// 드래그 핸들이다.
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
                              /// 카테고리 색상 인디케이터 점이다.
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
                                  style: Theme.of(ctx2).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          /// 카테고리 비율 및 합계 금액 요약 행이다.
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

                    /// 카테고리 내 지출 내역 목록이다. 날짜 내림차순으로 정렬된다.
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

                                /// 각 지출 항목 타일이다(날짜 | 내용 | 금액).
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

  /// 기간 선택 모드(월간/기간)와 날짜 내비게이션을 담은 헤더 행이다.
  ///
  /// "월간 ▼" 드롭다운과 "< MM.01 - MM.DD >" 내비게이션으로 구성된다.
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
        /// 기간 모드 선택 버튼이다(월간 ▼ 형태).
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

        /// 날짜 내비게이션 영역이다.
        /// 월간 모드: 이전/다음 달 화살표 + 월 탭.
        /// 기간 모드: 날짜 범위 선택 버튼.
        Expanded(
          child: _periodMode == _PeriodMode.monthly
              ? _buildMonthNavRow(context, strings)
              : _buildRangeNavRow(context, strings, localeCode),
        ),
      ],
    );
  }

  /// 월간 모드의 < MM.01 - MM.DD > 내비게이션 행이다.
  Widget _buildMonthNavRow(BuildContext context, Map<String, String> strings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        /// 이전 달 이동 버튼이다.
        IconButton(
          onPressed: _prevMonth,
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
          splashRadius: 20,
        ),

        /// 월 범위 텍스트다. 탭하면 월 선택 바텀시트가 열린다.
        GestureDetector(
          onTap: () => _pickMonth(context, strings),
          child: Text(
            _monthRangeLabel(_selectedMonth),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),

        /// 다음 달 이동 버튼이다.
        IconButton(
          onPressed: _nextMonth,
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
          splashRadius: 20,
        ),
      ],
    );
  }

  /// 기간 모드의 날짜 범위 선택 버튼 행이다.
  Widget _buildRangeNavRow(
    BuildContext context,
    Map<String, String> strings,
    String localeCode,
  ) {
    return Row(
      children: <Widget>[
        /// 날짜 범위 선택 버튼이다.
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

          /// 기간 선택 초기화 버튼이다.
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
  /// ">" 버튼을 탭하면 [onDetailTap]이 호출된다.
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
            /// 카테고리 색상 인디케이터 점이다.
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: section.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),

            /// 카테고리 이름이다.
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

            /// 카테고리 비율(%)이다.
            Text(
              '${section.percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: section.color,
              ),
            ),
            const SizedBox(width: 12),

            /// 카테고리 합계 금액이다.
            Text(
              '${section.amount.toCurrency()}$currency',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),

            /// 상세 보기 버튼(>)이다.
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

  /// 이달의 고정지출 목록을 요약 카드로 표시하는 영역이다.
  Widget _buildFixedExpenseSection({
    required BuildContext context,
    required List<FixedExpense> items,
    required Map<String, String> strings,
    required String currency,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final int total = items.fold(0, (int s, FixedExpense e) => s + e.amount);

    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          /// 고정지출 섹션 제목이다.
          Text(
            _text(strings, 'analysisFixedExpenseSectionTitle', '이번 달 고정지출'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          /// 고정지출 개별 항목 행이다.
          ...items.map((FixedExpense item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
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
                      fontSize: 13,
                      color: Color(0xFF0D6EFD),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 20),

          /// 고정지출 합계 행이다.
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _text(strings, 'fixedExpenseTotal', '고정지출 합계'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${total.toCurrency()}$currency',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF0D6EFD),
                ),
              ),
            ],
          ),
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

    // ── 수입 데이터 로드(월간 모드에서만) ──
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
    final DateTime chartRangeStart = usingRange
        ? _selectedRange!.start
        : _selectedMonth;

    return BootstrapPage(
      title: _text(strings, 'analysis', '지출 분석'),
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            /// ── 상단 컨트롤 카드 ──
            /// 지출/수입 탭 전환과 기간 선택 내비게이션을 포함한다.
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

                  /// 기간 모드 선택과 날짜 내비게이션이다.
                  _buildPeriodHeader(context, strings, localeCode),
                  const SizedBox(height: 4),

                  /// 현재 분석 기간을 텍스트로 요약해 보여준다.
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
                  );
                  final int totalAmount = expenses.fold(
                    0,
                    (int s, ExpenseEntry e) => s + e.amount,
                  );
                  final List<FlSpot> dailySpots = _buildDailyExpenseSpots(
                    expenses,
                    chartRangeStart,
                  );

                  return Column(
                    children: <Widget>[
                      /// ── 도넛 차트 카드 ──
                      /// 카테고리별 지출 비율을 도넛 그래프로 시각화한다.
                      BootstrapSectionCard(
                        child: Column(
                          children: <Widget>[
                            /// 카테고리별 지출 비율 도넛 그래프다.
                            AnalysisDonutChart(
                              sections: sections,
                              touchedIndex: _touchedIndex,
                              onTouchUpdate: (int index) {
                                setState(() => _touchedIndex = index);
                              },
                              totalLabel: _text(
                                strings,
                                'analysisTotalLabel',
                                '전체',
                              ),
                              totalAmount:
                                  '${totalAmount.toCurrency()}$currency',
                            ),
                            const SizedBox(height: 8),

                            /// 전체 지출 합계 요약 행이다.
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
                      /// 도넛 그래프 섹션과 1:1 대응되는 카테고리 항목 목록이다.
                      /// 각 행의 ">" 버튼을 탭하면 해당 카테고리 지출 내역 상세가 열린다.
                      if (sections.isNotEmpty)
                        BootstrapSectionCard(
                          child: Column(
                            children: <Widget>[
                              ...sections.asMap().entries.map((
                                MapEntry<int, DonutSection> entry,
                              ) {
                                return Column(
                                  children: <Widget>[
                                    /// 카테고리별 한 행이다(색상 점·이름·%·금액·>).
                                    _buildCategoryRow(
                                      context: context,
                                      section: entry.value,
                                      currency: currency,

                                      /// 행 탭 시 해당 섹션을 도넛 차트에서 선택 상태로 전환한다.
                                      onRowTap: () => setState(
                                        () => _touchedIndex =
                                            _touchedIndex == entry.key
                                            ? -1
                                            : entry.key,
                                      ),

                                      /// ">" 버튼 탭 시 카테고리 상세 바텀시트를 연다.
                                      onDetailTap: () => _showCategoryDetail(
                                        context,
                                        entry.value,
                                        expenses,
                                        strings,
                                        currency,
                                      ),
                                    ),
                                    if (entry.key < sections.length - 1)
                                      const Divider(height: 1),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      /// ── 이달 고정지출 카드 ──
                      /// 월간 모드에서만 이달 고정지출 항목을 요약해 표시한다.
                      if (!usingRange)
                        _buildFixedExpenseSection(
                          context: context,
                          items: monthlyFixed,
                          strings: strings,
                          currency: currency,
                        ),
                      if (!usingRange && monthlyFixed.isNotEmpty)
                        const SizedBox(height: 16),

                      /// ── 일별 지출 추이 카드 ──
                      /// 선택 기간 내 날짜별 지출 합계를 꺾은선 그래프로 보여준다.
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
                          ),
                        ),
                      if (dailySpots.isNotEmpty) const SizedBox(height: 16),

                      /// 데이터가 없을 때 표시하는 빈 상태 메시지다.
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
                      /// 수입 합계 요약 카드다.
                      BootstrapSectionCard(
                        child: BootstrapSummaryTile(
                          label: _text(strings, 'analysisIncomeTotal', '수입 합계'),
                          value: '${incomeTotal.toCurrency()}$currency',
                          color: const Color(0xFF198754),
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// 수입 내역 목록 카드다.
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

                              /// 수입 개별 항목 행이다(날짜 | 내용 | 금액).
                              ...incomes.map((IncomeEntry item) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 7,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Text(
                                        DateFormat(
                                          'MM/dd',
                                        ).format(item.earnedAt),
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

                      /// 일별 수입 추이 꺾은선 그래프 카드다.
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
