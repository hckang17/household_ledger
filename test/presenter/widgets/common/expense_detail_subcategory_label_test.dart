import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/common/ledger_dialogs.dart';

void main() {
  const subcategoryTags = <MetadataTag>[
    MetadataTag(type: MetadataTagType.subcategory, code: '_', label: '평상시'),
    MetadataTag(type: MetadataTagType.subcategory, code: 't', label: '여행'),
  ];

  final trip = Trip.create(
    id: 'trip-a',
    name: '후쿠오카',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 3),
  );

  ExpenseEntry expense({String subcategoryCode = 't', String? tripId}) {
    return ExpenseEntry.create(
      id: 'expense-a',
      spentAt: DateTime(2026, 9, 1),
      categoryCode: 'E',
      subcategoryCode: subcategoryCode,
      tripId: tripId,
      description: '라멘',
      amount: 1200,
    );
  }

  test('여행 소구분은 연결된 여행명을 함께 표시한다', () {
    final label = expenseSubcategoryDetailLabel(
      entry: expense(tripId: trip.id),
      subcategoryTags: subcategoryTags,
      trips: <Trip>[trip],
    );

    expect(label, '여행(후쿠오카)');
  });

  test('연결된 여행을 찾지 못하면 기존 소구분명을 표시한다', () {
    final label = expenseSubcategoryDetailLabel(
      entry: expense(tripId: 'missing-trip'),
      subcategoryTags: subcategoryTags,
      trips: <Trip>[trip],
    );

    expect(label, '여행');
  });
}
