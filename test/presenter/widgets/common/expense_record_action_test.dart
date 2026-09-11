import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/common/expense_record_action.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/travel_provider.dart';

void main() {
  for (final floating in [true, false]) {
    for (final japanese in [false, true]) {
      testWidgets('여행 모드 ON/OFF 기록 버튼: floating=$floating jp=$japanese', (
        tester,
      ) async {
        var pressed = 0;
        final container = ProviderContainer(
          overrides: [travelProvider.overrideWith(_Travel.new)],
        );
        addTearDown(container.dispose);
        await container.read(travelProvider.future);
        final normal = japanese ? '支出を記録する' : '지출 기록하기';
        final travel = japanese ? '旅行の支出を記録' : '여행지출 기록하기';
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 280,
                  child: ExpenseRecordAction(
                    strings: {
                      'quickExpense': normal,
                      'recordTravelExpense': travel,
                    },
                    floating: floating,
                    onPressed: () => pressed++,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text(normal), findsOneWidget);
        final notifier = container.read(travelProvider.notifier) as _Travel;
        notifier.toggle(true);
        await tester.pumpAndSettle();
        expect(find.text(travel), findsOneWidget);
        expect(find.text(normal), findsNothing);
        final Color? background;
        final Color? foreground;
        if (floating) {
          final button = tester.widget<FloatingActionButton>(
            find.byType(FloatingActionButton),
          );
          background = button.backgroundColor;
          foreground = button.foregroundColor;
        } else {
          final button = tester.widget<BootstrapActionButton>(
            find.byType(BootstrapActionButton),
          );
          background = button.backgroundColor;
          foreground = button.foregroundColor;
        }
        expect(background, const Color(0xFF16804A));
        expect(foreground, Colors.white);
        expect(
          (foreground!.computeLuminance() + 0.05) /
              (background!.computeLuminance() + 0.05),
          greaterThanOrEqualTo(4.5),
        );
        await tester.tap(find.text(travel));
        expect(pressed, 1);
        notifier.toggle(false);
        await tester.pumpAndSettle();
        expect(find.text(normal), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _Travel extends TravelNotifier {
  @override
  Future<TravelState> build() async => const TravelState(trips: []);

  void toggle(bool enabled) {
    final trip = Trip.create(
      id: 'a',
      name: 'trip',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
    );
    state = AsyncData(
      TravelState(trips: [trip], activeTripId: enabled ? trip.id : null),
    );
  }
}
