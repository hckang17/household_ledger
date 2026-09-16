import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/presenter/widgets/import_data_page/import_preview_dialog.dart';
import 'package:household_ledger/services/imexporting_file/data_im_export_service.dart';

void main() {
  for (final locale in ['ko', 'jp']) {
    testWidgets(
      '$locale preview supports cancel and confirm on a small screen with large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final strings = Map<String, String>.from(
          jsonDecode(
                File('assets/language_data/$locale.json').readAsStringSync(),
              )
              as Map,
        );
        bool? confirmed;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    confirmed = await showImportPreviewDialog(
                      context,
                      strings,
                      ImportResult(
                        success: true,
                        ledgerState: LedgerState.initial(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('0'), findsWidgets);
        await tester.ensureVisible(find.text(strings['cancel']!));
        await tester.tap(find.text(strings['cancel']!));
        await tester.pumpAndSettle();
        expect(confirmed, isFalse);
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(strings['importButton']!));
        await tester.tap(find.text(strings['importButton']!));
        await tester.pumpAndSettle();
        expect(confirmed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
