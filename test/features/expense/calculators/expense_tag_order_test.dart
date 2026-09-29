import 'package:household_ledger/features/expense/calculators/expense_tag_order.dart';
import 'package:test/test.dart';

void main() {
  test('frequency wins; ties and unused tags retain their original order', () {
    expect(
      orderExpenseTagCodes(
        availableCodes: ['A', 'B', 'C', 'D'],
        usedCodes: ['C', 'B', 'C', 'removed'],
      ),
      ['C', 'B', 'A', 'D'],
    );
  });

  test('empty history preserves defaults and empty tags are supported', () {
    expect(orderExpenseTagCodes(availableCodes: ['B', 'A'], usedCodes: []), [
      'B',
      'A',
    ]);
    expect(orderExpenseTagCodes(availableCodes: [], usedCodes: ['A']), isEmpty);
  });

  test(
    'editing keeps the saved selection visible without adding deleted tags',
    () {
      expect(
        orderExpenseTagCodes(
          availableCodes: ['A', 'B', 'C'],
          usedCodes: ['C', 'C', 'B'],
          selectedCode: 'A',
        ),
        ['A', 'C', 'B'],
      );
      expect(
        orderExpenseTagCodes(
          availableCodes: ['A'],
          usedCodes: [],
          selectedCode: 'removed',
        ),
        ['A'],
      );
    },
  );
}
