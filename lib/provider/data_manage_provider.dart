import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/data_search_filter.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/services/data_search_service.dart';

enum DataManageStatus { idle, searching, found, operating }

class DataManageState {
  const DataManageState({
    this.filter = const DataSearchFilter(),
    this.expenses = const <ExpenseEntry>[],
    this.fixedExpenses = const <FixedExpense>[],
    this.incomes = const <IncomeEntry>[],
    this.searchedTableType,
    this.selectedIds = const <String>{},
    this.status = DataManageStatus.idle,
    this.operationCompleted = 0,
    this.operationTotal = 0,
  });

  final DataSearchFilter filter;
  final List<ExpenseEntry> expenses;
  final List<FixedExpense> fixedExpenses;
  final List<IncomeEntry> incomes;
  final DataTableType? searchedTableType;
  final Set<String> selectedIds;
  final DataManageStatus status;
  final int operationCompleted;
  final int operationTotal;

  bool get hasResults =>
      searchedTableType != null && status != DataManageStatus.searching;
  bool get isOperating => status == DataManageStatus.operating;
  bool get isSearching => status == DataManageStatus.searching;
  bool get hasSelection => selectedIds.isNotEmpty;

  int get resultCount {
    return switch (searchedTableType) {
      DataTableType.expense => expenses.length,
      DataTableType.fixedExpense => fixedExpenses.length,
      DataTableType.income => incomes.length,
      null => 0,
    };
  }

  bool isSelected(String id) => selectedIds.contains(id);

  bool get isAllSelected =>
      selectedIds.isNotEmpty && selectedIds.length == resultCount;

  DataManageState copyWith({
    DataSearchFilter? filter,
    List<ExpenseEntry>? expenses,
    List<FixedExpense>? fixedExpenses,
    List<IncomeEntry>? incomes,
    DataTableType? searchedTableType,
    bool clearSearchedTableType = false,
    Set<String>? selectedIds,
    DataManageStatus? status,
    int? operationCompleted,
    int? operationTotal,
  }) {
    return DataManageState(
      filter: filter ?? this.filter,
      expenses: expenses ?? this.expenses,
      fixedExpenses: fixedExpenses ?? this.fixedExpenses,
      incomes: incomes ?? this.incomes,
      searchedTableType: clearSearchedTableType
          ? null
          : (searchedTableType ?? this.searchedTableType),
      selectedIds: selectedIds ?? this.selectedIds,
      status: status ?? this.status,
      operationCompleted: operationCompleted ?? this.operationCompleted,
      operationTotal: operationTotal ?? this.operationTotal,
    );
  }
}

class DataManageNotifier extends Notifier<DataManageState> {
  @override
  DataManageState build() => const DataManageState();

  void setFilter(DataSearchFilter filter) {
    state = state.copyWith(filter: filter);
  }

  Future<void> search() async {
    final DataTableType? tableType = state.filter.tableType;
    if (tableType == null) {
      return;
    }

    state = state.copyWith(
      status: DataManageStatus.searching,
      selectedIds: const <String>{},
    );

    switch (tableType) {
      case DataTableType.expense:
        final List<ExpenseEntry> all = await ref
            .read(expenseDatabaseServiceProvider)
            .loadAllExpenses();
        final List<ExpenseEntry> filtered = DataSearchService.filterExpenses(
          all,
          state.filter,
        );
        state = state.copyWith(
          expenses: filtered,
          searchedTableType: tableType,
          status: DataManageStatus.found,
        );
      case DataTableType.fixedExpense:
        final List<FixedExpense> all = await ref
            .read(fixedExpenseDatabaseServiceProvider)
            .loadAllFixedExpenses();
        final List<FixedExpense> filtered =
            DataSearchService.filterFixedExpenses(all, state.filter);
        state = state.copyWith(
          fixedExpenses: filtered,
          searchedTableType: tableType,
          status: DataManageStatus.found,
        );
      case DataTableType.income:
        final List<IncomeEntry> all = await ref
            .read(incomeDatabaseServiceProvider)
            .loadAllIncomes();
        final List<IncomeEntry> filtered = DataSearchService.filterIncomes(
          all,
          state.filter,
        );
        state = state.copyWith(
          incomes: filtered,
          searchedTableType: tableType,
          status: DataManageStatus.found,
        );
    }
  }

  void toggleSelection(String id) {
    final Set<String> next = Set<String>.from(state.selectedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(selectedIds: next);
  }

  void selectAll() {
    final Set<String> all = switch (state.searchedTableType) {
      DataTableType.expense =>
        state.expenses.map((ExpenseEntry e) => e.id).toSet(),
      DataTableType.fixedExpense =>
        state.fixedExpenses.map((FixedExpense e) => e.id).toSet(),
      DataTableType.income =>
        state.incomes
            .where((IncomeEntry e) => e.id != null)
            .map((IncomeEntry e) => e.id.toString())
            .toSet(),
      null => const <String>{},
    };
    state = state.copyWith(selectedIds: all);
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: const <String>{});
  }

