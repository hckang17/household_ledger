// """ MVVM 계층: Model / Calculation Feature """
// """ 역할: 지출, 고정지출, 수입을 PDF 공통 집계 결과로 계산 """
// """ 규칙: PDF 라이브러리와 파일 시스템에 의존하지 않는 순수 계산 코드 """

import 'package:household_ledger/features/reporting/models/report_summary.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';

/// PDF 위젯이나 파일 시스템에 의존하지 않고 리포트 합계를 계산한다.
class ReportSummaryCalculator {
  const ReportSummaryCalculator();

  // """ 공개 계산 진입점 """
  ReportSummary calculate({
    required Iterable<ExpenseEntry> expenses,
    required Iterable<FixedExpense> fixedExpenses,
    required Iterable<IncomeEntry> incomes,
  }) {
    final categoryTotals = <String, int>{};
    final categoryCounts = <String, int>{};
    final paymentMethodTotals = <String, int>{};
    var expenseTotal = 0;

    for (final entry in expenses) {
      expenseTotal += entry.amount;
      categoryTotals.update(
        entry.categoryCode,
        (int value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
      categoryCounts.update(
        entry.categoryCode,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
      if (entry.paymentMethodCode.isNotEmpty) {
        paymentMethodTotals.update(
          entry.paymentMethodCode,
          (int value) => value + entry.amount,
          ifAbsent: () => entry.amount,
        );
      }
    }

    return ReportSummary(
      expenseTotal: expenseTotal,
      fixedTotal: fixedExpenses.fold<int>(
        0,
        (int total, FixedExpense entry) => total + entry.amount,
      ),
      incomeTotal: incomes.fold<int>(
        0,
        (int total, IncomeEntry entry) => total + entry.amount,
      ),
      categoryTotals: Map<String, int>.unmodifiable(categoryTotals),
      categoryCounts: Map<String, int>.unmodifiable(categoryCounts),
      paymentMethodTotals: Map<String, int>.unmodifiable(paymentMethodTotals),
    );
  }
}
