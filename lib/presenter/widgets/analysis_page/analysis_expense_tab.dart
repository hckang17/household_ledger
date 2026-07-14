// """ MVVM 계층: View / analysis_page """
// """ 역할: 지출 분석 탭의 차트, 카드, 상세 화면을 조합 """
// """ 계산: FoodAnalysisProvider가 제공한 결과만 화면에 연결 """

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/features/analysis/calculators/analysis_series_calculator.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/food/food_insight_section.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/analysis_chart_helpers.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/analysis_daily_chart.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/analysis_donut_chart.dart';
import 'package:household_ledger/provider/food_analysis_provider.dart';
import 'package:intl/intl.dart';

/// 도넛 캐러샐의 슬라이드 종류를 정의한다.
enum AnalysisChartMode { category, subcategory, diningOccasion, paymentMethod }

/// 분석 화면의 지출 탭 콘텐츠다.
///
/// 도넛 차트 캐러샐·섹션 목록·고정지출 바·일별 추이를 포함한다.
/// 캐러샐 모드와 터치 인덱스는 위젯이 내부적으로 관리한다.
class AnalysisExpenseTabSection extends ConsumerStatefulWidget {
  const AnalysisExpenseTabSection({
    required this.expenses,
    required this.prevCategoryExpenses,
    required this.monthlyFixed,
    required this.categoryTags,
    required this.subcategoryTags,
    required this.diningOccasionTags,
    required this.paymentTags,
    required this.strings,
    required this.currency,
    required this.usingRange,
    required this.chartRangeStart,
    required this.chartRangeEnd,
    required this.prevRangeStart,
    required this.onAddExpense,
    super.key,
  });

  final List<ExpenseEntry> expenses;
  final List<ExpenseEntry> prevCategoryExpenses;
  final List<FixedExpense> monthlyFixed;
  final List<MetadataTag> categoryTags;
  final List<MetadataTag> subcategoryTags;
  final List<MetadataTag> diningOccasionTags;
  final List<MetadataTag> paymentTags;
  final Map<String, String> strings;
  final String currency;
  final bool usingRange;
  final DateTime chartRangeStart;
  final DateTime chartRangeEnd;
  final DateTime prevRangeStart;
  final VoidCallback onAddExpense;

  @override
  ConsumerState<AnalysisExpenseTabSection> createState() =>
      _AnalysisExpenseTabSectionState();
}

