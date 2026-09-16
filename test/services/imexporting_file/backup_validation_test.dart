import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/services/imexporting_file/data_im_export_service.dart';

void main() {
  final service = DataImExportService();
  String backup() => service.buildCsvContent(
    expenses: [],
    fixedExpenses: [],
    trips: [],
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
    ledgerState: LedgerState.initial(),
    email: 'test@example.com',
    passkey: 'test',
    timestamp: '20260915',
  );
  Future<ImportResult> parse(String csv) => service.importFromCsv(
    csvContent: csv,
    email: 'test@example.com',
    passkey: 'test',
  );

  final corruptions = <String, String Function(String)>{
    'missing version': (s) => s.replaceFirst('version,3.0\n', ''),
    'truncated tags': (s) => s.substring(0, s.indexOf('[TAGS]') + 6),
    'missing expense header': (s) =>
        s.replaceFirst(RegExp(r'\[EXPENSES\]\n[^\n]+'), '[EXPENSES]'),
    'duplicate income id': (s) =>
        s.replaceFirst('2,2026-09-02', '1,2026-09-02'),
    'invalid income id': (s) =>
        s.replaceFirst('2,2026-09-02', 'oops,2026-09-02'),
    'overflow date': (s) => s.replaceFirst('2026-09-02', '2026-02-30'),
    'duplicate section': (s) =>
        '$s\n[INCOMES]\nid,earnedAt,amount,description\n',
    'truncated quoted record': (s) => '$s\ncategory,Z,"unfinished',
    'invalid version': (s) => s.replaceFirst('version,3.0', 'version,broken'),
    'wrong income header': (s) => s.replaceFirst(
      'id,earnedAt,amount,description',
      'id,date,amount,description',
    ),
    'missing settings body': (s) => s.replaceFirst(
      RegExp(r'\[SETTINGS\][\s\S]*?\[TAGS\]'),
      '[SETTINGS]\nkey,value\n\n[TAGS]',
    ),
  };
  for (final entry in corruptions.entries) {
    test('rejects ${entry.key} before returning any restore data', () async {
      final result = await parse(entry.value(backup()));
      expect(result.success, isFalse);
      expect(result.expenses, isEmpty);
      expect(result.incomes, isEmpty);
      expect(result.ledgerState, isNull);
    });
  }
  test('valid empty sections and two distinct incomes remain valid', () async {
    final result = await parse(backup());
    expect(result.success, isTrue);
    expect(result.expenses, isEmpty);
    expect(result.incomes.fold<int>(0, (sum, item) => sum + item.amount), 3000);
  });
  test('v1 and v2 still accept optional missing travel section', () async {
    for (final version in ['1.0', '2.0']) {
      final csv = backup()
          .replaceFirst('version,3.0', 'version,$version')
          .replaceFirst(RegExp(r'\[TRIPS\][\s\S]*?\n\n'), '');
      expect((await parse(csv)).success, isTrue);
      expect(
        (await parse(csv.replaceFirst('2,2026-09-02', '1,2026-09-02'))).success,
        isFalse,
      );
    }
  });
}
