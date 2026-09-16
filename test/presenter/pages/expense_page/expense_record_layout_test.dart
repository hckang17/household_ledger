import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/presenter/pages/expense_page/expense_record_page.dart';
import 'package:household_ledger/presenter/widgets/common/expense_entry_tile.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';

class _Ledger extends LedgerNotifier {
  @override
  Future<LedgerState> build() async => LedgerState.initial();
}

class _Travel extends TravelNotifier {
  @override
  Future<TravelState> build() async => const TravelState(trips: []);
}

void main() {
  for (final fail in [false, true]) {
    testWidgets('short viewport: loading to ${fail ? 'error' : 'empty'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(640, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<List<ExpenseEntry>>();
      final strings = Map<String, String>.from(
        jsonDecode(File('assets/language_data/jp.json').readAsStringSync())
            as Map,
      );
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWith(_Ledger.new),
          travelProvider.overrideWith(_Travel.new),
          localizedStringsProvider.overrideWithValue(strings),
          monthlyExpensesProvider.overrideWith((ref, month) => pending.future),
          monthlyIncomesProvider.overrideWith((ref, month) async => []),
        ],
      );
      addTearDown(container.dispose);
      await container.read(ledgerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const Scaffold(
              body: ExpenseRecordPage(),
              bottomNavigationBar: SizedBox(height: 80),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (fail) {
        pending.completeError(StateError('load failed'));
      } else {
        pending.complete([]);
      }
      await tester.pumpAndSettle();
      if (fail) {
        expect(find.textContaining('load failed'), findsOneWidget);
      } else {
        await tester.scrollUntilVisible(
          find.text(strings['emptyData']!),
          150,
          scrollable: find
              .descendant(
                of: find.byKey(const PageStorageKey('expense-record-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.byType(ExpenseEntryTile), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final locale in ['ko', 'jp']) {
    for (final config in [
      (const Size(320, 568), 1.0),
      (const Size(640, 360), 1.8),
      (const Size(360, 640), 1.8),
      (const Size(800, 1280), 1.0),
    ]) {
      testWidgets(
        '$locale ${config.$1} scale ${config.$2}: scroll to last record and back to calendar',
        (tester) async {
          tester.view.physicalSize = config.$1;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final strings = Map<String, String>.from(
            jsonDecode(
                  File('assets/language_data/$locale.json').readAsStringSync(),
                )
                as Map,
          );
          final now = DateTime.now();
          final entries = [
            for (var i = 0; i < 40; i++)
              ExpenseEntry.create(
                id: '$i',
                spentAt: now,
                categoryCode: 'F',
                description: 'record-$i',
                amount: 123456,
              ),
          ];
          final container = ProviderContainer(
            overrides: [
              ledgerProvider.overrideWith(_Ledger.new),
              travelProvider.overrideWith(_Travel.new),
              localizedStringsProvider.overrideWithValue(strings),
              monthlyExpensesProvider.overrideWith(
                (ref, month) async => entries,
              ),
              monthlyIncomesProvider.overrideWith((ref, month) async => []),
            ],
          );
          addTearDown(container.dispose);
          await container.read(ledgerProvider.future);
          await container.read(travelProvider.future);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(config.$2)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: ExpenseRecordPage(),
                  bottomNavigationBar: SizedBox(height: 80),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final scroll = find.byKey(
            const PageStorageKey('expense-record-scroll'),
          );
          final last = find.byWidgetPredicate(
            (w) => w is ExpenseEntryTile && w.entry.id == '39',
          );
          await tester.scrollUntilVisible(
            last,
            250,
            scrollable: find
                .descendant(of: scroll, matching: find.byType(Scrollable))
                .first,
            maxScrolls: 100,
          );
          await tester.ensureVisible(last);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(last).bottom,
            lessThanOrEqualTo(config.$1.height - 80),
          );
          expect(find.byType(ExpenseEntryTile).evaluate().length, lessThan(40));
          final position = tester
              .state<ScrollableState>(
                find
                    .descendant(of: scroll, matching: find.byType(Scrollable))
                    .first,
              )
              .position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();
          final fab = find.byType(FloatingActionButton);
          expect(
            tester.getRect(last).bottom,
            lessThanOrEqualTo(tester.getRect(fab).top),
          );
          position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(strings['calendarFold']!));
          await tester.pumpAndSettle();
          expect(find.byTooltip(strings['calendarUnfold']!), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
