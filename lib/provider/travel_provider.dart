import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/data_manage_provider.dart';
import 'package:household_ledger/provider/travel_summary_provider.dart';
import 'package:household_ledger/services/database/travel_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 여행 목록과 현재 여행 모드 선택을 보관한다.
class TravelState {
  const TravelState({required this.trips, this.activeTripId});

  final List<Trip> trips;
  final String? activeTripId;

  bool get isTravelModeOn => activeTripId != null;

  Trip? get activeTrip {
    for (final trip in trips) {
      if (trip.id == activeTripId && !trip.isArchived) {
        return trip;
      }
    }
    return null;
  }

  TravelState copyWith({
    List<Trip>? trips,
    String? activeTripId,
    bool clearActiveTrip = false,
  }) {
    return TravelState(
      trips: trips ?? this.trips,
      activeTripId: clearActiveTrip
          ? null
          : (activeTripId ?? this.activeTripId),
    );
  }
}

final travelProvider = AsyncNotifierProvider<TravelNotifier, TravelState>(
  TravelNotifier.new,
);

/// 여행 메타데이터와 여행 모드 ON/OFF 상태를 관리한다.
class TravelNotifier extends AsyncNotifier<TravelState> {
  TravelDatabaseService get _database {
    return ref.read(travelDatabaseServiceProvider);
  }

  @override
  Future<TravelState> build() async {
    await _database.initialize();
    final trips = await _database.loadAllTrips();
    final preferences = await SharedPreferences.getInstance();
    final storedActiveId = preferences.getString(
      TravelDatabaseService.activeTripStorageKey,
    );
    final isValid = trips.any(
      (Trip trip) => trip.id == storedActiveId && !trip.isArchived,
    );
    if (!isValid && storedActiveId != null) {
      await preferences.remove(TravelDatabaseService.activeTripStorageKey);
    }
    return TravelState(
      trips: trips,
      activeTripId: isValid ? storedActiveId : null,
    );
  }

  Future<void> selectActiveTrip(String tripId) async {
    final current = state.asData?.value;
    if (current == null ||
        !current.trips.any(
          (Trip trip) => trip.id == tripId && !trip.isArchived,
        )) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      TravelDatabaseService.activeTripStorageKey,
      tripId,
    );
    state = AsyncData(current.copyWith(activeTripId: tripId));
  }

  Future<void> turnOffTravelMode() async {
    final current = state.asData?.value;
    if (current == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(TravelDatabaseService.activeTripStorageKey);
    state = AsyncData(current.copyWith(clearActiveTrip: true));
  }

  Future<void> saveTrip(Trip trip) async {
    await _database.upsertTrip(trip);
    final current = state.asData?.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final nextTrips = <Trip>[
      ...current.trips.where((Trip item) => item.id != trip.id),
      trip,
    ];
    _sortTrips(nextTrips);
    state = AsyncData(current.copyWith(trips: nextTrips));
  }

  /// 저장 성공 후에만 여행 목록을 변경하고 모든 지출 조회를 갱신한다.
  Future<void> deleteTrip(String tripId) async {
    final current = await future;
    if (!current.trips.any((trip) => trip.id == tripId)) return;
    await ref
        .read(expenseDatabaseServiceProvider)
        .deleteTripAndReclassifyExpenses(tripId);
    final latest = state.asData?.value ?? current;
    state = AsyncData(
      latest.copyWith(
        trips: latest.trips.where((trip) => trip.id != tripId).toList(),
        clearActiveTrip: latest.activeTripId == tripId,
      ),
    );
    ref.invalidate(monthlyExpensesProvider);
    ref.invalidate(rangeExpensesProvider);
    ref.invalidate(travelExpensesProvider);
    ref.invalidate(travelExpenseTotalsProvider);
    ref.invalidate(ledgerProvider);
    ref.invalidate(dataManageProvider);
    // 삭제된 ID는 build에서도 무효화한다. 설정 저장 실패가 이미 완료된
    // DB 삭제를 실패로 표시하거나 메모리 여행 모드를 되살리지 않게 한다.
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getString(TravelDatabaseService.activeTripStorageKey) ==
          tripId) {
        await preferences.remove(TravelDatabaseService.activeTripStorageKey);
      }
    } catch (_) {
      // 다음 초기화에서 존재하지 않는 활성 여행 ID를 다시 정리한다.
    }
  }

  Future<void> setArchived(Trip trip, bool archived) async {
    final next = trip.copyWith(
      archivedAt: archived ? DateTime.now() : null,
      clearArchivedAt: !archived,
    );
    await _database.upsertTrip(next);
    final current = state.asData?.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final shouldTurnOff = archived && current.activeTripId == trip.id;
    if (shouldTurnOff) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(TravelDatabaseService.activeTripStorageKey);
    }
    final nextTrips = <Trip>[
      ...current.trips.where((Trip item) => item.id != trip.id),
      next,
    ];
    _sortTrips(nextTrips);
    state = AsyncData(
      current.copyWith(trips: nextTrips, clearActiveTrip: shouldTurnOff),
    );
  }

  void _sortTrips(List<Trip> trips) {
    trips.sort((Trip left, Trip right) {
      if (left.isArchived != right.isArchived) {
        return left.isArchived ? 1 : -1;
      }
      return right.startDate.compareTo(left.startDate);
    });
  }
}
