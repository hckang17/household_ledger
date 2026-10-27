import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/widgets/common/entrance_reveal.dart';
import 'package:household_ledger/presenter/widgets/common/expense_entry_tile.dart';

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: child),
  ),
);

Widget tile(DateTime? savedAt, {VoidCallback? onEdit}) => ExpenseEntryTile(
  entry: ExpenseEntry.create(
    id: 'saved',
    spentAt: DateTime(2026, 10, 26),
    categoryCode: 'F',
    description: '식사',
    amount: 1200,
  ),
  highlightedAt: savedAt,
  categoryLabel: '식비',
  categoryIcon: Icons.restaurant,
  currency: '원',
  editTooltip: '수정',
  deleteTooltip: '삭제',
  onTap: () {},
  onEdit: onEdit ?? () {},
  onDelete: () {},
);

Color background(WidgetTester tester) => tester
    .widget<BootstrapSectionCard>(find.byType(BootstrapSectionCard))
    .backgroundColor;

void main() {
  testWidgets(
    'successful save fades once, keeps actions available and can repeat',
    (tester) async {
      var edits = 0;
      final savedAt = DateTime.now();
      await tester.pumpWidget(host(tile(savedAt, onEdit: () => edits++)));
      expect(background(tester), isNot(Colors.white));
      await tester.tap(find.byTooltip('수정'));
      expect(edits, 1);
      await tester.pump(const Duration(milliseconds: 700));
      expect(background(tester), Colors.white);
      await tester.pumpWidget(host(tile(savedAt)));
      expect(background(tester), Colors.white);
      await tester.pumpWidget(
        host(tile(DateTime.now().add(const Duration(milliseconds: 1)))),
      );
      expect(background(tester), isNot(Colors.white));
      await tester.pumpAndSettle();
      expect(background(tester), Colors.white);
    },
  );

  testWidgets('ordinary, expired and reduced-motion records stay still', (
    tester,
  ) async {
    await tester.pumpWidget(host(tile(null)));
    expect(background(tester), Colors.white);
    await tester.pumpWidget(
      host(tile(DateTime.now().subtract(const Duration(seconds: 2)))),
    );
    expect(background(tester), Colors.white);
    await tester.pumpWidget(host(tile(DateTime.now()), reduced: true));
    expect(background(tester), Colors.white);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('entrance finishes in 260ms and does not replay on rebuild', (
    tester,
  ) async {
    Widget reveal() => host(const EntranceReveal(child: Text('Summary')));
    await tester.pumpWidget(reveal());
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await tester.pump(const Duration(milliseconds: 260));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pumpWidget(reveal());
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      host(const EntranceReveal(child: Text('Summary')), reduced: true),
    );
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await tester.pumpAndSettle();
  });
}
