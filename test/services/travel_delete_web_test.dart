import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/services/database/expense_database_service.dart';
import 'package:household_ledger/services/database/travel_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('여러 달의 연결 지출만 평상시로 저장하고 재조회 및 재삭제한다', () async {
    final entries = [
      for (var month = 1; month <= 3; month++)
        ExpenseEntry.create(
          id: 'a-$month',
          spentAt: DateTime(2026, month, 1),
          categoryCode: 'F',
          subcategoryCode: 't',
          tripId: 'a',
          description: 'meal',
          amount: 1234,
          note: 'note',
        ),
      ExpenseEntry.create(
        id: 'b',
        spentAt: DateTime(2026, 1, 1),
        categoryCode: 'T',
        subcategoryCode: 't',
        tripId: 'b',
        description: 'train',
        amount: 500,
      ),
      ExpenseEntry.create(
        id: 'unassigned',
        spentAt: DateTime(2026, 1, 1),
        categoryCode: 'T',
        subcategoryCode: 't',
        description: 'bus',
        amount: 100,
      ),
    ];
    final trips = [
      for (final id in ['a', 'b'])
        Trip.create(
          id: id,
          name: id,
          startDate: DateTime(2026, 2, 1),
          endDate: DateTime(2026, 2, 2),
        ),
    ];
    SharedPreferences.setMockInitialValues({
      'household_ledger_expenses': jsonEncode(
        entries.map((e) => e.toJson()).toList(),
      ),
      TravelDatabaseService.webStorageKey: jsonEncode(
        trips.map((t) => t.toJson()).toList(),
      ),
    });
    await ExpenseDatabaseService().deleteTripAndReclassifyExpenses('a');
    final restored = await ExpenseDatabaseService().loadAllExpenses();
    for (final original in entries) {
      final actual = restored.singleWhere((e) => e.id == original.id);
      final expected = original.toJson();
      if (original.tripId == 'a') {
        expected['tripId'] = null;
        expected['subcategoryCode'] = '_';
      }
      expect(actual.toJson(), expected);
    }
    expect(
      (await TravelDatabaseService.instance.loadAllTrips()).single.id,
      'b',
    );
    await ExpenseDatabaseService().deleteTripAndReclassifyExpenses('a');
    expect(await ExpenseDatabaseService().loadExpensesByTrip('a'), isEmpty);
    expect(await ExpenseDatabaseService().loadAllExpenses(), hasLength(5));
  }, skip: !kIsWeb);

  test('잘못된 여행 JSON이면 지출을 변경하지 않는다', () async {
    SharedPreferences.setMockInitialValues({
      'household_ledger_expenses': '[]',
      TravelDatabaseService.webStorageKey: 'invalid',
    });
    await expectLater(
      ExpenseDatabaseService().deleteTripAndReclassifyExpenses('a'),
      throwsFormatException,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        'household_ledger_expenses',
      ),
      '[]',
    );
  }, skip: !kIsWeb);
}
