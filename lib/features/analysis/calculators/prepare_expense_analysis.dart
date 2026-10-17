import '../models/prepared_expense_analysis.dart';
import 'analysis_series_calculator.dart';
import 'food_analysis_calculator.dart';
import 'monthly_spending_forecast_calculator.dart';

/// Computes all chart modes once, outside the UI isolate on native platforms.
PreparedExpenseAnalysis prepareExpenseAnalysis(ExpenseAnalysisRequest input) {
  const series = AnalysisSeriesCalculator();
  final expenses = List.of(input.expenses, growable: false);
  final previous = List.of(input.previousExpenses, growable: false);
  final fixed = input.fixedExpenses
      .where(
        (entry) =>
            !input.usingRange &&
            entry.appliedAt.year == input.start.year &&
            entry.appliedAt.month == input.start.month,
      )
      .toList(growable: false);
  final expenseTotal = series.expenseTotal(expenses);
  final fixedTotal = series.fixedExpenseTotal(fixed);
  return PreparedExpenseAnalysis(
    expenses: List.unmodifiable(expenses),
    previousExpenses: List.unmodifiable(previous),
    fixedExpenses: List.unmodifiable(fixed),
    expenseTotal: expenseTotal,
    fixedTotal: fixedTotal,
    previousTotal: series.expenseTotal(previous),
    previousCategoryTotals: series.categoryTotals(previous),
    category: series.categoryBreakdown(
      expenses: expenses,
      fixedExpenses: fixed,
    ),
    subcategory: series.subcategoryBreakdown(expenses),
    diningOccasion: series.diningOccasionBreakdown(expenses),
    paymentMethod: series.paymentMethodBreakdown(expenses),
    daily: series.dailyExpenses(expenses, input.start),
    previousDaily: series.dailyExpenses(previous, input.previousStart),
    food: const FoodAnalysisCalculator().calculate(
      expenses: expenses,
      previousExpenses: previous,
      activeFixedExpenses: fixed,
      totalAmount: expenseTotal + fixedTotal,
      periodDays: input.end.difference(input.start).inDays.abs() + 1,
      diningOccasionCodes: input.diningOccasionCodes,
    ),
    forecast: const MonthlySpendingForecastCalculator().calculate(
      expenses: expenses,
      fixedExpenses: fixed,
      selectedMonth: input.start,
      usingRange: input.usingRange,
      today: input.today,
    ),
    budget: input.budget,
    today: input.today,
  );
}
