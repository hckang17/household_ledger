import 'package:household_ledger/model/trip.dart';
import 'package:test/test.dart';

void main() {
  test('여행정보를 JSON으로 왕복하고 날짜를 일 단위로 정규화한다', () {
    final trip = Trip.create(
      id: 'trip-a',
      name: '  제주 여행  ',
      startDate: DateTime(2026, 9, 10, 12, 30),
      endDate: DateTime(2026, 9, 14, 18, 45),
      budget: 500000,
      note: '  가족 여행  ',
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 2),
    );

    final restored = Trip.fromJson(trip.toJson());

    expect(restored.id, 'trip-a');
    expect(restored.name, '제주 여행');
    expect(restored.startDate, DateTime(2026, 9, 10));
    expect(restored.endDate, DateTime(2026, 9, 14));
    expect(restored.budget, 500000);
    expect(restored.note, '가족 여행');
  });

  test('여행을 보관하고 다시 복원할 수 있다', () {
    final trip = Trip.create(
      id: 'trip-a',
      name: '제주 여행',
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 14),
    );

    final archived = trip.copyWith(archivedAt: DateTime(2026, 9, 20));
    final restored = archived.copyWith(clearArchivedAt: true);

    expect(archived.isArchived, isTrue);
    expect(restored.isArchived, isFalse);
  });
}
