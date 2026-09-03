import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/common/travel_editor_sheet.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';

void main() {
  testWidgets('새 여행 Modal Sheet가 하단 SafeArea 안에서 여행정보를 저장한다', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        localizedStringsProvider.overrideWithValue(const <String, String>{
          'travelAddTitle': '새 여행',
          'travelNameLabel': '여행 이름',
          'travelStartDateLabel': '시작일',
          'travelEndDateLabel': '종료일',
          'travelBudgetLabel': '여행 예산 (선택)',
          'travelNoteLabel': '메모',
          'save': '저장',
        }),
        travelProvider.overrideWith(_FakeTravelNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(travelProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: _EditorLauncher())),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('새 여행'), findsOneWidget);
    final safeAreas = tester.widgetList<SafeArea>(find.byType(SafeArea));
    expect(safeAreas.any((SafeArea area) => !area.top && area.bottom), isTrue);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '제주 여행');
    await tester.enterText(fields.at(1), '500000');
    await tester.enterText(fields.at(2), '가족 여행');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final state = container.read(travelProvider).requireValue;
    expect(state.trips, hasLength(1));
    expect(state.trips.single.name, '제주 여행');
    expect(state.trips.single.budget, 500000);
    expect(state.trips.single.note, '가족 여행');
  });

  testWidgets('수정 Modal Sheet는 기존 여행정보를 초기값으로 표시한다', (
    WidgetTester tester,
  ) async {
    final trip = Trip.create(
      id: 'trip-a',
      name: '도쿄 여행',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 5),
      budget: 800000,
      note: '가을 여행',
    );
    final container = ProviderContainer(
      overrides: [
        localizedStringsProvider.overrideWithValue(const <String, String>{
          'travelEditTitle': '여행정보 수정',
          'travelNameLabel': '여행 이름',
          'travelStartDateLabel': '시작일',
          'travelEndDateLabel': '종료일',
          'travelBudgetLabel': '여행 예산 (선택)',
          'travelNoteLabel': '메모',
          'save': '저장',
        }),
        travelProvider.overrideWith(_FakeTravelNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(travelProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: _EditorLauncher(trip: trip)),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('여행정보 수정'), findsOneWidget);
    expect(find.text('도쿄 여행'), findsOneWidget);
    expect(find.text('800000'), findsOneWidget);
    expect(find.text('가을 여행'), findsOneWidget);
  });
}

class _FakeTravelNotifier extends TravelNotifier {
  @override
  Future<TravelState> build() async {
    return const TravelState(trips: <Trip>[]);
  }

  @override
  Future<void> saveTrip(Trip trip) async {
    state = AsyncData(TravelState(trips: <Trip>[trip]));
  }
}

class _EditorLauncher extends StatelessWidget {
  const _EditorLauncher({this.trip});

  final Trip? trip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => showTravelEditorSheet(context: context, trip: trip),
        child: const Text('열기'),
      ),
    );
  }
}
