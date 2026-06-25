import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_donut_chart.dart';

/// 도넛 차트에서 고정지출을 구분하기 위한 내부 카테고리 코드다.
const String kAnalysisFixedCode = '__fixed__';

/// 도넛 차트에서 고정지출 섹션에 사용하는 색상이다.
const Color kAnalysisFixedColor = Color(0xFF37474F);

/// 소비구분(카테고리) 도넛 섹션을 계산한다. 고정지출을 포함한다.
List<DonutSection> buildCategoryDonutSections(
  List<ExpenseEntry> expenses,
  List<MetadataTag> categoryTags,
  List<FixedExpense> fixedExpenses,
  String fixedLabel,
) {
  final Map<String, int> sums = <String, int>{};
  for (final ExpenseEntry e in expenses) {
    sums.update(
      e.categoryCode,
      (int v) => v + e.amount,
      ifAbsent: () => e.amount,
    );
  }
  if (fixedExpenses.isNotEmpty) {
    final int fixedTotal = fixedExpenses.fold(
      0,
      (int s, FixedExpense f) => s + f.amount,
    );
    if (fixedTotal > 0) sums[kAnalysisFixedCode] = fixedTotal;
  }
  return _toSortedDonutSections(
    sums,
    (String code) =>
        code == kAnalysisFixedCode ? fixedLabel : categoryTags.labelFor(code),
    (String code, int colorIndex) => code == kAnalysisFixedCode
        ? kAnalysisFixedColor
        : kDonutSectionColors[colorIndex],
  );
}

/// 소비소구분 도넛 섹션을 계산한다.
List<DonutSection> buildSubcategoryDonutSections(
  List<ExpenseEntry> expenses,
  List<MetadataTag> subcategoryTags,
) {
  final Map<String, int> sums = <String, int>{};
  for (final ExpenseEntry e in expenses) {
    if (e.subcategoryCode.isEmpty) continue;
    sums.update(
      e.subcategoryCode,
      (int v) => v + e.amount,
      ifAbsent: () => e.amount,
    );
  }
  return _toSortedDonutSections(
    sums,
    (String code) => subcategoryTags.labelFor(code),
    (String code, int colorIndex) => kDonutSectionColors[colorIndex],
  );
}

/// 소비수단 도넛 섹션을 계산한다.
List<DonutSection> buildPaymentDonutSections(
  List<ExpenseEntry> expenses,
  List<MetadataTag> paymentTags,
) {
  final Map<String, int> sums = <String, int>{};
  for (final ExpenseEntry e in expenses) {
    if (e.paymentMethodCode.isEmpty) continue;
    sums.update(
      e.paymentMethodCode,
      (int v) => v + e.amount,
      ifAbsent: () => e.amount,
    );
  }
  return _toSortedDonutSections(
    sums,
    (String code) => paymentTags.labelFor(code),
    (String code, int colorIndex) => kDonutSectionColors[colorIndex],
  );
}

/// 일별 지출 추이 [FlSpot] 목록을 계산한다.
List<FlSpot> buildDailyExpenseSpots(
  List<ExpenseEntry> expenses,
  DateTime rangeStart,
) {
  if (expenses.isEmpty) return <FlSpot>[];
  final DateTime base =
      DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
  final Map<int, int> daily = <int, int>{};
  for (final ExpenseEntry e in expenses) {
    final int offset =
        DateTime(e.spentAt.year, e.spentAt.month, e.spentAt.day)
            .difference(base)
            .inDays +
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

/// 일별 수입 추이 [FlSpot] 목록을 계산한다.
List<FlSpot> buildDailyIncomeSpots(
  List<IncomeEntry> incomes,
  DateTime rangeStart,
) {
  if (incomes.isEmpty) return <FlSpot>[];
  final DateTime base =
      DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
  final Map<int, int> daily = <int, int>{};
  for (final IncomeEntry e in incomes) {
    final int offset =
        DateTime(e.earnedAt.year, e.earnedAt.month, e.earnedAt.day)
            .difference(base)
            .inDays +
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

List<DonutSection> _toSortedDonutSections(
  Map<String, int> sums,
  String Function(String code) labelOf,
  Color Function(String code, int colorIndex) colorOf,
) {
  final int total = sums.values.fold(0, (int a, int b) => a + b);
  if (total == 0) return <DonutSection>[];

  final List<MapEntry<String, int>> sorted = sums.entries.toList()
    ..sort(
      (MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value),
    );

  int colorIndex = 0;
  return sorted.map((MapEntry<String, int> entry) {
    final String code = entry.key;
    final bool isFixed = code == kAnalysisFixedCode;
    final Color color = colorOf(code, colorIndex);
    if (!isFixed) colorIndex++;
    return DonutSection(
      categoryCode: code,
      label: labelOf(code),
      amount: entry.value,
      percentage: entry.value / total * 100,
      color: color,
    );
  }).toList();
}
