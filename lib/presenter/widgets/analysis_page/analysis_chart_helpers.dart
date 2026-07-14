// """ MVVM 계층: View / analysis_page """
// """ 역할: 순수 분석 결과를 차트 라이브러리의 View 모델로 변환 """
// """ 규칙: 금액 집계는 AnalysisSeriesCalculator에 위임 """

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:household_ledger/features/analysis/calculators/analysis_series_calculator.dart';
import 'package:household_ledger/features/analysis/models/analysis_series_result.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/analysis_donut_chart.dart';

const String kAnalysisFixedCode = AnalysisSeriesCalculator.fixedExpenseCode;
const Color kAnalysisFixedColor = Color(0xFF37474F);

List<DonutSection> buildCategoryDonutSections(
  List<ExpenseEntry> expenses,
  List<MetadataTag> categoryTags,
  List<FixedExpense> fixedExpenses,
  String fixedLabel,
) => _toDonutSections(
  const AnalysisSeriesCalculator().categoryBreakdown(
    expenses: expenses,
    fixedExpenses: fixedExpenses,
  ),
  labelOf: (String code) =>
      code == kAnalysisFixedCode ? fixedLabel : categoryTags.labelFor(code),
);

List<DonutSection> buildSubcategoryDonutSections(
  List<ExpenseEntry> expenses,
  List<MetadataTag> subcategoryTags,
) => _toDonutSections(
  const AnalysisSeriesCalculator().subcategoryBreakdown(expenses),
  labelOf: subcategoryTags.labelFor,
);

List<DonutSection> buildPaymentDonutSections(
  List<ExpenseEntry> expenses,
  List<MetadataTag> paymentTags,
) => _toDonutSections(
  const AnalysisSeriesCalculator().paymentMethodBreakdown(expenses),
  labelOf: paymentTags.labelFor,
);

List<DonutSection> buildDiningOccasionDonutSections(
  List<ExpenseEntry> expenses,
  List<MetadataTag> diningOccasionTags,
) => _toDonutSections(
  const AnalysisSeriesCalculator().diningOccasionBreakdown(expenses),
  labelOf: diningOccasionTags.labelFor,
);

List<FlSpot> buildDailyExpenseSpots(
  List<ExpenseEntry> expenses,
  DateTime rangeStart,
) => _toSpots(
  const AnalysisSeriesCalculator().dailyExpenses(expenses, rangeStart),
);

List<FlSpot> buildDailyIncomeSpots(
  List<IncomeEntry> incomes,
  DateTime rangeStart,
) => _toSpots(
  const AnalysisSeriesCalculator().dailyIncomes(incomes, rangeStart),
);

List<DonutSection> _toDonutSections(
  List<AnalysisBreakdownItem> items, {
  required String Function(String code) labelOf,
}) {
  var colorIndex = 0;
  return items
      .map((AnalysisBreakdownItem item) {
        final isFixed = item.code == kAnalysisFixedCode;
        final color = isFixed
            ? kAnalysisFixedColor
            : kDonutSectionColors[colorIndex++ % kDonutSectionColors.length];
        return DonutSection(
          categoryCode: item.code,
          label: labelOf(item.code),
          amount: item.amount,
          percentage: item.percentage,
          color: color,
        );
      })
      .toList(growable: false);
}

List<FlSpot> _toSpots(List<DailyAmountPoint> points) => points
    .map(
      (DailyAmountPoint point) =>
          FlSpot(point.dayOffset.toDouble(), point.amount.toDouble()),
    )
    .toList(growable: false);
