import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'analysis_series_result.dart';
import 'food_analysis_result.dart';
import 'monthly_spending_forecast.dart';

/// Immutable snapshot shared by every expense analysis section.
class PreparedExpenseAnalysis {
  const PreparedExpenseAnalysis({
    required this.expenses,
    required this.previousExpenses,
    required this.fixedExpenses,
    required this.expenseTotal,
    required this.fixedTotal,
    required this.previousTotal,
    required this.previousCategoryTotals,
    required this.category,
    required this.subcategory,
    required this.diningOccasion,
    required this.paymentMethod,
    required this.daily,
    required this.previousDaily,
    required this.food,
    required this.forecast,
    required this.budget,
    required this.today,
  });
  final List<ExpenseEntry> expenses;
  final List<ExpenseEntry> previousExpenses;
  final List<FixedExpense> fixedExpenses;
  final int expenseTotal;
  final int fixedTotal;
  final int previousTotal;
  final Map<String, int> previousCategoryTotals;
  final List<AnalysisBreakdownItem> category;
  final List<AnalysisBreakdownItem> subcategory;
  final List<AnalysisBreakdownItem> diningOccasion;
  final List<AnalysisBreakdownItem> paymentMethod;
  final List<DailyAmountPoint> daily;
  final List<DailyAmountPoint> previousDaily;
  final FoodAnalysisResult food;
  final MonthlySpendingForecast? forecast;
  final int budget;
  final DateTime today;
}

/// Only domain data crosses the isolate boundary; no widgets or providers.
typedef ExpenseAnalysisRequest = ({
  List<ExpenseEntry> expenses,
  List<ExpenseEntry> previousExpenses,
  List<FixedExpense> fixedExpenses,
  List<String> diningOccasionCodes,
  DateTime start,
  DateTime end,
  DateTime previousStart,
  DateTime today,
  bool usingRange,
  int budget,
});
