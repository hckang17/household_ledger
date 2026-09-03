import 'package:household_ledger/model/expense_entry.dart';
import 'package:test/test.dart';

void main() {
  ExpenseEntry create({required String subcategoryCode, String? tripId}) {
    return ExpenseEntry.create(
      id: 'expense-1',
      spentAt: DateTime(2026, 9, 10),
      categoryCode: 'T',
      subcategoryCode: subcategoryCode,
      tripId: tripId,
      description: '항공권',
      amount: 100000,
    );
  }

  test('여행 소구분 지출은 여행 ID를 저장하고 JSON으로 왕복한다', () {
    final entry = create(subcategoryCode: 't', tripId: 'trip-a');
    final restored = ExpenseEntry.fromJson(entry.toJson());

    expect(entry.tripId, 'trip-a');
    expect(restored.tripId, 'trip-a');
  });

  test('여행이 아닌 소구분에는 여행 ID를 저장하지 않는다', () {
    final entry = create(subcategoryCode: '_', tripId: 'trip-a');

    expect(entry.tripId, isNull);
  });

  test('기존 여행 지출 수정 시 저장된 여행 ID를 유지하고 명시적으로 해제한다', () {
    final entry = create(subcategoryCode: 't', tripId: 'trip-a');

    expect(entry.copyWith(description: '수정').tripId, 'trip-a');
    expect(entry.copyWith(clearTrip: true).tripId, isNull);
    expect(entry.copyWith(subcategoryCode: '_').tripId, isNull);
  });
}
