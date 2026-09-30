import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/data_search_filter.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/provider/data_manage_provider.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/services/database/expense_database_service.dart';
import 'package:test/test.dart';

void main() {
  ExpenseEntry expense({
    required String id,
    String subcategoryCode = '_',
    String? tripId,
  }) {
    return ExpenseEntry.create(
      id: id,
      spentAt: DateTime(2026, 9, 1),
      categoryCode: 'E',
      subcategoryCode: subcategoryCode,
      tripId: tripId,
      description: id,
      amount: 1000,
    );
  }

  test('선택한 과거 지출을 여행 소구분과 특정 여행으로 일괄 연결한다', () async {
    final database = _FakeExpenseDatabaseService(<ExpenseEntry>[
      expense(id: 'selected'),
      expense(id: 'untouched'),
    ]);
    final container = ProviderContainer(
      overrides: [expenseDatabaseServiceProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(dataManageProvider.notifier);

    notifier.setFilter(
      const DataSearchFilter(tableType: DataTableType.expense),
    );
    await notifier.search();
    notifier.toggleSelection('selected');
    await notifier.bulkChangeTags(
      subcategoryCode: 't',
      changeTripId: true,
      tripId: 'trip-a',
    );

    final selected = database.entries.firstWhere(
      (ExpenseEntry entry) => entry.id == 'selected',
    );
    final untouched = database.entries.firstWhere(
      (ExpenseEntry entry) => entry.id == 'untouched',
    );
    expect(selected.subcategoryCode, 't');
    expect(selected.tripId, 'trip-a');
    expect(untouched.subcategoryCode, '_');
    expect(container.read(dataManageProvider).selectedIds, isEmpty);
  });

  test('여행 지출을 평상시 소구분으로 바꾸면 여행 연결도 해제한다', () async {
    final database = _FakeExpenseDatabaseService(<ExpenseEntry>[
      expense(id: 'travel', subcategoryCode: 't', tripId: 'trip-a'),
    ]);
    final container = ProviderContainer(
      overrides: [expenseDatabaseServiceProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(dataManageProvider.notifier);

    notifier.setFilter(
      const DataSearchFilter(tableType: DataTableType.expense),
    );
    await notifier.search();
    notifier.selectAll();
    await notifier.bulkChangeTags(subcategoryCode: '_');

    expect(database.entries.single.subcategoryCode, '_');
    expect(database.entries.single.tripId, isNull);
  });

  test('늦게 끝난 이전 검색은 최신 검색 결과를 덮어쓰지 않는다', () async {
    final database = _QueuedExpenseDatabaseService();
    final container = ProviderContainer(
      overrides: [expenseDatabaseServiceProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(dataManageProvider.notifier);

    notifier.setFilter(
      const DataSearchFilter(
        tableType: DataTableType.expense,
        descriptionQuery: 'old',
      ),
    );
    final oldSearch = notifier.search();
    notifier.setFilter(
      const DataSearchFilter(
        tableType: DataTableType.expense,
        descriptionQuery: 'new',
      ),
    );
    final newSearch = notifier.search();

    database.requests[1].complete(<ExpenseEntry>[expense(id: 'new')]);
    await newSearch;
    database.requests[0].complete(<ExpenseEntry>[expense(id: 'old')]);
    await oldSearch;

    expect(
      container.read(dataManageProvider).expenses.map((entry) => entry.id),
      <String>['new'],
    );
  });
}

class _FakeExpenseDatabaseService extends ExpenseDatabaseService {
  _FakeExpenseDatabaseService(List<ExpenseEntry> initial)
    : entries = <ExpenseEntry>[...initial];

  final List<ExpenseEntry> entries;

  @override
  Future<List<ExpenseEntry>> loadAllExpenses() async {
    return <ExpenseEntry>[...entries];
  }

  @override
  Future<void> upsertExpense(ExpenseEntry entry) async {
    entries.removeWhere((ExpenseEntry current) => current.id == entry.id);
    entries.add(entry);
  }
}

class _QueuedExpenseDatabaseService extends ExpenseDatabaseService {
  final List<Completer<List<ExpenseEntry>>> requests =
      <Completer<List<ExpenseEntry>>>[];

  @override
  Future<List<ExpenseEntry>> loadAllExpenses() {
    final request = Completer<List<ExpenseEntry>>();
    requests.add(request);
    return request.future;
  }
}
