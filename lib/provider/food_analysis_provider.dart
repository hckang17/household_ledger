// """ MVVM 계층: ViewModel Provider """
// """ 역할: 분석 화면이 필요로 하는 음식 분석 결과를 계산 기능에 요청해 제공 """
// """ 규칙: 수치 계산식은 features에 두고 Provider는 화면 입력과 결과 연결만 담당 """

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/features/analysis/calculators/food_analysis_calculator.dart';
import 'package:household_ledger/features/analysis/models/food_analysis_result.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';

// """ 분석 화면에서 ViewModel로 전달하는 입력 """
class FoodAnalysisInput {
  const FoodAnalysisInput({
    required this.expenses,
    required this.previousExpenses,
    required this.activeFixedExpenses,
    required this.totalAmount,
    required this.periodDays,
    required this.diningOccasionCodes,
  });

  final List<ExpenseEntry> expenses;
  final List<ExpenseEntry> previousExpenses;
  final List<FixedExpense> activeFixedExpenses;
  final int totalAmount;
  final int periodDays;
  final Iterable<String> diningOccasionCodes;
}

// """ 음식 분석 화면용 ViewModel Provider """
final foodAnalysisProvider = Provider.autoDispose
    .family<FoodAnalysisResult, FoodAnalysisInput>((Ref ref, input) {
      return const FoodAnalysisCalculator().calculate(
        expenses: input.expenses,
        previousExpenses: input.previousExpenses,
        activeFixedExpenses: input.activeFixedExpenses,
        totalAmount: input.totalAmount,
        periodDays: input.periodDays,
        diningOccasionCodes: input.diningOccasionCodes,
      );
    });
