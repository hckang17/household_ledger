// """ MVVM 계층: Model / Reporting Request """
// """ 역할: PDF 생성에 필요한 화면 입력과 조회 데이터를 하나의 요청으로 전달 """
// """ 규칙: 생성 과정에서 값이 바뀌지 않는 불변 객체 """

import 'package:household_ledger/model/reporting/report_options.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';

/// 화면에서 수집한 PDF 생성 입력을 하나의 불변 요청으로 전달한다.
class ReportGenerationRequest {
  const ReportGenerationRequest({
    required this.expenses,
    required this.fixedExpenses,
    required this.incomes,
    required this.ledger,
    required this.email,
    required this.options,
    required this.periodLabel,
    required this.strings,
    required this.previousExpenses,
    required this.periodStart,
    required this.previousPeriodStart,
    required this.reportTitle,
  });

  final List<ExpenseEntry> expenses;
  final List<FixedExpense> fixedExpenses;
  final List<IncomeEntry> incomes;
  final LedgerState ledger;
  final String email;
  final ReportOptions options;
  final String periodLabel;
  final Map<String, String> strings;
  final List<ExpenseEntry> previousExpenses;
  final DateTime? periodStart;
  final DateTime? previousPeriodStart;
  final String reportTitle;
}
