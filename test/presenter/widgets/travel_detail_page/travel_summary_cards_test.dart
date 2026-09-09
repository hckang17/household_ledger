import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/features/travel/models/travel_summary.dart';
import 'package:household_ledger/presenter/widgets/travel_detail_page/travel_summary_cards.dart';

void main() {
  testWidgets('작은 화면과 긴 일본어 문구에서도 여행 요약을 표시한다', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TravelSummaryCards(
              summary: TravelSummary(
                totalExpense: 523000,
                expenseCount: 8,
                tripDayCount: 3,
                averagePerTripDay: 174333,
                beforeTripExpense: 250000,
                duringTripExpense: 263000,
                afterTripExpense: 10000,
                transportExpense: 80000,
                accommodationExpense: 210000,
                budget: 700000,
                remainingBudget: 177000,
                budgetUsagePercent: 74.7,
                categoryBreakdown: <TravelBreakdownItem>[],
                paymentMethodBreakdown: <TravelBreakdownItem>[],
                dailyAmounts: <TravelDailyAmount>[],
              ),
              strings: <String, String>{
                'travelTotalExpenseLabel': '旅行支出合計',
                'travelBudgetLabel': '旅行予算（任意）',
                'travelRemainingBudgetLabel': '残り予算',
                'travelDailyAverageLabel': '1日あたりの旅行支出平均',
                'travelExpenseCountLabel': '支出件数と旅行日数',
                'travelExpenseCountUnit': '件',
                'travelDayUnit': '日',
                'travelTransportExpenseLabel': '交通費',
                'travelAccommodationExpenseLabel': '宿泊費',
                'travelTimingSummaryTitle': '旅行前後の支出',
                'travelBeforeLabel': '旅行前',
                'travelDuringLabel': '旅行中',
                'travelAfterLabel': '旅行後',
              },
              currency: '¥',
            ),
          ),
        ),
      ),
    );

    expect(find.text('523,000¥'), findsOneWidget);
    expect(find.text('宿泊費'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
