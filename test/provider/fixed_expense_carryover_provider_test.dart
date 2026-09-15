import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/provider/fixed_expense_carryover_provider.dart';
import 'package:household_ledger/services/database/fixed_expense_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('빈 월은 반복 제안하고 사용자가 숨긴 월만 더 이상 제안하지 않는다', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final database = _MemoryFixedExpenseDatabase(<FixedExpense>[
      _entry(id: 'rent', month: DateTime(2026, 9), amount: 800000),
    ]);
    final controller = FixedExpenseCarryoverController(database: database);

    expect(await controller.findOfferCount(DateTime(2026, 10)), 1);
    expect(await controller.findOfferCount(DateTime(2026, 10)), 1);

    await controller.suppressForMonth(DateTime(2026, 10));

    expect(await controller.findOfferCount(DateTime(2026, 10)), 0);
    expect(await controller.findOfferCount(DateTime(2026, 11)), 0);
  });

  test('지난달 항목의 금액만 0으로 바꾸고 대상 월로 복사한다', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final source = _entry(
      id: 'subscription',
      month: DateTime(2026, 9),
      amount: 12900,
    );
    final database = _MemoryFixedExpenseDatabase(<FixedExpense>[source]);
    final controller = FixedExpenseCarryoverController(database: database);

    final copied = await controller.copyPreviousMonth(DateTime(2026, 10));

    expect(copied, hasLength(1));
    expect(copied.single.id, 'carryover-2026-10-subscription');
    expect(copied.single.appliedAt, DateTime(2026, 10, 1));
    expect(copied.single.amount, 0);
    expect(copied.single.categoryCode, source.categoryCode);
    expect(copied.single.paymentMethodCode, source.paymentMethodCode);
    expect(copied.single.description, source.description);
    expect(copied.single.note, source.note);
    expect(await controller.copyPreviousMonth(DateTime(2026, 10)), isEmpty);
  });
}

FixedExpense _entry({
  required String id,
  required DateTime month,
  required int amount,
}) {
  return FixedExpense.create(
    id: id,
    appliedAt: month,
    categoryCode: 'L',
    paymentMethodCode: '_s',
    description: 'rent',
    amount: amount,
    note: 'automatic transfer',
  );
}

class _MemoryFixedExpenseDatabase extends FixedExpenseDatabaseService {
  _MemoryFixedExpenseDatabase(this.items);

  final List<FixedExpense> items;

  @override
  Future<List<FixedExpense>> loadFixedExpensesByMonth(DateTime month) async {
    return items
        .where(
          (FixedExpense item) =>
              item.appliedAt.year == month.year &&
              item.appliedAt.month == month.month,
        )
        .toList(growable: false);
  }

  @override
  Future<void> upsertFixedExpenses(List<FixedExpense> entries) async {
    for (final entry in entries) {
      items.removeWhere((FixedExpense item) => item.id == entry.id);
      items.add(entry);
    }
  }
}
