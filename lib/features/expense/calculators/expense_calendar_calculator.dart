// """ MVVM 계층: Model / Calculation Feature """
// """ 역할: 소비 기록 달력에 필요한 날짜별 월간 지출 합계를 계산 """
// """ 규칙: 달력 Widget과 현지화 정보에 의존하지 않음 """

import 'package:household_ledger/model/expense_entry.dart';

class ExpenseCalendarCalculator {
  const ExpenseCalendarCalculator();

  Map<int, int> monthlyTotals(Iterable<ExpenseEntry> expenses, DateTime month) {
    final totals = <int, int>{};
    for (final entry in expenses) {
      if (entry.spentAt.year != month.year ||
          entry.spentAt.month != month.month) {
        continue;
      }
      totals.update(
        entry.spentAt.day,
        (int amount) => amount + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    return Map<int, int>.unmodifiable(totals);
  }
}
