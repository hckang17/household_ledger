import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/services/database/income_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'v1 migration preserves rows and repeated opens; dates move across months',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp(
        'income_migration_',
      );
      await databaseFactory.setDatabasesPath(directory.path);
      final path = '${directory.path}/household_income.db';
      final old = await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE income_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, earnedAt TEXT NOT NULL, amount INTEGER NOT NULL, description TEXT NOT NULL)',
          );
          await db.insert('income_entries', {
            'id': 7,
            'earnedAt': '2024-02-01T00:00:00.000',
            'amount': 1234,
            'description': 'salary',
          });
        },
      );
      await old.close();
      final service = IncomeDatabaseService();
      final original = (await service.loadAllIncomes()).single;
      expect(original.category, IncomeCategory.regular);
      expect(original.id, 7);
      expect(original.amount, 1234);
      expect(original.description, 'salary');
      expect(original.earnedAt, DateTime(2024, 2, 1));
      await service.upsertIncome(
        original.copyWith(
          earnedAt: DateTime(2024, 2, 29),
          category: IncomeCategory.additional,
        ),
      );
      expect(
        (await service.loadIncomesByMonth(
          DateTime(2024, 2),
        )).single.earnedAt.day,
        29,
      );
      await service.upsertIncome(
        original.copyWith(
          earnedAt: DateTime(2025, 1, 31),
          category: IncomeCategory.gift,
        ),
      );
      expect(await service.loadIncomesByMonth(DateTime(2024, 2)), isEmpty);
      expect(
        (await service.loadIncomesByMonth(DateTime(2025, 1))).single.category,
        IncomeCategory.gift,
      );
      await (await openDatabase(path)).close();
      expect(
        (await IncomeDatabaseService().loadAllIncomes()).single.category,
        IncomeCategory.gift,
      );
      await (await openDatabase(path)).close();
      await deleteDatabase(path);
      final fresh = IncomeDatabaseService();
      expect(await fresh.loadAllIncomes(), isEmpty);
      for (final category in IncomeCategory.values) {
        await fresh.upsertIncome(
          IncomeEntry.create(
            earnedAt: DateTime(2025, 1, 31),
            amount: 1,
            description: category.name,
            category: category,
          ),
        );
      }
      expect(
        (await fresh.loadAllIncomes()).map((e) => e.category).toSet(),
        IncomeCategory.values.toSet(),
      );
      await (await openDatabase(path)).close();
      await directory.delete(recursive: true);
    },
  );
}
