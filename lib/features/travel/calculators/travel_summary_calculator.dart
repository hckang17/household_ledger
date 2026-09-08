import 'package:household_ledger/features/travel/models/travel_expense_timing.dart';
import 'package:household_ledger/features/travel/models/travel_summary.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/trip.dart';

/// 한 여행에 연결된 지출의 요약과 분석 수치를 계산한다.
class TravelSummaryCalculator {
  const TravelSummaryCalculator();

  static const String transportCategoryCode = 'T';
  static const String accommodationCategoryCode = 'A';

  TravelSummary calculate({
    required Trip trip,
    required Iterable<ExpenseEntry> expenses,
  }) {
    final start = _dateOnly(trip.startDate);
    final end = _dateOnly(trip.endDate);
    final tripDayCount = end.difference(start).inDays + 1;
    final safeTripDayCount = tripDayCount < 1 ? 1 : tripDayCount;
    final linkedExpenses = expenses
        .where((ExpenseEntry entry) => entry.tripId == trip.id)
        .toList(growable: false);

    var totalExpense = 0;
    var beforeTripExpense = 0;
    var duringTripExpense = 0;
    var afterTripExpense = 0;
    var transportExpense = 0;
    var accommodationExpense = 0;
    final categoryTotals = <String, int>{};
    final paymentMethodTotals = <String, int>{};
    final dailyTotals = <DateTime, int>{};

    for (final entry in linkedExpenses) {
      totalExpense += entry.amount;
      categoryTotals.update(
        entry.categoryCode,
        (int amount) => amount + entry.amount,
        ifAbsent: () => entry.amount,
      );
      paymentMethodTotals.update(
        entry.paymentMethodCode,
        (int amount) => amount + entry.amount,
        ifAbsent: () => entry.amount,
      );
      if (entry.categoryCode == transportCategoryCode) {
        transportExpense += entry.amount;
      }
      if (entry.categoryCode == accommodationCategoryCode) {
        accommodationExpense += entry.amount;
      }

      switch (timingOf(entry.spentAt, trip)) {
        case TravelExpenseTiming.before:
          beforeTripExpense += entry.amount;
        case TravelExpenseTiming.during:
          duringTripExpense += entry.amount;
          final date = _dateOnly(entry.spentAt);
          dailyTotals.update(
            date,
            (int amount) => amount + entry.amount,
            ifAbsent: () => entry.amount,
          );
        case TravelExpenseTiming.after:
          afterTripExpense += entry.amount;
      }
    }

    final budget = trip.budget;
    return TravelSummary(
      totalExpense: totalExpense,
      expenseCount: linkedExpenses.length,
      tripDayCount: safeTripDayCount,
      averagePerTripDay: (totalExpense / safeTripDayCount).round(),
      beforeTripExpense: beforeTripExpense,
      duringTripExpense: duringTripExpense,
      afterTripExpense: afterTripExpense,
      transportExpense: transportExpense,
      accommodationExpense: accommodationExpense,
      budget: budget,
      remainingBudget: budget == null ? null : budget - totalExpense,
      budgetUsagePercent: budget == null || budget <= 0
          ? null
          : totalExpense / budget * 100,
      categoryBreakdown: _breakdown(categoryTotals),
      paymentMethodBreakdown: _breakdown(paymentMethodTotals),
      dailyAmounts: List<TravelDailyAmount>.unmodifiable(
        List<TravelDailyAmount>.generate(safeTripDayCount, (int index) {
          final date = start.add(Duration(days: index));
          return TravelDailyAmount(
            date: date,
            dayNumber: index + 1,
            amount: dailyTotals[date] ?? 0,
          );
        }),
      ),
    );
  }

  TravelExpenseTiming timingOf(DateTime expenseDate, Trip trip) {
    final date = _dateOnly(expenseDate);
    final start = _dateOnly(trip.startDate);
    final end = _dateOnly(trip.endDate);
    if (date.isBefore(start)) return TravelExpenseTiming.before;
    if (date.isAfter(end)) return TravelExpenseTiming.after;
    return TravelExpenseTiming.during;
  }

  List<TravelBreakdownItem> _breakdown(Map<String, int> totals) {
    final total = totals.values.fold<int>(
      0,
      (int sum, int value) => sum + value,
    );
    if (total == 0) return const <TravelBreakdownItem>[];
    final sorted = totals.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));
    return List<TravelBreakdownItem>.unmodifiable(
      sorted.map(
        (entry) => TravelBreakdownItem(
          code: entry.key,
          amount: entry.value,
          percentage: entry.value / total * 100,
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
