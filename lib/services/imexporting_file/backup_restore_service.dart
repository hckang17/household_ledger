import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:household_ledger/services/database/expense_database_service.dart';
import 'package:household_ledger/services/database/fixed_expense_database_service.dart';
import 'package:household_ledger/services/database/income_database_service.dart';
import 'package:household_ledger/services/database/travel_database_service.dart';
import 'package:household_ledger/services/local_storage_service.dart';
import 'package:household_ledger/services/tutorial_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_journal.dart';
import 'backup_restore_data.dart';

/// 독립 DB와 설정의 교체를 조정한다. 미완료 작업은 다음 시작에 이전 상태로 되돌린다.
class BackupRestoreService {
  BackupRestoreService({
    ExpenseDatabaseService? expenses,
    FixedExpenseDatabaseService? fixedExpenses,
    IncomeDatabaseService? incomes,
    TravelDatabaseService? trips,
    BackupJournal? journal,
  }) : expenses = expenses ?? ExpenseDatabaseService(),
       fixedExpenses = fixedExpenses ?? FixedExpenseDatabaseService(),
       incomes = incomes ?? IncomeDatabaseService(),
       trips = trips ?? TravelDatabaseService.instance,
       journal = journal ?? BackupJournal();

  final ExpenseDatabaseService expenses;
  final FixedExpenseDatabaseService fixedExpenses;
  final IncomeDatabaseService incomes;
  final TravelDatabaseService trips;
  final BackupJournal journal;
  static bool busy = false;
  static const preferenceKeys = [
    LocalStorageService.storageKey,
    TravelDatabaseService.activeTripStorageKey,
    TutorialService.completedKey,
    TutorialService.versionKey,
  ];

  Future<BackupRestoreData> capture() async {
    final prefs = await SharedPreferences.getInstance();
    return BackupRestoreData(
      expenses: await expenses.loadAllExpenses(),
      fixedExpenses: await fixedExpenses.loadAllFixedExpenses(),
      incomes: await incomes.loadAllIncomes(),
      trips: await trips.loadAllTrips(),
      preferences: {for (final key in preferenceKeys) key: prefs.get(key)},
    );
  }

  Future<void> _write(BackupRestoreData data) async {
    await trips.replaceAllTrips(data.trips);
    await expenses.deleteAllExpenses();
    await expenses.upsertExpenses(data.expenses);
    await fixedExpenses.deleteAllFixedExpenses();
    await fixedExpenses.upsertFixedExpenses(data.fixedExpenses);
    await incomes.deleteAllIncomes();
    await incomes.upsertIncomes(data.incomes);
    final prefs = await SharedPreferences.getInstance();
    for (final key in preferenceKeys) {
      final value = data.preferences[key];
      final bool saved;
      if (value == null) {
        saved = await prefs.remove(key);
      } else if (value is String) {
        saved = await prefs.setString(key, value);
      } else if (value is bool) {
        saved = await prefs.setBool(key, value);
      } else if (value is int) {
        saved = await prefs.setInt(key, value);
      } else {
        throw const FormatException('Invalid saved setting');
      }
      if (!saved) throw StateError('Could not write imported settings');
    }
    final actual = (await capture()).toJson();
    final expected = data.toJson();
    // Compare complete records (and hence counts, amounts and references), independent of DB ordering.
    for (final key in ['expenses', 'fixedExpenses', 'incomes', 'trips']) {
      List<String> canonical(dynamic rows) =>
          (rows as List).map((e) => jsonEncode(e)).toList()..sort();
      if (!listEquals(canonical(actual[key]), canonical(expected[key]))) {
        throw StateError('Imported records do not match');
      }
    }
    if (!mapEquals(
      actual['preferences'] as Map,
      expected['preferences'] as Map,
    )) {
      throw StateError('Imported settings do not match');
    }
  }

  Future<void> _recover() async {
    final previous = await journal.read();
    if (previous == null) return;
    await _write(previous);
    await journal.clear();
  }

  /// runApp 및 Provider 초기화 전에 실행한다. 실패하면 복구본을 유지한다.
  Future<void> recover() async {
    if (busy) throw StateError('Import already running');
    busy = true;
    try {
      await _recover();
    } finally {
      busy = false;
    }
  }

  Future<void> replace(
    BackupRestoreData input, {
    Future<void> Function()? finalize,
  }) async {
    input.validate();
    final data = input.withIncomeIds();
    if (busy) throw StateError('Import already running');
    busy = true;
    try {
      await _recover();
      await journal.save(await capture());
      try {
        await _write(data);
        await finalize?.call();
        await journal.clear();
      } catch (_) {
        await _recover();
        rethrow;
      }
    } finally {
      busy = false;
    }
  }
}
