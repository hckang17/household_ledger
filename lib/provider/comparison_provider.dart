// """ MVVM 계층: ViewModel Provider """
// """ 역할: Ledger 상태를 읽어 홈 화면용 소비 비교 결과를 제공 """
// """ 규칙: 비교 계산식은 features에 위임하고 화면 데이터 연결만 담당 """

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/features/comparison/calculators/expense_comparison_calculator.dart';
import 'package:household_ledger/features/comparison/models/expense_comparison_result.dart';
import 'package:household_ledger/provider/ledger_provider.dart';

final comparisonProvider = Provider<ExpenseComparisonResult?>((Ref ref) {
  final ledger = ref.watch(ledgerProvider).asData?.value;
  if (ledger == null) return null;

  return const ExpenseComparisonCalculator().calculate(
    currentExpenses: ledger.expenses,
    previousExpenses: ledger.prevPeriodExpenses,
  );
});
