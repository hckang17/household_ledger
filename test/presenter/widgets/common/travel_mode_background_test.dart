import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:household_ledger/presenter/extensions/travel_gradient_palette_extension.dart';
import 'package:household_ledger/presenter/widgets/common/travel_mode_background.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';

void main() {
  testWidgets('travel gradient is hidden when travel mode is off', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(const TravelState(trips: <Trip>[])));

    final opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey<String>('travel-mode-gradient')),
    );
    expect(opacity.opacity, 0);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('travel gradient fades in when an active trip exists', (
    WidgetTester tester,
  ) async {
    final trip = Trip.create(
      id: 'trip-a',
      name: 'Jeju',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 3),
      createdAt: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      _testApp(TravelState(trips: <Trip>[trip], activeTripId: trip.id)),
    );
    await tester.pump();

    final opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey<String>('travel-mode-gradient')),
    );
    expect(opacity.opacity, 1);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('reduced motion keeps the travel background static', (
    WidgetTester tester,
  ) async {
    final trip = Trip.create(
      id: 'trip-a',
      name: 'Jeju',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 3),
      createdAt: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      _testApp(
        TravelState(trips: <Trip>[trip], activeTripId: trip.id),
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('selected palette supplies the travel gradient colors', (
    WidgetTester tester,
  ) async {
    final trip = Trip.create(
      id: 'trip-a',
      name: 'Jeju',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 3),
      createdAt: DateTime(2026, 8, 1),
    );

    await tester.pumpWidget(
      _testApp(
        TravelState(trips: <Trip>[trip], activeTripId: trip.id),
        palette: TravelGradientPalette.ocean,
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();

    final gradientBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('travel-mode-gradient')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final gradient = (gradientBox.decoration as BoxDecoration).gradient;
    expect(gradient, isA<LinearGradient>());
    final linearGradient = gradient! as LinearGradient;
    expect(linearGradient.colors, TravelGradientPalette.ocean.colors);
    expect(linearGradient.transform, isA<GradientRotation>());
  });
}

Widget _testApp(
  TravelState travelState, {
  bool disableAnimations = false,
  TravelGradientPalette palette = TravelGradientPalette.breeze,
}) {
  final ledgerState = LedgerState.initial();
  return ProviderScope(
    overrides: [
      travelProvider.overrideWith(() => _FakeTravelNotifier(travelState)),
      ledgerProvider.overrideWith(
        () => _FakeLedgerNotifier(
          ledgerState.copyWith(
            settings: ledgerState.settings.copyWith(
              travelGradientPalette: palette,
            ),
          ),
        ),
      ),
    ],
    child: MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: TravelModeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: const Text('content'),
        ),
      ),
    ),
  );
}

class _FakeTravelNotifier extends TravelNotifier {
  _FakeTravelNotifier(this.travelState);

  final TravelState travelState;

  @override
  Future<TravelState> build() async => travelState;
}

class _FakeLedgerNotifier extends LedgerNotifier {
  _FakeLedgerNotifier(this.ledgerState);

  final LedgerState ledgerState;

  @override
  Future<LedgerState> build() async => ledgerState;
}
