import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/trip.dart';
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

final travelDatabaseServiceProvider = Provider<TravelDatabaseService>((
  Ref ref,
) {
  return TravelDatabaseService.instance;
});

final travelProvider = AsyncNotifierProvider<TravelNotifier, TravelState>(
  TravelNotifier.new,
);

/// 여행 메타데이터와 여행 모드 ON/OFF 상태를 관리한다.
class TravelNotifier extends AsyncNotifier<TravelState> {
  static const String _activeTripStorageKey = 'household_ledger_active_trip_id';

  TravelDatabaseService get _database {
    return ref.read(travelDatabaseServiceProvider);
  }

  @override
  Future<TravelState> build() async {
    await _database.initialize();
    final trips = await _database.loadAllTrips();
    final preferences = await SharedPreferences.getInstance();
    final storedActiveId = preferences.getString(_activeTripStorageKey);
    final isValid = trips.any(
      (Trip trip) => trip.id == storedActiveId && !trip.isArchived,
    );
    if (!isValid && storedActiveId != null) {
      await preferences.remove(_activeTripStorageKey);
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
    await preferences.setString(_activeTripStorageKey, tripId);
    state = AsyncData(current.copyWith(activeTripId: tripId));
  }

  Future<void> turnOffTravelMode() async {
    final current = state.asData?.value;
    if (current == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_activeTripStorageKey);
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
      await preferences.remove(_activeTripStorageKey);
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
