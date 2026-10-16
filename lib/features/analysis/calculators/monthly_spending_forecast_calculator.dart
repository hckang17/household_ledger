import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import '../models/analysis_series_result.dart';
import '../models/monthly_spending_forecast.dart';

/// 무지출일을 포함한 경과 일수로 평균을 구하는 단순 월말 예측.
/// 이번 달 고정지출은 절편으로 한 번만 더하며 일평균에는 포함하지 않는다.
class MonthlySpendingForecastCalculator {
  const MonthlySpendingForecastCalculator();

  MonthlySpendingForecast? calculate({
    required Iterable<ExpenseEntry> expenses,
    Iterable<FixedExpense> fixedExpenses = const [],
    required DateTime selectedMonth,
    required bool usingRange,
    required DateTime today,
  }) {
    if (usingRange ||
        selectedMonth.year != today.year ||
        selectedMonth.month != today.month) {
      return null;
    }

    final days = DateTime(today.year, today.month + 1, 0).day;
    final fixedAmount = fixedExpenses
        .where(
          (entry) =>
              entry.appliedAt.year == today.year &&
              entry.appliedAt.month == today.month,
        )
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final daily = List<int>.filled(today.day, 0);
    for (final entry in expenses) {
      final date = entry.spentAt;
      if (date.year == today.year &&
          date.month == today.month &&
          date.day <= today.day) {
        daily[date.day - 1] += entry.amount;
      }
    }
    var total = 0;
    final actual = <DailyAmountPoint>[];
    for (var day = 1; day <= today.day; day++) {
      total += daily[day - 1];
      actual.add(DailyAmountPoint(dayOffset: day, amount: fixedAmount + total));
    }
    // 표시용 평균의 반올림 오차가 누적되지 않도록 각 예측점에서 한 번만 반올림한다.
    int estimate(int remainingDays) =>
        (total * remainingDays / today.day).round();
    return MonthlySpendingForecast(
      actual: actual,
      fixedAmount: fixedAmount,
      projected: today.day == days
          ? []
          : [
              for (var day = today.day; day <= days; day++)
                DailyAmountPoint(
                  dayOffset: day,
                  amount: fixedAmount + total + estimate(day - today.day),
                ),
            ],
      daysInMonth: days,
      dailyAverage: (total / today.day).round(),
      remainingAmount: estimate(days - today.day),
    );
  }
}
