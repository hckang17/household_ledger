import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/travel_management_page/travel_trip_card.dart';
import 'package:household_ledger/provider/localization_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final languages = <String, Map<String, String>>{};
  setUpAll(() async {
    for (final locale in ['ko', 'jp']) {
      languages[locale] = Map<String, String>.from(
        jsonDecode(
              await rootBundle.loadString('assets/language_data/$locale.json'),
            )
            as Map,
      );
    }
  });
  late Map<String, String> strings;
  late Trip trip;
  var opened = 0;
  var edited = 0;
  var retried = 0;
  bool? archived;

  setUp(() {
    opened = edited = retried = 0;
    archived = null;
    trip = Trip.create(
      id: 'trip',
      name: '가족과 함께 떠나는 아주 긴 여행 이름 長い旅行の名前',
      startDate: DateTime(2026, 12, 30),
      endDate: DateTime(2027, 1, 3),
      budget: 1000000,
      note: '여행 메모 / 旅行メモ',
    );
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    String locale = 'ko',
    AsyncValue<int> total = const AsyncData(250000),
    double width = 320,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    strings = languages[locale]!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localizedStringsProvider.overrideWithValue(strings)],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: TravelTripCard(
                  trip: trip,
                  isActive: !trip.isArchived,
                  totalExpense: total,
                  currency: locale == 'ko' ? '원' : '円',
                  strings: strings,
                  onTap: () => opened++,
                  onEdit: () => edited++,
                  onArchiveChanged: (value) => archived = value,
                  onRetry: () => retried++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final locale in ['ko', 'jp']) {
    testWidgets('$locale 작은 화면과 큰 글꼴에서 이름·기간·예산·관리 버튼을 표시한다', (tester) async {
      await pumpCard(tester, locale: locale, scale: 1.4);
      expect(find.text(trip.name), findsOneWidget);
      expect(find.text('2026.12.30 – 2027.01.03'), findsOneWidget);
      expect(
        find.textContaining(strings['travelRemainingBudgetLabel']!),
        findsOneWidget,
      );
      expect(find.text('25.0%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(trip.name));
      expect(opened, 1);
      await tester.ensureVisible(find.text(strings['edit']!));
      await tester.tap(find.text(strings['edit']!));
      expect(edited, 1);
      expect(opened, 1);
      await tester.ensureVisible(find.text(strings['travelArchiveButton']!));
      await tester.tap(find.text(strings['travelArchiveButton']!));
      expect(archived, isTrue);
      await tester.ensureVisible(find.text(strings['travelDeleteTitle']!));
      await tester.tap(find.text(strings['travelDeleteTitle']!));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text(strings['travelDeleteNo']!));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });
  }

  testWidgets('예산 초과는 금액과 문구를 표시하고 막대는 100%에서 멈춘다', (tester) async {
    await pumpCard(tester, total: const AsyncData(1250000), width: 720);
    expect(find.text('예산 초과 250,000원'), findsOneWidget);
    expect(find.text('125.0%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('예산 미설정·지출 0건에서는 예산 설정으로 이동한다', (tester) async {
    trip = trip.copyWith(clearBudget: true);
    await pumpCard(tester, total: const AsyncData(0));
    expect(find.text('0원'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text(strings['travelSetBudgetButton']!));
    expect(edited, 1);
    expect(opened, 0);
  });

  testWidgets('로딩과 오류를 0원으로 오인하지 않고 오류에서 재시도한다', (tester) async {
    await pumpCard(tester, total: const AsyncLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('0원'), findsNothing);
    await pumpCard(
      tester,
      total: AsyncError(StateError('failed'), StackTrace.empty),
    );
    expect(find.text(strings['travelExpenseLoadError']!), findsOneWidget);
    expect(find.text('0원'), findsNothing);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    expect(retried, 1);
    expect(opened, 0);
  });

  testWidgets('보관 여행에서는 복원 버튼과 보관 상태를 표시한다', (tester) async {
    trip = trip.copyWith(archivedAt: DateTime(2027, 2, 1));
    await pumpCard(tester);
    expect(find.text(strings['travelArchivedLabel']!), findsOneWidget);
    expect(find.text(strings['travelActiveLabel']!), findsNothing);
    await tester.tap(find.text(strings['travelRestoreButton']!));
    expect(archived, isFalse);
  });
}
