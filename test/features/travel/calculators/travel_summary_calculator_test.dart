import 'package:household_ledger/features/travel/calculators/travel_summary_calculator.dart';
import 'package:household_ledger/features/travel/models/travel_expense_timing.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:test/test.dart';

void main() {
  const calculator = TravelSummaryCalculator();
  final trip = Trip.create(
    id: 'trip-a',
    name: '제주 여행',
    startDate: DateTime(2026, 9, 3),
    endDate: DateTime(2026, 9, 5),
    budget: 600000,
  );

  ExpenseEntry expense({
    required String id,
    required DateTime date,
    required String categoryCode,
    required int amount,
    String tripId = 'trip-a',
    String paymentCode = '_s',
  }) {
    return ExpenseEntry.create(
      id: id,
      spentAt: date,
      categoryCode: categoryCode,
      subcategoryCode: 't',
      tripId: tripId,
      paymentMethodCode: paymentCode,
      description: id,
      amount: amount,
    );
  }

  test('연결된 전체 비용과 여행 전중후 및 일별 합계를 계산한다', () {
    final result = calculator.calculate(
      trip: trip,
      expenses: <ExpenseEntry>[
        expense(
          id: 'hotel',
          date: DateTime(2026, 8, 20),
          categoryCode: 'A',
          amount: 210000,
        ),
        expense(
          id: 'train',
          date: DateTime(2026, 9, 3, 22),
          categoryCode: 'T',
          amount: 30000,
        ),
        expense(
          id: 'meal',
          date: DateTime(2026, 9, 5),
          categoryCode: 'F',
          amount: 60000,
          paymentCode: '_c',
        ),
        expense(
          id: 'settlement',
          date: DateTime(2026, 9, 8),
          categoryCode: 'T',
          amount: 15000,
        ),
        expense(
          id: 'other-trip',
          date: DateTime(2026, 9, 4),
          categoryCode: 'F',
          amount: 999999,
          tripId: 'trip-b',
        ),
      ],
    );

    expect(result.totalExpense, 315000);
    expect(result.expenseCount, 4);
    expect(result.tripDayCount, 3);
    expect(result.averagePerTripDay, 105000);
    expect(result.beforeTripExpense, 210000);
    expect(result.duringTripExpense, 90000);
    expect(result.afterTripExpense, 15000);
    expect(result.transportExpense, 45000);
    expect(result.accommodationExpense, 210000);
    expect(result.remainingBudget, 285000);
    expect(result.budgetUsagePercent, closeTo(52.5, 0.001));
    expect(result.dailyAmounts.map((item) => item.amount), <int>[
      30000,
      0,
      60000,
    ]);
    expect(result.categoryBreakdown.first.code, 'A');
    expect(result.paymentMethodBreakdown, hasLength(2));
  });

  test('여행 시작일과 종료일을 기간 중으로 분류한다', () {
    expect(
      calculator.timingOf(DateTime(2026, 9, 3, 23, 59), trip),
      TravelExpenseTiming.during,
    );
    expect(
      calculator.timingOf(DateTime(2026, 9, 5), trip),
      TravelExpenseTiming.during,
    );
  });

  test('예산과 지출이 없어도 안전한 0 결과를 반환한다', () {
    final noBudgetTrip = Trip.create(
      id: 'trip-empty',
      name: '당일 여행',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 1),
    );

    final result = calculator.calculate(
      trip: noBudgetTrip,
      expenses: const <ExpenseEntry>[],
    );

    expect(result.totalExpense, 0);
    expect(result.tripDayCount, 1);
    expect(result.averagePerTripDay, 0);
    expect(result.budget, isNull);
    expect(result.remainingBudget, isNull);
    expect(result.budgetUsagePercent, isNull);
    expect(result.dailyAmounts.single.amount, 0);
    expect(result.categoryBreakdown, isEmpty);
  });

  test('예산 초과 시 남은 예산을 음수로 반환한다', () {
    final result = calculator.calculate(
      trip: trip,
      expenses: <ExpenseEntry>[
        expense(
          id: 'large',
          date: DateTime(2026, 9, 4),
          categoryCode: 'E',
          amount: 700000,
        ),
      ],
    );

    expect(result.remainingBudget, -100000);
    expect(result.budgetUsagePercent, closeTo(116.666, 0.01));
  });
}
