import 'package:test/test.dart';
import 'package:household_ledger/features/analysis/calculators/prepare_expense_analysis.dart';
import 'package:household_ledger/features/analysis/models/prepared_expense_analysis.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';

ExpenseAnalysisRequest request(DateTime today, {bool range = false}) => (
  expenses: [
    ExpenseEntry.create(
      spentAt: DateTime(today.year, today.month, 1),
      categoryCode: 'F',
      subcategoryCode: 'lunch',
      paymentMethodCode: 'card',
      diningOccasionCode: 'company',
      description: '',
      amount: 2900,
    ),
  ],
  previousExpenses: [],
  fixedExpenses: [
    FixedExpense.create(
      appliedAt: DateTime(today.year, today.month),
      categoryCode: 'L',
      description: '',
      amount: 1000,
    ),
    FixedExpense.create(
      appliedAt: DateTime(today.year, today.month - 1),
      categoryCode: 'L',
      description: '',
      amount: 9999,
    ),
  ],
  diningOccasionCodes: ['company'],
  start: DateTime(today.year, today.month),
  end: today,
  previousStart: DateTime(today.year, today.month - 1),
  today: today,
  usingRange: range,
  budget: 5000,
);

void main() {
  test('all sections share totals and only selected month fixed expenses', () {
    final result = prepareExpenseAnalysis(request(DateTime(2024, 2, 29)));
    expect(result.expenseTotal, 2900);
    expect(result.fixedTotal, 1000);
    expect(
      result.category.fold<int>(0, (sum, item) => sum + item.amount),
      3900,
    );
    expect(result.subcategory.single.amount, 2900);
    expect(result.paymentMethod.single.code, 'card');
    expect(result.diningOccasion.single.code, 'company');
    expect(result.food.companyDining.count, 1);
    expect(result.forecast!.dailyAverage, 100);
    expect(result.forecast!.monthEndAmount, 3900);
    expect(result.forecast!.projected, isEmpty);
    expect(result.previousTotal, 0);
    expect(result.previousDaily, isEmpty);
    expect(() => result.expenses.clear(), throwsUnsupportedError);
    expect(() => result.category.clear(), throwsUnsupportedError);
  });
  test('range excludes fixed expenses and forecast', () {
    final result = prepareExpenseAnalysis(
      request(DateTime(2026, 1, 31), range: true),
    );
    expect(result.fixedTotal, 0);
    expect(result.category.single.amount, 2900);
    expect(result.forecast, isNull);
  });
  test('empty January snapshot preserves zero values', () {
    final input = request(DateTime(2026, 1, 1));
    final result = prepareExpenseAnalysis((
      expenses: <ExpenseEntry>[],
      previousExpenses: <ExpenseEntry>[],
      fixedExpenses: <FixedExpense>[],
      diningOccasionCodes: input.diningOccasionCodes,
      start: input.start,
      end: input.end,
      previousStart: input.previousStart,
      today: input.today,
      usingRange: false,
      budget: 0,
    ));
    expect(result.expenseTotal, 0);
    expect(result.category, isEmpty);
    expect(result.food.hasFoodData, isFalse);
    expect(result.forecast!.monthEndAmount, 0);
  });
}
