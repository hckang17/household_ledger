import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/common/expense_editor_sheet.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-a',
    name: '가을 여행',
    startDate: DateTime(2026, 9, 3),
    endDate: DateTime(2026, 9, 5),
  );

  testWidgets('여행 기간 밖의 지출은 안내하면서 저장을 허용한다', (WidgetTester tester) async {
    await _openEditor(tester, trip: trip, initialDate: DateTime(2026, 9, 8));

    expect(
      find.byKey(const ValueKey<String>('travel-period-outside-warning')),
      findsOneWidget,
    );
    expect(find.text(_warningText), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '저장'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('여행 시작일과 종료일에는 기간 안내를 표시하지 않는다', (WidgetTester tester) async {
    await _openEditor(tester, trip: trip, initialDate: DateTime(2026, 9, 3));

    expect(
      find.byKey(const ValueKey<String>('travel-period-outside-warning')),
      findsNothing,
    );
  });
}

const String _warningText = '선택한 날짜는 여행 기간 밖입니다. 여행 전후에 발생한 지출이면 그대로 입력해주세요.';

Future<void> _openEditor(
  WidgetTester tester, {
  required Trip trip,
  required DateTime initialDate,
}) async {
  final ledgerState = LedgerState.initial();
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWith(() => _FakeLedgerNotifier(ledgerState)),
      travelProvider.overrideWith(() => _FakeTravelNotifier(trip)),
      localizedStringsProvider.overrideWithValue(const <String, String>{
        'travelExpenseTripLabel': '여행 이름',
        'travelUnassignedLabel': '미지정',
        'travelExpenseOutsidePeriodWarning': _warningText,
        'save': '저장',
      }),
    ],
  );
  addTearDown(container.dispose);
  await container.read(ledgerProvider.future);
  await container.read(travelProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: _ExpenseEditorLauncher(initialDate: initialDate)),
      ),
    ),
  );
  await tester.tap(find.text('입력 열기'));
  await tester.pumpAndSettle();
}

class _ExpenseEditorLauncher extends ConsumerWidget {
  const _ExpenseEditorLauncher({required this.initialDate});

  final DateTime initialDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton(
        onPressed: () => showExpenseEditorSheet(
          context: context,
          ref: ref,
          initialDate: initialDate,
        ),
        child: const Text('입력 열기'),
      ),
    );
  }
}

class _FakeLedgerNotifier extends LedgerNotifier {
  _FakeLedgerNotifier(this.ledgerState);

  final LedgerState ledgerState;

  @override
  Future<LedgerState> build() async => ledgerState;
}

class _FakeTravelNotifier extends TravelNotifier {
  _FakeTravelNotifier(this.trip);

  final Trip trip;

  @override
  Future<TravelState> build() async {
    return TravelState(trips: <Trip>[trip], activeTripId: trip.id);
  }
}
