import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/services/local_storage_service.dart';
import 'package:household_ledger/services/mock_data_service.dart';
import 'package:household_ledger/services/database/expense_database_service.dart';
import 'package:household_ledger/services/database/fixed_expense_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:logger/logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('tutorial cleanup after service instance recreation', (
    tester,
  ) async {
    Logger.level = Level.off;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // This audit test is deliberately stored with its report.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final expense = ExpenseDatabaseService();
    final fixed = FixedExpenseDatabaseService();
    final container = ProviderContainer(
      overrides: [
        expenseDatabaseServiceProvider.overrideWithValue(expense),
        fixedExpenseDatabaseServiceProvider.overrideWithValue(fixed),
      ],
    );
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp(
        'ledger_beta_tutorial_',
      );
      await databaseFactory.setDatabasesPath(dir.path);
      final state = LedgerState.initial();
      await LocalStorageService().saveState(
        state.copyWith(
          settings: state.settings.copyWith(onboardingCompleted: true),
        ),
      );
      await container.read(ledgerProvider.future);
    });
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      await MockDataService().insertMockData(widgetRef);
      final before = await expense.loadAllExpenses();
      // A new process recreates this in-memory service. Keep the same persisted DB.
      await MockDataService().cleanupMockData(widgetRef);
      final after = await expense.loadAllExpenses();
      await File(
        'docs/developing/beta_test_evidence/tutorial_restart_probe.json',
      ).writeAsString(
        jsonEncode({
          'inserted': before.length,
          'remainingAfterFreshServiceCleanup': after.length,
          'remainingMockTagged': after
              .where((e) => e.note == MockDataService.mockTag)
              .length,
          'remainingTotal': after.fold<int>(0, (sum, e) => sum + e.amount),
          'method':
              'WidgetRef and real SQLite; service recreation simulates loss of in-memory IDs, not a native process-restart test',
        }),
      );
    });
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
