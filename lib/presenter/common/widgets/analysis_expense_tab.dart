import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_chart_helpers.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_daily_chart.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_donut_chart.dart';
import 'package:intl/intl.dart';

/// 도넛 캐러샐의 슬라이드 종류를 정의한다.
enum AnalysisChartMode { category, subcategory, diningOccasion, paymentMethod }

/// 분석 화면의 지출 탭 콘텐츠다.
///
/// 도넛 차트 캐러샐·섹션 목록·고정지출 바·일별 추이를 포함한다.
/// 캐러샐 모드와 터치 인덱스는 위젯이 내부적으로 관리한다.
class AnalysisExpenseTabSection extends StatefulWidget {
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

  @override
  State<AnalysisExpenseTabSection> createState() =>
      _AnalysisExpenseTabSectionState();
}

class _AnalysisExpenseTabSectionState extends State<AnalysisExpenseTabSection> {
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
    const foodCategoryCodes = <String>{'C', 'F', 'G'};
    final foodExpenseTotal = expenses
        .where(
          (ExpenseEntry entry) =>
              foodCategoryCodes.contains(entry.categoryCode),
        )
        .fold<int>(0, (int total, ExpenseEntry entry) => total + entry.amount);
    final foodFixedTotal = activeFixed
        .where(
          (FixedExpense entry) =>
              foodCategoryCodes.contains(entry.categoryCode),
        )
        .fold<int>(0, (int total, FixedExpense entry) => total + entry.amount);
    final foodTotal = foodExpenseTotal + foodFixedTotal;
    final engelIndex = totalAmount > 0 ? foodTotal / totalAmount * 100 : 0.0;
    final periodDays =
        widget.chartRangeEnd.difference(widget.chartRangeStart).inDays.abs() +
        1;
    final previousExpenses = widget.prevCategoryExpenses;

    List<ExpenseEntry> categoryEntries(
      List<ExpenseEntry> source,
      String categoryCode,
    ) => source
        .where((ExpenseEntry entry) => entry.categoryCode == categoryCode)
        .toList();

    int totalOf(List<ExpenseEntry> source) => source.fold<int>(
      0,
      (int total, ExpenseEntry entry) => total + entry.amount,
    );

    int averageOf(List<ExpenseEntry> source) =>
        source.isEmpty ? 0 : (totalOf(source) / source.length).round();

    double dailyOf(List<ExpenseEntry> source) => source.length / periodDays;

    String frequencyComparison(double current, double previous) {
      if (previous == 0) {
        return _text('analysisNoPreviousFrequency', '전월동기 비교 기록이 아직 없어요.');
      }
      final difference = current - previous;
      final key = difference.abs() < 0.05
          ? 'analysisFrequencySimilar'
          : difference > 0
          ? 'analysisFrequencyMore'
          : 'analysisFrequencyLess';
      final fallback = difference.abs() < 0.05
          ? '전월동기 하루평균 {previous}회와 비슷한 수준이에요.'
          : difference > 0
          ? '전월동기 하루평균 {previous}회보다 {difference}회 많아요.'
          : '전월동기 하루평균 {previous}회보다 {difference}회 적어요.';
      return _text(key, fallback)
          .replaceAll('{previous}', previous.toStringAsFixed(2))
          .replaceAll('{difference}', difference.abs().toStringAsFixed(2));
    }

    String countComparison(int current, int previous) {
      if (previous == 0) {
        return _text('analysisNoPreviousCount', '전월동기 비교 기록이 아직 없어요.');
      }
      final difference = current - previous;
      final key = difference == 0
          ? 'analysisCountSimilar'
          : difference > 0
          ? 'analysisCountMore'
          : 'analysisCountLess';
      final fallback = difference == 0
          ? '전월동기 {previous}회와 같은 수준이에요.'
          : difference > 0
          ? '전월동기 {previous}회보다 {difference}회 늘었어요.'
          : '전월동기 {previous}회보다 {difference}회 줄었어요.';
      return _text(key, fallback)
          .replaceAll('{previous}', '$previous')
          .replaceAll('{difference}', '${difference.abs()}');
    }

