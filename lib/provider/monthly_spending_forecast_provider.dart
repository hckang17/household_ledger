import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/features/analysis/calculators/monthly_spending_forecast_calculator.dart';
import 'package:household_ledger/features/analysis/models/monthly_spending_forecast.dart';
import 'package:household_ledger/model/expense_entry.dart';

typedef MonthlySpendingForecastInput = ({
  List<ExpenseEntry> expenses,
  DateTime selectedMonth,
  bool usingRange,
  DateTime today,
});

/// 화면에서 로딩/오류 처리를 마친 데이터만 순수 계산기에 전달한다.
final monthlySpendingForecastProvider = Provider.autoDispose
    .family<MonthlySpendingForecast?, MonthlySpendingForecastInput>((
      ref,
      input,
    ) {
      return const MonthlySpendingForecastCalculator().calculate(
        expenses: input.expenses,
        selectedMonth: input.selectedMonth,
        usingRange: input.usingRange,
        today: input.today,
      );
    });
