import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/common/expense_editor/expense_tag_selector.dart';

void main() {
  testWidgets('short sections align with the input fields on the left', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const TextField(),
                ExpenseTagSelector(
                  label: '소비 소구분',
                  tags: const [
                    MetadataTag(
                      type: MetadataTagType.subcategory,
                      code: '_',
                      label: '평상시',
                    ),
                    MetadataTag(
                      type: MetadataTagType.subcategory,
                      code: 't',
                      label: '여행',
                    ),
                  ],
                  selectedCode: '_',
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final left = tester.getTopLeft(find.byType(TextField)).dx;
    expect(tester.getTopLeft(find.text('소비 소구분')).dx, left);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('subcategory-_'))).dx,
      left,
    );
    expect(tester.takeException(), isNull);
  });

  for (final label in ['아주 긴 사용자 소비구분 이름', 'とても長いユーザーカテゴリ名']) {
    testWidgets(
      'one tap selects and horizontal scrolling reveals tags: $label',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = '0';
        final tags = List.generate(
          6,
          (i) => MetadataTag(
            type: MetadataTagType.category,
            code: '$i',
            label: '$label $i',
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => ExpenseTagSelector(
                  label: label,
                  tags: tags,
                  selectedCode: selected,
                  onSelected: (code) => setState(() => selected = code),
                ),
              ),
            ),
          ),
        );
        final target = find.byKey(const ValueKey('category-5'));
        await tester.dragUntilVisible(
          target,
          find.byType(SingleChildScrollView),
          const Offset(-200, 0),
        );
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(selected, '5');
        expect(tester.widget<ChoiceChip>(target).selected, isTrue);
        await tester.tap(target);
        await tester.pump();
        expect(selected, '5');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