    Widget visitCard({
      required IconData icon,
      required String title,
      required List<ExpenseEntry> current,
      required List<ExpenseEntry> previous,
      required String dailyTemplate,
      required String averageTemplate,
      required Color color,
    }) {
      final currentDaily = dailyOf(current);
      final previousDaily = dailyOf(previous);
      return BootstrapSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _InsightHeader(icon: icon, title: title, color: color),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _InsightValue(
                    value: currentDaily.toStringAsFixed(2),
                    label: dailyTemplate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InsightValue(
                    value:
                        '${averageOf(current).toCurrency()}${widget.currency}',
                    label: averageTemplate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _AnimatedComparisonBars(
              current: currentDaily,
              previous: previousDaily,
              currentLabel: _text('analysisCurrentPeriod', '현재'),
              previousLabel: _text('analysisPreviousPeriod', '전월동기'),
              valueSuffix: _text('analysisTimesPerDayUnit', '회/일'),
              color: color,
            ),
            const SizedBox(height: 12),
            _ComparisonMessage(
              text: frequencyComparison(currentDaily, previousDaily),
              isIncrease:
                  previousDaily > 0 && currentDaily > previousDaily + 0.05,
              isSimilar:
                  previousDaily == 0 ||
                  (currentDaily - previousDaily).abs() < 0.05,
            ),
          ],
        ),
      );
    }

    final diningEntries = categoryEntries(expenses, 'F');
    final previousDiningEntries = categoryEntries(previousExpenses, 'F');
    final diningDaily = dailyOf(diningEntries);
    final previousDiningDaily = dailyOf(previousDiningEntries);

    List<ExpenseEntry> occasionEntries(
      List<ExpenseEntry> source,
      String code,
    ) => source
        .where((ExpenseEntry entry) => entry.diningOccasionCode == code)
        .toList();

    final diningOccasionTags = widget.diningOccasionTags;
    final mealTimeCounts = <String, int>{
      for (final tag in diningOccasionTags)
        tag.code: occasionEntries(diningEntries, tag.code).length,
    };
    final previousMealTimeCounts = <String, int>{
      for (final tag in diningOccasionTags)
        tag.code: occasionEntries(previousDiningEntries, tag.code).length,
    };
    final String? peakMealCode = diningOccasionTags.isEmpty
        ? null
        : diningOccasionTags
              .map((MetadataTag tag) => tag.code)
              .reduce(
                (String left, String right) =>
                    (mealTimeCounts[left] ?? 0) >= (mealTimeCounts[right] ?? 0)
                    ? left
                    : right,
              );
    final peakMealCount = peakMealCode == null
        ? 0
        : mealTimeCounts[peakMealCode] ?? 0;
    final previousPeakMealCount = peakMealCode == null
        ? 0
        : previousMealTimeCounts[peakMealCode] ?? 0;
    final peakMealLabel = peakMealCode == null
        ? ''
        : diningOccasionTags.labelFor(peakMealCode);

    final companyEntries = occasionEntries(diningEntries, 'company');
    final previousCompanyEntries = occasionEntries(
      previousDiningEntries,
      'company',
    );
    final cafeEntries = categoryEntries(expenses, 'C');
    final previousCafeEntries = categoryEntries(previousExpenses, 'C');
    final groceryEntries = categoryEntries(expenses, 'G');
    final previousGroceryEntries = categoryEntries(previousExpenses, 'G');

    final engelStatusKey = engelIndex > 35
        ? 'analysisEngelHigh'
        : engelIndex < 25
        ? 'analysisEngelLow'
        : 'analysisEngelBalanced';
    final engelStatusFallback = engelIndex > 35
        ? '엥겔지수가 높아요!'
        : engelIndex < 25
        ? '엥겔지수가 낮아요!'
        : '엥겔지수가 안정적인 수준이에요.';
    final engelColor = engelIndex > 35
        ? const Color(0xFFDC3545)
        : engelIndex < 25
        ? const Color(0xFF0D6EFD)
        : const Color(0xFF198754);

    return Column(
      children: <Widget>[
        BootstrapSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _InsightHeader(
                      icon: Icons.pie_chart_outline_rounded,
                      title: _text('analysisEngelIndexLabel', '엥겔지수'),
                      color: engelColor,
                    ),
                  ),
                  Tooltip(
                    message: _text(
                      'analysisEngelTooltip',
                      '엥겔지수는 전체 지출 중 카페·외식·식료품 지출이 차지하는 비율입니다.',
                    ),
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: Color(0xFF627D98),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    engelIndex.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: engelColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5, left: 3),
                    child: Text(
                      '%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: engelColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _AnimatedGauge(
                value: (engelIndex / 60).clamp(0.0, 1.0).toDouble(),
                color: engelColor,
              ),
              const SizedBox(height: 12),
              _ComparisonMessage(
                text: _text(engelStatusKey, engelStatusFallback),
                isIncrease: engelIndex > 35,
                isSimilar: engelIndex >= 25 && engelIndex <= 35,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        BootstrapSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InsightHeader(
                icon: Icons.restaurant_rounded,
                title: _text('analysisDiningOverviewTitle', '외식'),
                color: const Color(0xFF0D6EFD),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _InsightValue(
                      value: diningDaily.toStringAsFixed(2),
                      label: _text('analysisDailyDiningLabel', '하루평균 외식 횟수'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InsightValue(
                      value:
                          '${averageOf(diningEntries).toCurrency()}${widget.currency}',
                      label: _text('analysisAverageDiningLabel', '1회 평균 금액'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _AnimatedComparisonBars(
                current: diningDaily,
                previous: previousDiningDaily,
                currentLabel: _text('analysisCurrentPeriod', '현재'),
                previousLabel: _text('analysisPreviousPeriod', '전월동기'),
                valueSuffix: _text('analysisTimesPerDayUnit', '회/일'),
                color: const Color(0xFF0D6EFD),
              ),
              const SizedBox(height: 12),
              _ComparisonMessage(
                text: frequencyComparison(diningDaily, previousDiningDaily),
                isIncrease:
                    previousDiningDaily > 0 &&
                    diningDaily > previousDiningDaily + 0.05,
                isSimilar:
                    previousDiningDaily == 0 ||
                    (diningDaily - previousDiningDaily).abs() < 0.05,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        BootstrapSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _InsightHeader(
                icon: Icons.query_stats_rounded,
                title: _text('analysisDiningDetailTitle', '외식 상세 분석'),
                color: const Color(0xFF6F42C1),
              ),
              const SizedBox(height: 16),
              _ChartLegend(
                currentLabel: _text('analysisCurrentPeriod', '현재'),
                previousLabel: _text('analysisPreviousPeriod', '전월동기'),
                color: const Color(0xFF6F42C1),
              ),
              const SizedBox(height: 10),
              _DiningOccasionVerticalChart(
                tags: diningOccasionTags,
                currentCounts: mealTimeCounts,
                previousCounts: previousMealTimeCounts,
                color: const Color(0xFF6F42C1),
              ),
              const SizedBox(height: 14),
              _ComparisonMessage(
                text: peakMealCount == 0
                    ? _text('analysisNoMealTimeData', '아직 시간대별 외식 기록이 없어요.')
                    : '${_text('analysisPeakMealTime', '{label} 유형의 외식이 가장 많아요!').replaceAll('{label}', peakMealLabel)}\n${countComparison(peakMealCount, previousPeakMealCount)}',
                isIncrease:
                    previousPeakMealCount > 0 &&
                    peakMealCount > previousPeakMealCount,
                isSimilar:
                    previousPeakMealCount == 0 ||
                    peakMealCount == previousPeakMealCount,
              ),
              const Divider(height: 30),
              Text(
                _text('analysisCompanyDiningTitle', '회식 분석'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _InsightValue(
                      value: '${companyEntries.length}',
                      label: _text('analysisCompanyCountLabel', '회식 횟수'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InsightValue(
                      value:
                          '${averageOf(companyEntries).toCurrency()}${widget.currency}',
                      label: _text('analysisCompanyAverageLabel', '평균 단가'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InsightValue(
                      value:
                          '${totalOf(companyEntries).toCurrency()}${widget.currency}',
                      label: _text('analysisCompanyTotalLabel', '총 사용금액'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _AnimatedComparisonBars(
                current: companyEntries.length.toDouble(),
                previous: previousCompanyEntries.length.toDouble(),
                currentLabel: _text('analysisCurrentPeriod', '현재'),
                previousLabel: _text('analysisPreviousPeriod', '전월동기'),
                valueSuffix: _text('analysisTimesUnit', '회'),
                color: const Color(0xFFDC3545),
              ),
              const SizedBox(height: 12),
              _ComparisonMessage(
                text: countComparison(
                  companyEntries.length,
                  previousCompanyEntries.length,
                ),
                isIncrease:
                    previousCompanyEntries.isNotEmpty &&
                    companyEntries.length > previousCompanyEntries.length,
                isSimilar:
                    previousCompanyEntries.isEmpty ||
                    companyEntries.length == previousCompanyEntries.length,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        visitCard(
          icon: Icons.local_cafe_rounded,
          title: _text('analysisCafeVisitTitle', '카페 방문'),
          current: cafeEntries,
          previous: previousCafeEntries,
          dailyTemplate: _text('analysisDailyVisitLabel', '하루평균 방문 횟수'),
          averageTemplate: _text('analysisAverageSpendLabel', '1회 평균 금액'),
          color: const Color(0xFF795548),
        ),
        const SizedBox(height: 16),
        visitCard(
          icon: Icons.shopping_cart_rounded,
          title: _text('analysisGroceryVisitTitle', '장보기'),
          current: groceryEntries,
          previous: previousGroceryEntries,
          dailyTemplate: _text('analysisDailyGroceryLabel', '하루평균 장보기 횟수'),
          averageTemplate: _text('analysisAverageSpendLabel', '1회 평균 금액'),
          color: const Color(0xFF198754),
        ),
      ],
    );
  }

  // ─── 상세 바텀시트 ────────────────────────────────────────────────

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
    final List<ExpenseEntry> expenses = widget.expenses;
    final List<FixedExpense> activeFixed = !widget.usingRange
        ? widget.monthlyFixed
        : const <FixedExpense>[];

    final int expenseTotal = expenses.fold(
      0,
      (int s, ExpenseEntry e) => s + e.amount,
    );
    final int fixedTotal = activeFixed.fold(
      0,
      (int s, FixedExpense f) => s + f.amount,
    );
    final int totalAmount = expenseTotal + fixedTotal;

    final int chartDisplayTotal = _chartMode == AnalysisChartMode.category
        ? totalAmount
        : expenseTotal;

    final List<ExpenseEntry> prevExpenses =
        _chartMode == AnalysisChartMode.category
        ? widget.prevCategoryExpenses
        : const <ExpenseEntry>[];
    final Map<String, int> prevCategoryTotals = <String, int>{};
    for (final ExpenseEntry e in prevExpenses) {
      prevCategoryTotals.update(
        e.categoryCode,
        (int v) => v + e.amount,
        ifAbsent: () => e.amount,
      );
    }
    final int prevExpensesTotal = prevExpenses.fold(
      0,
      (int s, ExpenseEntry e) => s + e.amount,
    );

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

class _InsightHeader extends StatelessWidget {
  const _InsightHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _InsightValue extends StatelessWidget {
  const _InsightValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F3A5F),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF627D98)),
        ),
      ],
    );
  }
}

class _AnimatedGauge extends StatelessWidget {
  const _AnimatedGauge({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double animatedValue, Widget? child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: animatedValue,
            minHeight: 10,
            color: color,
            backgroundColor: const Color(0xFFE6EDF4),
          ),
        );
      },
    );
  }
}

class _ComparisonMessage extends StatelessWidget {
  const _ComparisonMessage({
    required this.text,
    required this.isIncrease,
    required this.isSimilar,
  });

  final String text;
  final bool isIncrease;
  final bool isSimilar;

  @override
  Widget build(BuildContext context) {
    final Color color = isSimilar
        ? const Color(0xFF486581)
        : isIncrease
        ? const Color(0xFFDC3545)
        : const Color(0xFF198754);
    final IconData icon = isSimilar
        ? Icons.remove_rounded
        : isIncrease
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.currentLabel,
    required this.previousLabel,
    required this.color,
  });

  final String currentLabel;
  final String previousLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget item(Color dotColor, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        item(color, currentLabel),
        const SizedBox(width: 12),
        item(const Color(0xFFB8C4D1), previousLabel),
      ],
    );
  }
}

class _AnimatedComparisonBars extends StatelessWidget {
  const _AnimatedComparisonBars({
    required this.current,
    required this.previous,
    required this.currentLabel,
    required this.previousLabel,
    required this.valueSuffix,
    required this.color,
  });

  final double current;
  final double previous;
  final String currentLabel;
  final String previousLabel;
  final String valueSuffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double maxValue = math.max(current, previous);
    return Column(
      children: <Widget>[
        _AnimatedBarLine(
          label: currentLabel,
          value: current,
          maxValue: maxValue,
          valueSuffix: valueSuffix,
          color: color,
        ),
        const SizedBox(height: 8),
        _AnimatedBarLine(
          label: previousLabel,
          value: previous,
          maxValue: maxValue,
          valueSuffix: valueSuffix,
          color: const Color(0xFFB8C4D1),
        ),
      ],
    );
  }
}

class _DiningOccasionVerticalChart extends StatelessWidget {
  const _DiningOccasionVerticalChart({
    required this.tags,
    required this.currentCounts,
    required this.previousCounts,
    required this.color,
  });

  final List<MetadataTag> tags;
  final Map<String, int> currentCounts;
  final Map<String, int> previousCounts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final int maxCount = <int>[
      ...currentCounts.values,
      ...previousCounts.values,
      1,
    ].reduce(math.max);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double minimumGroupWidth = 52;
        final double groupWidth = tags.length <= 6
            ? math.max(minimumGroupWidth, constraints.maxWidth / tags.length)
            : minimumGroupWidth;
        final double chartWidth = math.max(
          constraints.maxWidth,
          groupWidth * tags.length,
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            height: 210,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tags.map((MetadataTag tag) {
                final int current = currentCounts[tag.code] ?? 0;
                final int previous = previousCounts[tag.code] ?? 0;
                return Semantics(
                  label: '${tag.label}, $current, $previous',
                  child: SizedBox(
                    width: groupWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                _AnimatedVerticalBar(
                                  value: current,
                                  maxValue: maxCount,
                                  color: color,
                                ),
                                const SizedBox(width: 1),
                                _AnimatedVerticalBar(
                                  value: previous,
                                  maxValue: maxCount,
                                  color: const Color(0xFFB8C4D1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),
                          SizedBox(
                            height: 42,
                            child: Text(
                              tag.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedVerticalBar extends StatelessWidget {
  const _AnimatedVerticalBar({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double fraction = maxValue <= 0 ? 0 : value / maxValue;
    return SizedBox(
      width: 17,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder:
            (BuildContext context, double animatedFraction, Widget? child) {
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double maximumBarHeight = math.max(
                    0,
                    constraints.maxHeight - 20,
                  );
                  final double barHeight = maximumBarHeight * animatedFraction;
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: barHeight + 2,
                        height: 16,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$value',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
      ),
    );
  }
}

class _AnimatedBarLine extends StatelessWidget {
  const _AnimatedBarLine({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.valueSuffix,
    required this.color,
  });

  final String label;
  final double value;
  final double maxValue;
  final String valueSuffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue <= 0 ? 0.0 : value / maxValue;
    final displayValue = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return Row(
      children: <Widget>[
        if (label.isNotEmpty)
          SizedBox(
            width: 68,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: Container(
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFFE6EDF4),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: fraction.clamp(0.0, 1.0).toDouble(),
              ),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder:
                  (
                    BuildContext context,
                    double animatedFraction,
                    Widget? child,
                  ) {
                    return FractionallySizedBox(
                      widthFactor: animatedFraction,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    );
                  },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: valueSuffix.isEmpty ? 28 : 66,
          child: Text(
            '$displayValue$valueSuffix',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
