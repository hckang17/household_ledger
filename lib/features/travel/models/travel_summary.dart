import 'package:household_ledger/features/travel/models/travel_expense_timing.dart';

/// 여행 지출의 코드별 합계와 비율이다.
class TravelBreakdownItem {
  const TravelBreakdownItem({
    required this.code,
    required this.amount,
    required this.percentage,
  });

  final String code;
  final int amount;
  final double percentage;
}

/// 여행 기간의 하루 지출 합계다.
class TravelDailyAmount {
  const TravelDailyAmount({
    required this.date,
    required this.dayNumber,
    required this.amount,
  });

  final DateTime date;
  final int dayNumber;
  final int amount;
}

/// 한 여행에 연결된 모든 지출에서 계산한 불변 요약 결과다.
class TravelSummary {
  const TravelSummary({
    required this.totalExpense,
    required this.expenseCount,
    required this.tripDayCount,
    required this.averagePerTripDay,
    required this.beforeTripExpense,
    required this.duringTripExpense,
    required this.afterTripExpense,
    required this.transportExpense,
    required this.accommodationExpense,
    required this.budget,
    required this.remainingBudget,
    required this.budgetUsagePercent,
    required this.categoryBreakdown,
    required this.paymentMethodBreakdown,
    required this.dailyAmounts,
  });

  final int totalExpense;
  final int expenseCount;
  final int tripDayCount;
  final int averagePerTripDay;
  final int beforeTripExpense;
  final int duringTripExpense;
  final int afterTripExpense;
  final int transportExpense;
  final int accommodationExpense;
  final int? budget;
  final int? remainingBudget;
  final double? budgetUsagePercent;
  final List<TravelBreakdownItem> categoryBreakdown;
  final List<TravelBreakdownItem> paymentMethodBreakdown;
  final List<TravelDailyAmount> dailyAmounts;

  int amountForTiming(TravelExpenseTiming timing) => switch (timing) {
    TravelExpenseTiming.before => beforeTripExpense,
    TravelExpenseTiming.during => duringTripExpense,
    TravelExpenseTiming.after => afterTripExpense,
  };
}
