import 'package:household_ledger/model/data_search_filter.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/services/data_search_service.dart';
import 'package:test/test.dart';

void main() {
  ExpenseEntry expense(String id, String subcategoryCode) {
    return ExpenseEntry.create(
      id: id,
      spentAt: DateTime(2026, 9, 1),
      categoryCode: 'E',
      subcategoryCode: subcategoryCode,
      tripId: subcategoryCode == 't' ? 'trip-a' : null,
      description: id,
      amount: 1000,
    );
  }

  test('소비 소구분 코드로 지출을 검색한다', () {
    final result = DataSearchService.filterExpenses(
      <ExpenseEntry>[expense('usual', '_'), expense('travel', 't')],
      const DataSearchFilter(
        tableType: DataTableType.expense,
        subcategoryCode: 't',
      ),
    );

    expect(result.map((ExpenseEntry entry) => entry.id), <String>['travel']);
  });

  test('소비 소구분 필터를 해제하면 모든 소구분을 검색한다', () {
    final filter = const DataSearchFilter(
      subcategoryCode: 't',
    ).copyWith(clearSubcategory: true);

    final result = DataSearchService.filterExpenses(<ExpenseEntry>[
      expense('usual', '_'),
      expense('travel', 't'),
    ], filter);

    expect(result, hasLength(2));
  });
}
