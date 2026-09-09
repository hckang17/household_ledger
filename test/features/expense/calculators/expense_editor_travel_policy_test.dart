import 'package:household_ledger/features/expense/calculators/expense_editor_travel_policy.dart';
import 'package:test/test.dart';

void main() {
  const policy = ExpenseEditorTravelPolicy();
  const knownTrips = <String>{'trip-a', 'trip-b'};

  test('신규 지출은 활성 여행의 여행 ID와 여행 소구분을 적용한다', () {
    final selection = policy.initialSelection(
      isEditing: false,
      savedOrDefaultSubcategoryCode: '_',
      savedTripId: null,
      activeTripId: 'trip-a',
      knownTripIds: knownTrips,
    );

    expect(selection.subcategoryCode, 't');
    expect(selection.tripId, 'trip-a');
  });

  test('기존 지출 수정은 다른 활성 여행보다 저장된 값을 우선한다', () {
    final selection = policy.initialSelection(
      isEditing: true,
      savedOrDefaultSubcategoryCode: 't',
      savedTripId: 'trip-a',
      activeTripId: 'trip-b',
      knownTripIds: knownTrips,
    );

    expect(selection.subcategoryCode, 't');
    expect(selection.tripId, 'trip-a');
  });

  test('기존 일반 지출 수정에는 활성 여행을 적용하지 않는다', () {
    final selection = policy.initialSelection(
      isEditing: true,
      savedOrDefaultSubcategoryCode: '_',
      savedTripId: null,
      activeTripId: 'trip-b',
      knownTripIds: knownTrips,
    );

    expect(selection.subcategoryCode, '_');
    expect(selection.tripId, isNull);
  });

  test('소구분을 여행이 아닌 값으로 바꾸면 여행 연결을 해제한다', () {
    final tripId = policy.tripAfterSubcategoryChanged(
      subcategoryCode: '_',
      currentTripId: 'trip-a',
    );

    expect(tripId, isNull);
  });

  group('여행 기간 안내', () {
    final start = DateTime(2026, 9, 3);
    final end = DateTime(2026, 9, 5);

    test('여행 시작일과 종료일은 기간 안으로 처리한다', () {
      expect(
        policy.isOutsideTripPeriod(
          expenseDate: DateTime(2026, 9, 3, 23, 59),
          tripStartDate: start,
          tripEndDate: end,
        ),
        isFalse,
      );
      expect(
        policy.isOutsideTripPeriod(
          expenseDate: DateTime(2026, 9, 5),
          tripStartDate: start,
          tripEndDate: end,
        ),
        isFalse,
      );
    });

    test('여행 시작 전과 종료 후 날짜는 기간 밖으로 처리한다', () {
      expect(
        policy.isOutsideTripPeriod(
          expenseDate: DateTime(2026, 9, 2),
          tripStartDate: start,
          tripEndDate: end,
        ),
        isTrue,
      );
      expect(
        policy.isOutsideTripPeriod(
          expenseDate: DateTime(2026, 9, 8),
          tripStartDate: start,
          tripEndDate: end,
        ),
        isTrue,
      );
    });
  });
}
