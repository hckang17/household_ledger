@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/services/database/expense_database_service.dart';
import 'package:household_ledger/services/database/travel_database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Database expenseDb;
  late Database travelDb;
  final expenses = ExpenseDatabaseService();
  final travel = TravelDatabaseService.instance;

  Trip trip(String id) => Trip.create(
    id: id,
    name: id,
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 1, 3),
    archivedAt: DateTime(2026, 1, 4),
  );

  ExpenseEntry entry(String id, String? tripId, DateTime date) =>
      ExpenseEntry.create(
        id: id,
        spentAt: date,
        categoryCode: 'F',
        subcategoryCode: 't',
        tripId: tripId,
        description: 'meal',
        diningOccasionCode: 'l',
        amount: 1234,
        note: 'memo',
      );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp(
      'household_travel_delete_test_',
    );
    await databaseFactory.setDatabasesPath(directory.path);
    await expenses.loadAllExpenses();
    await travel.initialize();
    expenseDb = await openDatabase(
      path.join(directory.path, 'household_ledger.db'),
    );
    travelDb = await openDatabase(
      path.join(directory.path, TravelDatabaseService.databaseName),
    );
  });

  tearDownAll(() async {
    await expenseDb.close();
    await travelDb.close();
    await directory.delete(recursive: true);
  });

  setUp(() async {
    await expenseDb.delete('expense_entries');
    await travelDb.execute('DROP TRIGGER IF EXISTS prevent_delete');
    await travelDb.delete('trips');
  });

  test('보관 여행의 연도·월 경계 지출을 전환하고 다른 지출의 모든 필드를 유지한다', () async {
    await travel.upsertTrip(trip('a'));
    await travel.upsertTrip(trip('b'));
    final originals = [
      entry('before', 'a', DateTime(2025, 12, 31)),
      entry('during', 'a', DateTime(2026, 1, 2)),
      entry('after', 'a', DateTime(2026, 2, 28)),
      entry('other', 'b', DateTime(2026, 1, 2)),
      entry('unassigned', null, DateTime(2026, 1, 2)),
    ];
    await expenses.upsertExpenses(originals);
    await expenses.deleteTripAndReclassifyExpenses('a');
    final restored = await ExpenseDatabaseService().loadAllExpenses();
    for (final original in originals) {
      final expected = original.toJson();
      if (original.tripId == 'a') {
        expected['subcategoryCode'] = '_';
        expected['tripId'] = null;
      }
      expect(
        restored.singleWhere((e) => e.id == original.id).toJson(),
        expected,
      );
    }
    expect((await travel.loadAllTrips()).single.id, 'b');
    await expenses.deleteTripAndReclassifyExpenses('a');
    expect(await expenses.loadAllExpenses(), hasLength(5));
  });

  test('여행 삭제가 실패하면 먼저 변경한 지출도 롤백하고 재시도할 수 있다', () async {
    await travel.upsertTrip(trip('a'));
    final original = entry('expense', 'a', DateTime(2026, 1, 2));
    await expenses.upsertExpense(original);
    await travelDb.execute('''
      CREATE TRIGGER prevent_delete BEFORE DELETE ON trips
      BEGIN SELECT RAISE(ABORT, 'test failure'); END
    ''');
    await expectLater(
      expenses.deleteTripAndReclassifyExpenses('a'),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      (await expenses.loadAllExpenses()).single.toJson(),
      original.toJson(),
    );
    expect((await travel.loadAllTrips()).single.id, 'a');
    await travelDb.execute('DROP TRIGGER prevent_delete');
    await expenses.deleteTripAndReclassifyExpenses('a');
    expect(await travel.loadAllTrips(), isEmpty);
    expect((await expenses.loadAllExpenses()).single.subcategoryCode, '_');
  });

  test('지출이 없는 여행도 삭제할 수 있다', () async {
    await travel.upsertTrip(trip('empty'));
    await expenses.deleteTripAndReclassifyExpenses('empty');
    expect(await travel.loadAllTrips(), isEmpty);
    expect(await expenses.loadAllExpenses(), isEmpty);
  });
}
