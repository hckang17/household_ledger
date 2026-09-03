/// 지출 입력 시 적용할 여행 소구분과 여행 ID를 함께 보관한다.
class ExpenseTravelSelection {
  const ExpenseTravelSelection({
    required this.subcategoryCode,
    required this.tripId,
  });

  final String subcategoryCode;
  final String? tripId;
}

/// 여행 모드가 지출 입력의 초기값에 미치는 규칙을 UI와 분리한다.
class ExpenseEditorTravelPolicy {
  const ExpenseEditorTravelPolicy();

  ExpenseTravelSelection initialSelection({
    required bool isEditing,
    required String savedOrDefaultSubcategoryCode,
    required String? savedTripId,
    required String? activeTripId,
    required Set<String> knownTripIds,
  }) {
    if (isEditing) {
      return ExpenseTravelSelection(
        subcategoryCode: savedOrDefaultSubcategoryCode,
        tripId:
            savedOrDefaultSubcategoryCode == 't' &&
                knownTripIds.contains(savedTripId)
            ? savedTripId
            : null,
      );
    }

    if (knownTripIds.contains(activeTripId)) {
      return ExpenseTravelSelection(subcategoryCode: 't', tripId: activeTripId);
    }

    return ExpenseTravelSelection(
      subcategoryCode: savedOrDefaultSubcategoryCode,
      tripId: null,
    );
  }

  String? tripAfterSubcategoryChanged({
    required String subcategoryCode,
    required String? currentTripId,
  }) {
    return subcategoryCode == 't' ? currentTripId : null;
  }
}
