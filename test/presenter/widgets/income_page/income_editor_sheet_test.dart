import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/presenter/widgets/income_page/income_editor_sheet.dart';

void main() {
  for (final language in ['ko', 'jp']) {
    testWidgets('$language: small screen category and editable leap-day date', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = Map<String, String>.from(
        jsonDecode(
              File('assets/language_data/$language.json').readAsStringSync(),
            )
            as Map,
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () => showIncomeEditorSheet(
                      context: context,
                      ref: ref,
                      focusedMonth: DateTime(2024, 2),
                      strings: strings,
                      item: IncomeEntry.create(
                        id: 1,
                        earnedAt: DateTime(2024, 2, 29),
                        amount: 100,
                        description: 'income',
                        category: IncomeCategory.gift,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('2024-02-29'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<IncomeCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings['incomeCategory_regular']!).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2024-02-29'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('28'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('2024-02-28'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
