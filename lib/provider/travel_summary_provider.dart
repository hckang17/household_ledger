import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/features/travel/calculators/travel_summary_calculator.dart';
import 'package:household_ledger/features/travel/models/travel_summary.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';

/// 특정 여행에 연결된 모든 지출을 조회한다.
final travelExpensesProvider = FutureProvider.autoDispose
    .family<List<ExpenseEntry>, String>((Ref ref, String tripId) async {
      if (tripId.trim().isEmpty) return const <ExpenseEntry>[];
      return ref
          .read(expenseDatabaseServiceProvider)
          .loadExpensesByTrip(tripId);
    });

/// 여행 목록 카드에서 사용할 여행별 총 지출을 한 번에 조회한다.
final travelExpenseTotalsProvider =
    FutureProvider.autoDispose<Map<String, int>>(
      (Ref ref) =>
          ref.read(expenseDatabaseServiceProvider).loadExpenseTotalsByTrip(),
    );

/// 특정 여행과 연결 지출을 조합해 여행 요약을 계산한다.
final travelSummaryProvider = FutureProvider.autoDispose
    .family<TravelSummary?, String>((Ref ref, String tripId) async {
      final travelState = await ref.watch(travelProvider.future);
      Trip? selectedTrip;
      for (final trip in travelState.trips) {
        if (trip.id == tripId) {
          selectedTrip = trip;
          break;
        }
      }
      if (selectedTrip == null) return null;

      final expenses = await ref.watch(travelExpensesProvider(tripId).future);
      return const TravelSummaryCalculator().calculate(
        trip: selectedTrip,
        expenses: expenses,
      );
    });
