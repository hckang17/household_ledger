// """ MVVM 계층: Model / Calculation Policy """
// """ 역할: 소비 입력·수정 시 식사 유형의 초기값과 표시 우선순위를 결정 """
// """ 규칙: 수정 데이터는 시간대 추천으로 덮어쓰지 않음 """

class ExpenseEditorDiningPolicy {
  const ExpenseEditorDiningPolicy();

  String? initialCode({
    required bool isEditing,
    required String? savedCode,
    required String categoryCode,
    required DateTime selectedDate,
    required Iterable<String> availableCodes,
  }) {
    if (isEditing) return savedCode;
    if (categoryCode != 'F') return null;
    return recommendedCode(
      selectedDate: selectedDate,
      availableCodes: availableCodes,
    );
  }

  String? recommendedCode({
    required DateTime selectedDate,
    required Iterable<String> availableCodes,
  }) {
    final hour = selectedDate.hour;
    final recommended = switch (hour) {
      >= 6 && < 10 => 'breakfast',
      >= 10 && < 11 => 'brunch',
      >= 11 && < 14 => 'lunch',
      >= 14 && < 18 => 'snack',
      >= 18 && < 21 => 'dinner',
      _ => 'company',
    };
    return availableCodes.contains(recommended) ? recommended : null;
  }

  List<String> orderedCodes({
    required Iterable<String> availableCodes,
    required String? selectedCode,
    required String? recommendedCode,
  }) {
    final codes = availableCodes.toList()..sort();
    final preferredCode = selectedCode ?? recommendedCode;
    if (preferredCode == null || !codes.remove(preferredCode)) return codes;
    return <String>[preferredCode, ...codes];
  }
}