  Future<void> deleteSelected() async {
    if (state.selectedIds.isEmpty || state.searchedTableType == null) {
      return;
    }
    final Set<String> ids = Set<String>.from(state.selectedIds);

    state = state.copyWith(
      status: DataManageStatus.operating,
      operationTotal: ids.length,
      operationCompleted: 0,
    );

    switch (state.searchedTableType!) {
      case DataTableType.expense:
        final db = ref.read(expenseDatabaseServiceProvider);
        for (final String id in ids) {
          await db.deleteExpense(id);
          state = state.copyWith(
            operationCompleted: state.operationCompleted + 1,
          );
        }
        state = state.copyWith(
          expenses: state.expenses
              .where((ExpenseEntry e) => !ids.contains(e.id))
              .toList(),
          selectedIds: const <String>{},
          status: DataManageStatus.found,
        );
        ref.invalidate(monthlyExpensesProvider);
        ref.invalidate(rangeExpensesProvider);
        ref.invalidate(ledgerProvider);
      case DataTableType.fixedExpense:
        final db = ref.read(fixedExpenseDatabaseServiceProvider);
        for (final String id in ids) {
          await db.deleteFixedExpense(id);
          state = state.copyWith(
            operationCompleted: state.operationCompleted + 1,
          );
        }
        state = state.copyWith(
          fixedExpenses: state.fixedExpenses
              .where((FixedExpense e) => !ids.contains(e.id))
              .toList(),
          selectedIds: const <String>{},
          status: DataManageStatus.found,
        );
        ref.invalidate(monthlyFixedExpensesProvider);
        ref.invalidate(ledgerProvider);
      case DataTableType.income:
        final db = ref.read(incomeDatabaseServiceProvider);
        for (final IncomeEntry income in state.incomes) {
          if (income.id != null && ids.contains(income.id.toString())) {
            await db.deleteIncome(income.id!);
            state = state.copyWith(
              operationCompleted: state.operationCompleted + 1,
            );
          }
        }
        state = state.copyWith(
          incomes: state.incomes
              .where(
                (IncomeEntry e) =>
                    e.id == null || !ids.contains(e.id.toString()),
              )
              .toList(),
          selectedIds: const <String>{},
          status: DataManageStatus.found,
        );
        ref.invalidate(monthlyIncomesProvider);
    }
  }

  /// 선택된 항목의 소비수단/소비구분을 일괄 변경한다. (수입 테이블에서는 무시됨)
  Future<void> bulkChangeTags({
    String? paymentMethodCode,
    String? categoryCode,
  }) async {
    if (state.selectedIds.isEmpty || state.searchedTableType == null) {
      return;
    }
    if (paymentMethodCode == null && categoryCode == null) {
      return;
    }

    final Set<String> ids = Set<String>.from(state.selectedIds);

    state = state.copyWith(
      status: DataManageStatus.operating,
      operationTotal: ids.length,
      operationCompleted: 0,
    );

    switch (state.searchedTableType!) {
      case DataTableType.expense:
        final db = ref.read(expenseDatabaseServiceProvider);
        for (final ExpenseEntry e in state.expenses) {
          if (!ids.contains(e.id)) {
            continue;
          }
          ExpenseEntry updated = e;
          if (paymentMethodCode != null) {
            updated = updated.copyWith(paymentMethodCode: paymentMethodCode);
          }
          if (categoryCode != null) {
            updated = updated.copyWith(categoryCode: categoryCode);
          }
          await db.upsertExpense(updated);
          state = state.copyWith(
            operationCompleted: state.operationCompleted + 1,
          );
        }
        state = state.copyWith(
          expenses: state.expenses.map((ExpenseEntry e) {
            if (!ids.contains(e.id)) {
              return e;
            }
            ExpenseEntry updated = e;
            if (paymentMethodCode != null) {
              updated = updated.copyWith(paymentMethodCode: paymentMethodCode);
            }
            if (categoryCode != null) {
              updated = updated.copyWith(categoryCode: categoryCode);
            }
            return updated;
          }).toList(),
          selectedIds: const <String>{},
          status: DataManageStatus.found,
        );
        ref.invalidate(monthlyExpensesProvider);
        ref.invalidate(rangeExpensesProvider);
        ref.invalidate(ledgerProvider);
      case DataTableType.fixedExpense:
        final db = ref.read(fixedExpenseDatabaseServiceProvider);
        for (final FixedExpense e in state.fixedExpenses) {
          if (!ids.contains(e.id)) {
            continue;
          }
          FixedExpense updated = e;
          if (paymentMethodCode != null) {
            updated = updated.copyWith(paymentMethodCode: paymentMethodCode);
          }
          if (categoryCode != null) {
            updated = updated.copyWith(categoryCode: categoryCode);
          }
          await db.upsertFixedExpense(updated);
          state = state.copyWith(
            operationCompleted: state.operationCompleted + 1,
          );
        }
        state = state.copyWith(
          fixedExpenses: state.fixedExpenses.map((FixedExpense e) {
            if (!ids.contains(e.id)) {
              return e;
            }
            FixedExpense updated = e;
            if (paymentMethodCode != null) {
              updated = updated.copyWith(paymentMethodCode: paymentMethodCode);
            }
            if (categoryCode != null) {
              updated = updated.copyWith(categoryCode: categoryCode);
            }
            return updated;
          }).toList(),
          selectedIds: const <String>{},
          status: DataManageStatus.found,
        );
        ref.invalidate(monthlyFixedExpensesProvider);
        ref.invalidate(ledgerProvider);
      case DataTableType.income:
        // 수입에는 소비수단/소비구분이 없음
        state = state.copyWith(status: DataManageStatus.found);
    }
  }
}

final dataManageProvider =
    NotifierProvider<DataManageNotifier, DataManageState>(
      DataManageNotifier.new,
    );