class _AnalysisExpenseTabSectionState
    extends ConsumerState<AnalysisExpenseTabSection> {
  AnalysisChartMode _chartMode = AnalysisChartMode.category;
  int _touchedIndex = -1;
  final GlobalKey _fixedSectionKey = GlobalKey();

  // ─── 헬퍼 ────────────────────────────────────────────────────────

  String _text(String key, [String fallback = '']) =>
      widget.strings[key] ?? fallback;

  // ─── 캐러샐 내비게이션 ────────────────────────────────────────────

  void _prevChart() => setState(() {
    _touchedIndex = -1;
    _chartMode = switch (_chartMode) {
      AnalysisChartMode.category => AnalysisChartMode.paymentMethod,
      AnalysisChartMode.subcategory => AnalysisChartMode.category,
      AnalysisChartMode.diningOccasion => AnalysisChartMode.subcategory,
      AnalysisChartMode.paymentMethod => AnalysisChartMode.diningOccasion,
    };
  });

  void _nextChart() => setState(() {
    _touchedIndex = -1;
    _chartMode = switch (_chartMode) {
      AnalysisChartMode.category => AnalysisChartMode.subcategory,
      AnalysisChartMode.subcategory => AnalysisChartMode.diningOccasion,
      AnalysisChartMode.diningOccasion => AnalysisChartMode.paymentMethod,
      AnalysisChartMode.paymentMethod => AnalysisChartMode.category,
    };
  });

  String _chartModeTitle() => switch (_chartMode) {
    AnalysisChartMode.category => _text('categoryLabel', '소비구분'),
    AnalysisChartMode.subcategory => _text('subcategoryLabel', '소비 소구분'),
    AnalysisChartMode.diningOccasion => _text('diningOccasionLabel', '식사 유형'),
    AnalysisChartMode.paymentMethod => _text('paymentMethodLabel', '소비수단'),
  };

  // ─── 스크롤 ──────────────────────────────────────────────────────

  void _scrollToFixedSection() {
    final BuildContext? ctx = _fixedSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
    );
  }

  // ─── 전월동기 비교 헬퍼 ──────────────────────────────────────────

  String? _categoryDiffText(
    int currentAmount,
    String categoryCode,
    Map<String, int> prevTotals,
  ) {
    if (prevTotals.isEmpty) return null;
    final int diff = currentAmount - (prevTotals[categoryCode] ?? 0);
    if (diff == 0) return null;
    return '${diff > 0 ? '▲' : '▼'}${diff.abs().toCurrency()}${widget.currency}';
  }

  Color _categoryDiffColor(
    int currentAmount,
    String categoryCode,
    Map<String, int> prevTotals,
  ) {
    final int diff = currentAmount - (prevTotals[categoryCode] ?? 0);
    return diff > 0 ? const Color(0xFFDC3545) : const Color(0xFF198754);
  }

  Widget _buildFoodInsightSection({
    required List<ExpenseEntry> expenses,
    required List<FixedExpense> activeFixed,
    required int totalAmount,
  }) {
    return FoodInsightSection(
      result: ref.watch(
        foodAnalysisProvider(
          FoodAnalysisInput(
            expenses: expenses,
            previousExpenses: widget.prevCategoryExpenses,
            activeFixedExpenses: activeFixed,
            totalAmount: totalAmount,
            periodDays:
                widget.chartRangeEnd
                    .difference(widget.chartRangeStart)
                    .inDays
                    .abs() +
                1,
            diningOccasionCodes: widget.diningOccasionTags.map(
              (MetadataTag tag) => tag.code,
            ),
          ),
        ),
      ),
      diningOccasionTags: widget.diningOccasionTags,
      strings: widget.strings,
      currency: widget.currency,
      onAddExpense: widget.onAddExpense,
    );
  }

  void _showGroupDetail(
    DonutSection section,
    List<ExpenseEntry> filteredExpenses,
  ) {
    final String detailTitle = _text(
      'analysisCategoryDetailTitle',
      '{label} 상세',
    ).replaceAll('{label}', section.label);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ScrollController controller) => SafeArea(
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
                              style: Theme.of(ctx).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
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
                            '${section.amount.toCurrency()}${widget.currency}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${filteredExpenses.length}${_text('entryCountUnit', '건')}',
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
                  child: filteredExpenses.isEmpty
                      ? Center(
                          child: Text(_text('emptyData', '아직 입력된 데이터가 없습니다.')),
                        )
                      : ListView.separated(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredExpenses.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (_, int i) {
                            final ExpenseEntry item = filteredExpenses[i];
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
                                '${item.amount.toCurrency()}${widget.currency}',
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
          ),
        ),
      ),
    );
  }

  // ─── UI 빌더 ─────────────────────────────────────────────────────

  Widget _buildCarouselHeader() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: <Widget>[
        _CarouselArrowButton(
          icon: Icons.chevron_left_rounded,
          onTap: _prevChart,
        ),
        Expanded(
          child: Text(
            _chartModeTitle(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        _CarouselArrowButton(
          icon: Icons.chevron_right_rounded,
          onTap: _nextChart,
        ),
      ],
    ),
  );

  Widget _buildSectionRow({
    required DonutSection section,
    required VoidCallback onDetailTap,
    required VoidCallback onRowTap,
    String? prevDiffText,
    Color? prevDiffColor,
  }) => GestureDetector(
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
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${section.amount.toCurrency()}${widget.currency}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (prevDiffText != null)
                Text(
                  prevDiffText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: prevDiffColor ?? Colors.grey.shade500,
                  ),
                ),
            ],
          ),
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

  Widget _buildFixedExpenseBarSection({
    required List<FixedExpense> items,
    required int totalAmount,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final int maxAmount = items
        .map((FixedExpense f) => f.amount)
        .reduce((int a, int b) => a > b ? a : b);
    final int fixedTotal = items.fold(
      0,
      (int s, FixedExpense f) => s + f.amount,
    );
    final double fixedPercentage = totalAmount > 0
        ? fixedTotal / totalAmount * 100
        : 0.0;

    return BootstrapSectionCard(
      key: _fixedSectionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _text('analysisFixedExpenseSectionTitle', '이번 달 고정지출'),
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
                  color: kAnalysisFixedColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${fixedTotal.toCurrency()}${widget.currency}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF0D6EFD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((MapEntry<int, FixedExpense> entry) {
            final FixedExpense item = entry.value;
            final double ratio = maxAmount > 0 ? item.amount / maxAmount : 0.0;
            final Color barColor =
                kDonutSectionColors[entry.key % kDonutSectionColors.length];
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
                        '${item.amount.toCurrency()}${widget.currency}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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

  // ─── 빌드 ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const calculator = AnalysisSeriesCalculator();
    final List<ExpenseEntry> expenses = widget.expenses;
    final List<FixedExpense> activeFixed = !widget.usingRange
        ? widget.monthlyFixed
        : const <FixedExpense>[];

    final int expenseTotal = calculator.expenseTotal(expenses);
    final int fixedTotal = calculator.fixedExpenseTotal(activeFixed);
    final int totalAmount = expenseTotal + fixedTotal;

    final int chartDisplayTotal = _chartMode == AnalysisChartMode.category
        ? totalAmount
        : expenseTotal;

    final List<ExpenseEntry> prevExpenses =
        _chartMode == AnalysisChartMode.category
        ? widget.prevCategoryExpenses
        : const <ExpenseEntry>[];
    final Map<String, int> prevCategoryTotals = calculator.categoryTotals(
      prevExpenses,
    );
    final int prevExpensesTotal = calculator.expenseTotal(prevExpenses);

    String? totalDiffText;
    Color? totalDiffColor;
    if (_chartMode == AnalysisChartMode.category && prevExpenses.isNotEmpty) {
      final int totalDiff = expenseTotal - prevExpensesTotal;
      final bool isIncrease = totalDiff > 0;
      totalDiffText =
          '${isIncrease ? '▲' : '▼'}${totalDiff.abs().toCurrency()}${widget.currency}';
      totalDiffColor = isIncrease
          ? const Color(0xFFDC3545)
          : const Color(0xFF198754);
    }

    final List<DonutSection> sections = switch (_chartMode) {
      AnalysisChartMode.category => buildCategoryDonutSections(
        expenses,
        widget.categoryTags,
        activeFixed,
        _text('fixedExpenseCategoryLabel', '고정지출'),
      ),
      AnalysisChartMode.subcategory => buildSubcategoryDonutSections(
        expenses,
        widget.subcategoryTags,
      ),
      AnalysisChartMode.diningOccasion => buildDiningOccasionDonutSections(
        expenses,
        widget.diningOccasionTags,
      ),
      AnalysisChartMode.paymentMethod => buildPaymentDonutSections(
        expenses,
        widget.paymentTags,
      ),
    };

    final List<FlSpot> dailySpots = buildDailyExpenseSpots(
      expenses,
      widget.chartRangeStart,
    );

    final List<FlSpot> prevDailySpots = widget.prevCategoryExpenses.isNotEmpty
        ? buildDailyExpenseSpots(
            widget.prevCategoryExpenses,
            widget.prevRangeStart,
          )
        : const <FlSpot>[];

    List<ExpenseEntry> filteredFor(DonutSection section) {
      final List<ExpenseEntry> list = switch (_chartMode) {
        AnalysisChartMode.category =>
          expenses
              .where((ExpenseEntry e) => e.categoryCode == section.categoryCode)
              .toList(),
        AnalysisChartMode.subcategory =>
          expenses
              .where(
                (ExpenseEntry e) => e.subcategoryCode == section.categoryCode,
              )
              .toList(),
        AnalysisChartMode.diningOccasion =>
          expenses
              .where(
                (ExpenseEntry e) =>
                    e.diningOccasionCode == section.categoryCode,
              )
              .toList(),
        AnalysisChartMode.paymentMethod =>
          expenses
              .where(
                (ExpenseEntry e) => e.paymentMethodCode == section.categoryCode,
              )
              .toList(),
      };
      return list..sort(
        (ExpenseEntry a, ExpenseEntry b) => b.spentAt.compareTo(a.spentAt),
      );
    }

    return Column(
      children: <Widget>[
        // ── 도넛 차트 카드 (캐러샐 포함) ──
        BootstrapSectionCard(
          child: Column(
            children: <Widget>[
              _buildCarouselHeader(),
              AnalysisDonutChart(
                sections: sections,
                touchedIndex: _touchedIndex,
                onTouchUpdate: (int index) =>
                    setState(() => _touchedIndex = index),
                onSectionTap: (int index) {
                  if (index < 0 || index >= sections.length) return;
                  final DonutSection tapped = sections[index];
                  if (_chartMode == AnalysisChartMode.category &&
                      tapped.categoryCode == kAnalysisFixedCode) {
                    _scrollToFixedSection();
                    return;
                  }
                  _showGroupDetail(tapped, filteredFor(tapped));
                },
                totalLabel: _text('analysisTotalLabel', '전체'),
                totalAmount:
                    '${chartDisplayTotal.toCurrency()}${widget.currency}',
                currency: widget.currency,
                totalDiffText: totalDiffText,
                totalDiffColor: totalDiffColor,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    _text('analysisTotalLabel', '전체'),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${chartDisplayTotal.toCurrency()}${widget.currency}',
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

        // ── 데이터 목록 카드 ──
        if (sections.isNotEmpty)
          BootstrapSectionCard(
            child: Column(
              children: sections.asMap().entries.map((
                MapEntry<int, DonutSection> entry,
              ) {
                final bool isFixed =
                    _chartMode == AnalysisChartMode.category &&
                    entry.value.categoryCode == kAnalysisFixedCode;
                return Column(
                  children: <Widget>[
                    _buildSectionRow(
                      section: entry.value,
                      onRowTap: () {
                        setState(
                          () => _touchedIndex = _touchedIndex == entry.key
                              ? -1
                              : entry.key,
                        );
                        if (isFixed) _scrollToFixedSection();
                      },
                      onDetailTap: () {
                        if (isFixed) {
                          _scrollToFixedSection();
                          return;
                        }
                        _showGroupDetail(entry.value, filteredFor(entry.value));
                      },
                      prevDiffText: !isFixed
                          ? _categoryDiffText(
                              entry.value.amount,
                              entry.value.categoryCode,
                              prevCategoryTotals,
                            )
                          : null,
                      prevDiffColor: !isFixed
                          ? _categoryDiffColor(
                              entry.value.amount,
                              entry.value.categoryCode,
                              prevCategoryTotals,
                            )
                          : null,
                    ),
                    if (entry.key < sections.length - 1)
                      const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        if (sections.isNotEmpty) const SizedBox(height: 16),

        _buildFoodInsightSection(
          expenses: expenses,
          activeFixed: activeFixed,
          totalAmount: totalAmount,
        ),
        const SizedBox(height: 16),

        // ── 고정지출 가로 막대 카드 (월간 모드에서만) ──
        if (!widget.usingRange)
          _buildFixedExpenseBarSection(
            items: widget.monthlyFixed,
            totalAmount: totalAmount,
          ),
        if (!widget.usingRange && widget.monthlyFixed.isNotEmpty)
          const SizedBox(height: 16),

        // ── 일별 지출 추이 카드 ──
        if (dailySpots.isNotEmpty)
          BootstrapSectionCard(
            child: AnalysisDailyChart(
              spots: dailySpots,
              prevSpots: prevDailySpots.isNotEmpty ? prevDailySpots : null,
              currency: widget.currency,
              title: _text('analysisDailyTrendTitle', '일별 지출 추이'),
              rangeStart: widget.chartRangeStart,
              prevRangeStart: prevDailySpots.isNotEmpty
                  ? widget.prevRangeStart
                  : null,
              showDayStats: true,
            ),
          ),
        if (dailySpots.isNotEmpty) const SizedBox(height: 16),

        if (sections.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                _text('emptyData', '아직 입력된 데이터가 없습니다.'),
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ),
      ],
    );
  }
}

/// 캐러샐 좌/우 화살표 버튼이다.
class _CarouselArrowButton extends StatelessWidget {
  const _CarouselArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 22, color: Colors.grey.shade700),
      ),
    );
  }
}
