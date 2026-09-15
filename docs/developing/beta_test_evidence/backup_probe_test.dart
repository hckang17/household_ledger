// Observational audit: results are written as evidence, not product pass/fail assertions.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/services/imexporting_file/data_im_export_service.dart';
import 'package:household_ledger/services/database/income_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:logger/logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('audit incomplete backup and duplicate income restoration', () async {
    Logger.level = Level.off;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final temp = await Directory.systemTemp.createTemp('ledger_beta_backup_');
    await databaseFactory.setDatabasesPath(temp.path);
    final service = DataImExportService();
    final csv = service.buildCsvContent(
      expenses: [
        ExpenseEntry.create(
          id: 'one',
          spentAt: DateTime(2026, 9, 1),
          categoryCode: 'F',
          subcategoryCode: '_',
          description: 'test',
          amount: 1200,
        ),
      ],
      fixedExpenses: [],
      incomes: [
        IncomeEntry.create(
          id: 1,
          earnedAt: DateTime(2026, 9, 1),
          amount: 1000,
          description: 'salary',
        ),
        IncomeEntry.create(
          id: 2,
          earnedAt: DateTime(2026, 9, 2),
          amount: 2000,
          description: 'bonus',
        ),
      ],
      trips: [],
      ledgerState: LedgerState.initial(),
      email: 'beta@example.com',
      passkey: 'beta',
      timestamp: '20260914',
    );
    final probes = <String, String>{
      'valid': csv,
      'truncated_after_tags_marker': csv.substring(
        0,
        csv.indexOf('[TAGS]') + '[TAGS]'.length,
      ),
      'empty_expenses_section': csv.replaceFirst(
        RegExp(r'\[EXPENSES\][\s\S]*?\[TRIPS\]'),
        '[EXPENSES]\n[TRIPS]',
      ),
      'duplicate_income_id': csv.replaceFirst('2,2026-09-02', '1,2026-09-02'),
      'modified_amount': csv.replaceFirst(',1200,', ',999999,'),
    };
    final results = <Map<String, Object?>>[];
    for (final probe in probes.entries) {
      final result = await service.importFromCsv(
        csvContent: probe.value,
        email: 'beta@example.com',
        passkey: 'beta',
      );
      final evidence = <String, Object?>{
        'case': probe.key,
        'success': result.success,
        'error': result.errorKey,
        'expenseCount': result.expenses.length,
        'incomeCount': result.incomes.length,
        'tagCount': result.ledgerState?.metadataTags.length,
      };
      if (probe.key == 'duplicate_income_id' && result.success) {
        final db = IncomeDatabaseService();
        await db.upsertIncomes(result.incomes);
        final saved = await db.loadAllIncomes();
        evidence['storedIncomeCount'] = saved.length;
        evidence['storedIncomeTotal'] = saved.fold<int>(
          0,
          (a, b) => a + b.amount,
        );
      }
      results.add(evidence);
    }
    await File(
      'docs/developing/beta_test_evidence/backup_probe.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
  });
}
