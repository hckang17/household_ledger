import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';
import 'package:household_ledger/provider/travel_summary_provider.dart';
import 'package:household_ledger/services/database/expense_database_service.dart';
import 'package:test/test.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-a',
    name: '제주 여행',
    startDate: DateTime(2026, 9, 3),
    endDate: DateTime(2026, 9, 5),
  );

  test('여행과 연결 지출을 조합해 같은 ID의 요약을 만든다', () async {
    final database = _FakeExpenseDatabaseService(<ExpenseEntry>[
      ExpenseEntry.create(
        id: 'expense-a',
        spentAt: DateTime(2026, 9, 4),
        categoryCode: 'T',
        subcategoryCode: 't',
        tripId: trip.id,
        description: '공항철도',
        amount: 12000,
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        expenseDatabaseServiceProvider.overrideWithValue(database),
        travelProvider.overrideWith(() => _FakeTravelNotifier(<Trip>[trip])),
      ],
    );
    addTearDown(container.dispose);

    final summary = await container.read(travelSummaryProvider(trip.id).future);

    expect(summary?.totalExpense, 12000);
    expect(summary?.transportExpense, 12000);
    expect(database.requestedTripIds, <String>[trip.id]);
  });

  test('존재하지 않는 여행 ID는 DB를 조회하지 않고 null을 반환한다', () async {
    final database = _FakeExpenseDatabaseService(const <ExpenseEntry>[]);
    final container = ProviderContainer(
      overrides: [
        expenseDatabaseServiceProvider.overrideWithValue(database),
        travelProvider.overrideWith(() => _FakeTravelNotifier(<Trip>[trip])),
      ],
    );
    addTearDown(container.dispose);

    final summary = await container.read(
      travelSummaryProvider('missing').future,
    );

    expect(summary, isNull);
    expect(database.requestedTripIds, isEmpty);
  });
}

class _FakeExpenseDatabaseService extends ExpenseDatabaseService {
  _FakeExpenseDatabaseService(this.expenses);

  final List<ExpenseEntry> expenses;
  final List<String> requestedTripIds = <String>[];

  @override
  Future<List<ExpenseEntry>> loadExpensesByTrip(String tripId) async {
    requestedTripIds.add(tripId);
    return expenses
        .where((ExpenseEntry entry) => entry.tripId == tripId)
        .toList(growable: false);
  }
}

class _FakeTravelNotifier extends TravelNotifier {
  _FakeTravelNotifier(this.trips);

  final List<Trip> trips;

  @override
  Future<TravelState> build() async => TravelState(trips: trips);
}
