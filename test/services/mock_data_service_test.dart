import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/services/database/expense_database_service.dart';
import 'package:household_ledger/services/database/fixed_expense_database_service.dart';
import 'package:household_ledger/services/local_storage_service.dart';
import 'package:household_ledger/services/mock_data_service.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('서비스 재생성 뒤에도 튜토리얼 데이터만 반복 안전하게 정리한다', (tester) async {
    Logger.level = Level.off;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    late Directory directory;
    late ExpenseDatabaseService database;
    late FixedExpenseDatabaseService fixedDatabase;
    late ProviderContainer container;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('ledger_mock_cleanup_');
      await databaseFactory.setDatabasesPath(directory.path);
      database = ExpenseDatabaseService();
      fixedDatabase = FixedExpenseDatabaseService();
      container = ProviderContainer(
        overrides: [
          expenseDatabaseServiceProvider.overrideWithValue(database),
          fixedExpenseDatabaseServiceProvider.overrideWithValue(fixedDatabase),
        ],
      );
      final initial = LedgerState.initial();
      await LocalStorageService().saveState(
        initial.copyWith(
          settings: initial.settings.copyWith(onboardingCompleted: true),
        ),
      );
      await container.read(ledgerProvider.future);
    });
    addTearDown(() async {
      await database.closeForTesting();
      await fixedDatabase.closeForTesting();
      await directory.delete(recursive: true);
    });
    addTearDown(container.dispose);

    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );

    await tester.runAsync(() async {
      final userEntry = ExpenseEntry.create(
        id: 'user-entry',
        spentAt: DateTime.now(),
        categoryCode: 'T',
        description: '교통비',
        amount: 3000,
        note: '사용자 기록',
      );
      await container.read(ledgerProvider.notifier).addExpense(userEntry);
      await MockDataService().insertMockData(widgetRef);
      expect(
        (await database.loadAllExpenses()).where(
          (entry) => entry.id.startsWith(MockDataService.mockIdPrefix),
        ),
        hasLength(2),
      );

      // 프로세스 재생성처럼 새 서비스 인스턴스로 정리한다.
      await MockDataService().cleanupMockData(widgetRef);
      await MockDataService().cleanupMockData(widgetRef);

      final remaining = await database.loadAllExpenses();
      expect(remaining.map((entry) => entry.id), <String>['user-entry']);
      expect(
        container
            .read(ledgerProvider)
            .requireValue
            .expenses
            .map((entry) => entry.id),
        <String>['user-entry'],
      );
    });
  });

  test('구버전 note 표식 데이터는 정리하고 일반 데이터는 보존한다', () async {
    Logger.level = Level.off;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final directory = await Directory.systemTemp.createTemp(
      'ledger_legacy_mock_cleanup_',
    );
    await databaseFactory.setDatabasesPath(directory.path);
    final database = ExpenseDatabaseService();
    addTearDown(() async {
      await database.closeForTesting();
      await directory.delete(recursive: true);
    });
    await database.upsertExpenses(<ExpenseEntry>[
      ExpenseEntry.create(
        id: 'legacy',
        spentAt: DateTime(2026, 9, 1),
        categoryCode: 'T',
        description: 'legacy mock',
        amount: 1,
        note: MockDataService.mockTag,
      ),
      ExpenseEntry.create(
        id: 'normal',
        spentAt: DateTime(2026, 9, 1),
        categoryCode: 'T',
        description: 'normal',
        amount: 1,
      ),
    ]);

    final deleted = await database.deleteTutorialMockExpenses(
      idPrefix: MockDataService.mockIdPrefix,
      legacyNoteMarker: MockDataService.mockTag,
    );

    expect(deleted, 1);
    expect((await database.loadAllExpenses()).single.id, 'normal');
  });
}
