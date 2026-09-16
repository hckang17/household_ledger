@TestOn('vm')
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/services/local_storage_service.dart';
import 'package:household_ledger/services/database/travel_database_service.dart';
import 'package:household_ledger/services/imexporting_file/backup_journal.dart';
import 'package:household_ledger/services/imexporting_file/backup_restore_data.dart';
import 'package:household_ledger/services/imexporting_file/backup_restore_service.dart';
import 'package:household_ledger/services/imexporting_file/data_im_export_service.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FailingJournal extends BackupJournal {
  FailingJournal(Directory directory) : super(directory: directory);
  @override
  Future<void> save(BackupRestoreData data) async =>
      throw FileSystemException('no space');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late BackupJournal journal;
  late BackupRestoreService restore;
  late Database incomeDb;

  BackupRestoreData data(String id) => BackupRestoreData(
    expenses: [
      ExpenseEntry.create(
        id: id,
        spentAt: DateTime(2026, 9, 15),
        categoryCode: 'F',
        subcategoryCode: 't',
        tripId: id,
        description: 'expense',
        amount: 1234,
      ),
    ],
    fixedExpenses: [
      FixedExpense.create(
        id: id,
        appliedAt: DateTime(2026, 9),
        categoryCode: 'A',
        description: 'rent',
        amount: 800000,
      ),
    ],
    incomes: [
      IncomeEntry.create(
        id: id == 'old' ? 1 : 2,
        earnedAt: DateTime(2026, 9),
        amount: 3000000,
        description: id,
      ),
    ],
    trips: [
      Trip.create(
        id: id,
        name: id,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      ),
    ],
    preferences: {
      LocalStorageService.storageKey: '{"marker":"$id"}',
      TravelDatabaseService.activeTripStorageKey: id,
      'tutorial_completed': id == 'old',
      'tutorial_version': id == 'old' ? 1 : 2,
    },
  );

  test(
    'silently ignored SQLite row fails verification and restores original data',
    () async {
      final before = (await restore.capture()).toJson();
      await incomeDb.execute(
        "CREATE TRIGGER fail_income BEFORE INSERT ON income_entries WHEN NEW.description = 'new' BEGIN SELECT RAISE(IGNORE); END",
      );
      await expectLater(restore.replace(data('new')), throwsStateError);
      expect((await restore.capture()).toJson(), before);
    },
  );

  test(
    'ID-less legacy incomes receive distinct IDs without collisions',
    () async {
      final target = data('new');
      target.incomes.addAll([
        IncomeEntry.create(
          earnedAt: DateTime(2026, 9),
          amount: 10,
          description: 'a',
        ),
        IncomeEntry.create(
          earnedAt: DateTime(2026, 9),
          amount: 20,
          description: 'b',
        ),
      ]);
      await restore.replace(target);
      final saved = (await restore.capture()).incomes;
      expect(saved.map((e) => e.id).toSet().length, 3);
      expect(saved.fold<int>(0, (sum, e) => sum + e.amount), 3000030);
    },
  );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('ledger_restore_test_');
    await databaseFactory.setDatabasesPath(directory.path);
    journal = BackupJournal(directory: directory);
    restore = BackupRestoreService(journal: journal);
    SharedPreferences.setMockInitialValues({});
    await restore.capture();
    incomeDb = await openDatabase('${directory.path}/household_income.db');
  });
  setUp(() async {
    await incomeDb.execute('DROP TRIGGER IF EXISTS fail_income');
    await journal.clear();
    SharedPreferences.setMockInitialValues({});
    await restore.replace(data('old'));
  });
  tearDownAll(() async {
    for (final name in [
      'household_ledger.db',
      'household_income.db',
      'household_fixed_expense.db',
      'household_travel.db',
    ]) {
      await (await openDatabase('${directory.path}/$name')).close();
    }
    await directory.delete(recursive: true);
  });

  test(
    'successful replacement verifies every store and clears journal',
    () async {
      final target = data('new');
      await restore.replace(target);
      expect((await restore.capture()).toJson(), target.toJson());
      expect(await journal.read(), isNull);
    },
  );
  test(
    'SQLite failure after earlier DB writes restores all original records and settings',
    () async {
      final before = (await restore.capture()).toJson();
      await incomeDb.execute(
        "CREATE TRIGGER fail_income BEFORE INSERT ON income_entries WHEN NEW.description = 'new' BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(restore.replace(data('new')), throwsA(anything));
      expect((await restore.capture()).toJson(), before);
      expect(await journal.read(), isNull);
    },
  );
  test(
    'finalization failure also rolls back exact settings and active trip',
    () async {
      final before = (await restore.capture()).toJson();
      await expectLater(
        restore.replace(
          data('new'),
          finalize: () async {
            throw StateError('failed');
          },
        ),
        throwsStateError,
      );
      expect((await restore.capture()).toJson(), before);
    },
  );
  test('snapshot failure leaves every store untouched', () async {
    final before = (await restore.capture()).toJson();
    final failing = BackupRestoreService(journal: FailingJournal(directory));
    await expectLater(
      failing.replace(data('new')),
      throwsA(isA<FileSystemException>()),
    );
    expect((await restore.capture()).toJson(), before);
  });
  test(
    'fresh service recovers an interrupted partial replacement idempotently',
    () async {
      final before = await restore.capture();
      await journal.save(before);
      await restore.expenses.deleteAllExpenses();
      await restore.trips.replaceAllTrips([]);
      await (await SharedPreferences.getInstance()).remove(
        LocalStorageService.storageKey,
      );
      final restarted = BackupRestoreService(
        journal: BackupJournal(directory: directory),
      );
      await restarted.recover();
      await restarted.recover();
      expect((await restarted.capture()).toJson(), before.toJson());
    },
  );
  test(
    'rollback failure keeps journal; next startup can finish recovery',
    () async {
      final before = (await restore.capture()).toJson();
      await incomeDb.execute(
        "CREATE TRIGGER fail_income BEFORE INSERT ON income_entries BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      await expectLater(restore.replace(data('new')), throwsA(anything));
      expect(await journal.read(), isNotNull);
      await incomeDb.execute('DROP TRIGGER fail_income');
      await BackupRestoreService(journal: journal).recover();
      expect((await restore.capture()).toJson(), before);
    },
  );
  test('duplicate IDs passed directly to restore never start writes', () async {
    final before = (await restore.capture()).toJson();
    final target = data('new');
    target.incomes.add(target.incomes.single);
    await expectLater(restore.replace(target), throwsFormatException);
    expect((await restore.capture()).toJson(), before);
    expect(await journal.read(), isNull);
  });
  test('rejected CSV leaves existing SQLite and settings intact', () async {
    final before = (await restore.capture()).toJson();
    final service = DataImExportService();
    final csv = service.buildCsvContent(
      expenses: [],
      fixedExpenses: [],
      incomes: [],
      trips: [],
      ledgerState: LedgerState.initial(),
      email: 'test@example.com',
      passkey: 'test',
      timestamp: 'test',
    );
    final result = await service.importFromCsv(
      csvContent: csv.substring(0, csv.indexOf('[TAGS]') + 6),
      email: 'test@example.com',
      passkey: 'test',
    );
    expect(result.success, isFalse);
    expect((await restore.capture()).toJson(), before);
  });
}
