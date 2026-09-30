import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/presenter/widgets/common/expense_editor/expense_description_field.dart';

void main() {
  testWidgets('keyboard users can tab to a completion and select it', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pumpField(tester, controller);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byType(ActionChip), findsNWidgets(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.text, '스타벅스');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'focus shows suggestions; explicit selection fills only content',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? changed;
      await _pumpField(
        tester,
        controller,
        onChanged: (value) => changed = value,
      );
      expect(find.byType(ActionChip), findsNothing);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(find.widgetWithText(ActionChip, '스타벅스'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '스타');
      await tester.pump();
      expect(controller.text, '스타');
      expect(find.widgetWithText(ActionChip, 'スターバックス'), findsNothing);
      await tester.tap(find.widgetWithText(ActionChip, '스타벅스'));
      await tester.pump();
      expect(controller.text, '스타벅스');
      expect(controller.selection.baseOffset, '스타벅스'.length);
      expect(changed, '스타벅스');
      expect(find.byType(ActionChip), findsNothing);
      await tester.enterText(find.byType(TextField).first, '새로운 장소');
      await tester.pump();
      expect(controller.text, '새로운 장소');
      expect(find.byType(ActionChip), findsNothing);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(find.byType(ActionChip), findsNWidgets(2));
      await tester.tap(find.byType(TextField).last);
      await tester.pump();
      expect(find.byType(ActionChip), findsNothing);
    },
  );

  testWidgets('IME composition is untouched until a candidate is selected', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pumpField(tester, controller);
    await tester.tap(find.byType(TextField).first);
    const composing = TextEditingValue(
      text: '스타',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 1, end: 2),
    );
    tester.testTextInput.updateEditingValue(composing);
    await tester.pump();
    expect(controller.value, composing);
    await tester.tap(find.widgetWithText(ActionChip, '스타벅스'));
    await tester.pump();
    expect(controller.text, '스타벅스');
    expect(controller.value.composing, TextRange.empty);
  });

  testWidgets(
    'small screen, Japanese text and keyboard inset do not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final controller = TextEditingController(text: 'スタ');
      addTearDown(controller.dispose);
      await _pumpField(tester, controller);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.tap(find.widgetWithText(ActionChip, 'スターバックス'));
      await tester.pump();
      expect(controller.text, 'スターバックス');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty history still allows manual input', (tester) async {
    final controller = TextEditingController(text: 'existing content');
    addTearDown(controller.dispose);
    await _pumpField(tester, controller, suggestions: []);
    expect(controller.text, 'existing content');
    await tester.enterText(find.byType(TextField).first, 'new content');
    await tester.pump();
    expect(controller.text, 'new content');
    expect(find.byType(ActionChip), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpField(
  WidgetTester tester,
  TextEditingController controller, {
  ValueChanged<String>? onChanged,
  List<String> suggestions = const ['스타벅스', 'スターバックス'],
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 250),
        child: Column(
          children: [
            ExpenseDescriptionField(
              controller: controller,
              suggestions: suggestions,
              decoration: const InputDecoration(labelText: '내용 *'),
              suggestionsLabel: '今月よく入力した内容',
              onChanged: onChanged ?? (_) {},
            ),
            const TextField(decoration: InputDecoration(labelText: '금액 *')),
          ],
        ),
      ),
    ),
  ),
);
