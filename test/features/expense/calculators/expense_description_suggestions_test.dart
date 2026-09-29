import 'package:household_ledger/features/expense/calculators/expense_description_suggestions.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:test/test.dart';

ExpenseEntry entry(String text, int day) => ExpenseEntry.create(
  spentAt: DateTime(2026, 9, day),
  categoryCode: 'C',
  description: text,
  amount: 100,
);

void main() {
  test('ranks frequency then recency; merges whitespace and case variants', () {
    expect(
      rankExpenseDescriptions([
        entry(' Starbucks ', 1),
        entry('starbucks', 2),
        entry('スターバックス', 3),
        entry('스타벅스', 4),
        entry('   ', 5),
      ]),
      ['starbucks', '스타벅스', 'スターバックス'],
    );
  });

  test('empty history and no match return no suggestions', () {
    expect(rankExpenseDescriptions([]), isEmpty);
    expect(matchExpenseDescriptions(['스타벅스'], '식당'), isEmpty);
  });

  test('matches literal substrings and excludes exact matches', () {
    final ranked = ['스타벅스', 'Starbucks', 'スターバックス', 'shop [1]'];
    expect(matchExpenseDescriptions(ranked, '벅스'), ['스타벅스']);
    expect(matchExpenseDescriptions(ranked, ' STAR '), ['Starbucks']);
    expect(matchExpenseDescriptions(ranked, 'スター'), ['スターバックス']);
    expect(matchExpenseDescriptions(ranked, '['), ['shop [1]']);
    expect(matchExpenseDescriptions(ranked, 'starbucks'), isEmpty);
  });

  test('caps results after matching so uncommon matches remain accessible', () {
    final ranked = List.generate(10, (i) => 'Store $i');
    expect(matchExpenseDescriptions(ranked, ''), ranked.take(5));
    expect(matchExpenseDescriptions(ranked, '9'), ['Store 9']);
  });
}
