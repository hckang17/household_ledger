import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/travel_management_page/travel_delete_button.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';

void main() {
  for (final locale in ['ko', 'jp']) {
    testWidgets('$locale 작은 화면에서 취소·확인·실패와 중복 제출 방지', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = Map<String, String>.from(
        jsonDecode(
              await rootBundle.loadString('assets/language_data/$locale.json'),
            )
            as Map,
      );
      final trip = Trip.create(
        id: 'trip',
        name: '아주 긴 여행 이름 とても長い旅行の名前',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 3),
      );
      final notifier = _Notifier();
      final container = ProviderContainer(
        overrides: [
          localizedStringsProvider.overrideWithValue(strings),
          travelProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);
      await container.read(travelProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: TravelDeleteButton(trip: trip)),
          ),
        ),
      );

      await tester.tap(find.text(strings['travelDeleteTitle']!));
      await tester.pumpAndSettle();
      expect(find.textContaining(trip.name), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(strings['travelDeleteNo']!));
      await tester.pumpAndSettle();
      expect(notifier.calls, 0);

      await tester.tap(find.text(strings['travelDeleteTitle']!));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings['travelDeleteYes']!));
      await tester.pumpAndSettle();
      expect(notifier.calls, 1);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
      notifier.completion.completeError(StateError('failed'));
      await tester.pumpAndSettle();
      expect(find.text(strings['travelDeleteError']!), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _Notifier extends TravelNotifier {
  final completion = Completer<void>();
  int calls = 0;

  @override
  Future<TravelState> build() async => const TravelState(trips: []);

  @override
  Future<void> deleteTrip(String tripId) async {
    calls++;
    await completion.future;
  }
}
