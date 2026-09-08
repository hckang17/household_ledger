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
}
