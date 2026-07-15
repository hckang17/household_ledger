// """ 테스트 계층: Model Calculation Unit Test """
// """ 대상: 수정 시 저장 식사 유형 보존과 신규 입력 시간대 추천 """
// """ 실행: dart run test test/features/expense/calculators """

import 'package:household_ledger/features/expense/calculators/expense_editor_dining_policy.dart';
import 'package:test/test.dart';

void main() {
  const policy = ExpenseEditorDiningPolicy();
  const codes = <String>[
    'breakfast',
    'brunch',
    'lunch',
    'snack',
    'dinner',
    'lateNight',
    'company',
  ];

  test('저녁 시간에 점심 데이터를 수정해도 점심을 유지하고 먼저 표시한다', () {
    final selected = policy.initialCode(
      isEditing: true,
      savedCode: 'lunch',
      categoryCode: 'F',
      selectedDate: DateTime(2026, 7, 14, 19),
      availableCodes: codes,
    );
    final ordered = policy.orderedCodes(
      availableCodes: codes,
      selectedCode: selected,
      recommendedCode: 'dinner',
    );

    expect(selected, 'lunch');
    expect(ordered.first, 'lunch');
  });

  test('식사 유형이 비어 있는 수정 데이터에는 자동 추천을 적용하지 않는다', () {
    final selected = policy.initialCode(
      isEditing: true,
      savedCode: null,
      categoryCode: 'F',
      selectedDate: DateTime(2026, 7, 14, 19),
      availableCodes: codes,
    );

    expect(selected, isNull);
  });

  test('신규 외식 입력에는 시간대 추천값을 적용한다', () {
    final selected = policy.initialCode(
      isEditing: false,
      savedCode: null,
      categoryCode: 'F',
      selectedDate: DateTime(2026, 7, 14, 19),
      availableCodes: codes,
    );

    expect(selected, 'dinner');
  });

  test('밤 9시 이후 신규 외식 입력에는 야식을 추천한다', () {
    final selected = policy.initialCode(
      isEditing: false,
      savedCode: null,
      categoryCode: 'F',
      selectedDate: DateTime(2026, 7, 14, 23),
      availableCodes: codes,
    );

    expect(selected, 'lateNight');
  });
}
