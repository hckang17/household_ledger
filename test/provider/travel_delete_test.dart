import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';
import 'package:household_ledger/services/database/expense_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _trip = Trip.create(
  id: 'a',
  name: '여행',
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 1, 3),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final activeId in ['a', 'other']) {
    test('삭제 성공 후 목록 및 활성 여행 갱신: $activeId', () async {
      SharedPreferences.setMockInitialValues({
        'household_ledger_active_trip_id': activeId,
      });
      final database = _Database();
      final container = ProviderContainer(
        overrides: [
          expenseDatabaseServiceProvider.overrideWithValue(database),
          travelProvider.overrideWith(() => _Notifier(activeId)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(travelProvider.future);
      final deleting = container.read(travelProvider.notifier).deleteTrip('a');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(travelProvider).requireValue.trips, hasLength(2));
      database.completion.complete();
      await deleting;
      expect(database.deletedId, 'a');
      final state = container.read(travelProvider).requireValue;
      expect(state.trips.single.id, 'other');
      expect(state.activeTripId, activeId == 'a' ? null : 'other');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('household_ledger_active_trip_id'),
        activeId == 'a' ? null : 'other',
      );
      await container.read(travelProvider.notifier).deleteTrip('a');
      expect(database.calls, 1);
    });
  }

  test('저장 실패 시 여행과 활성 모드를 유지한다', () async {
    SharedPreferences.setMockInitialValues({
      'household_ledger_active_trip_id': 'a',
    });
    final database = _Database();
    final container = ProviderContainer(
      overrides: [
        expenseDatabaseServiceProvider.overrideWithValue(database),
        travelProvider.overrideWith(() => _Notifier('a')),
      ],
    );
    addTearDown(container.dispose);
    await container.read(travelProvider.future);
    final result = container.read(travelProvider.notifier).deleteTrip('a');
    final assertion = expectLater(result, throwsStateError);
    database.completion.completeError(StateError('storage failure'));
    await assertion;
    expect(container.read(travelProvider).requireValue.trips, hasLength(2));
    expect(container.read(travelProvider).requireValue.activeTripId, 'a');
    expect(
      (await SharedPreferences.getInstance()).getString(
        'household_ledger_active_trip_id',
      ),
      'a',
    );
  });
}

class _Database extends ExpenseDatabaseService {
  final completion = Completer<void>();
  String? deletedId;
  int calls = 0;

  @override
  Future<void> deleteTripAndReclassifyExpenses(String tripId) async {
    calls++;
    deletedId = tripId;
    await completion.future;
  }
}

class _Notifier extends TravelNotifier {
  _Notifier(this.activeId);
  final String activeId;

  @override
  Future<TravelState> build() async => TravelState(
    trips: [
      _trip,
      Trip.create(
        id: 'other',
        name: 'other',
        startDate: _trip.startDate,
        endDate: _trip.endDate,
      ),
    ],
    activeTripId: activeId,
  );
}
