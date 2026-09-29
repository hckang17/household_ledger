import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
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

  testWidgets('필수 표시와 자동완성은 검증 및 저장 흐름을 유지한다', (tester) async {
    final notifier = await _openEditor(
      tester,
      trip: trip,
      initialDate: DateTime(2026, 9, 3),
      expenses: [
        ExpenseEntry.create(
          spentAt: DateTime(2026, 9, 1),
          categoryCode: 'C',
          description: '스타벅스',
          amount: 600,
        ),
      ],
    );
    expect(find.text('내용 *'), findsOneWidget);
    expect(find.text('금액 *'), findsOneWidget);
    expect(find.text('소비구분 *'), findsOneWidget);
    expect(find.text('소비 소구분 *'), findsOneWidget);
    expect(find.text('소비수단 *'), findsOneWidget);
    expect(find.text('날짜 *'), findsOneWidget);
    expect(find.text('메모 *'), findsNothing);
    final save = find.widgetWithText(FilledButton, '저장');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(notifier.saved, isNull);
    expect(find.text('내용을 입력해주세요.'), findsOneWidget);
    expect(find.text('금액을 입력해주세요.'), findsOneWidget);
    final description = find.byType(TextField).at(1);
    await tester.ensureVisible(description);
    await tester.tap(description);
    await tester.pumpAndSettle();
    final suggestion = find.widgetWithText(ActionChip, '스타벅스');
    await tester.ensureVisible(suggestion);
    await tester.tap(suggestion);
    await tester.pumpAndSettle();
    expect(find.text('내용을 입력해주세요.'), findsNothing);
    await tester.enterText(find.byType(TextField).at(2), '900');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(notifier.saved?.description, '스타벅스');
    expect(notifier.saved?.amount, 900);
    expect(notifier.saved?.tripId, trip.id);
  });

  testWidgets('칩 선택 후 저장하면 소비구분·소구분·소비수단을 반영한다', (tester) async {
    final notifier = await _openEditor(
      tester,
      trip: trip,
      initialDate: DateTime(2026, 9, 3),
    );
    final category = find.byKey(const ValueKey('category-C'));
    await tester.ensureVisible(category);
    await tester.tap(category);
    final usual = find.byKey(const ValueKey('subcategory-_'));
    await tester.ensureVisible(usual);
    await tester.tap(usual);
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<String>), findsNothing);
    final payment = find.byKey(const ValueKey('paymentMethod-_s'));
    await tester.ensureVisible(payment);
    await tester.tap(payment);
    await tester.enterText(find.byType(TextField).at(1), '커피');
    await tester.enterText(find.byType(TextField).at(2), '450');
    final save = find.widgetWithText(FilledButton, '저장');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(notifier.saved?.categoryCode, 'C');
    expect(notifier.saved?.subcategoryCode, '_');
    expect(notifier.saved?.paymentMethodCode, '_s');
    expect(notifier.saved?.tripId, isNull);
    expect(notifier.saved?.amount, 450);
  });

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

  testWidgets('상세 화면의 명시적 여행은 다른 활성 여행보다 우선한다', (WidgetTester tester) async {
    final otherTrip = Trip.create(
      id: 'trip-b',
      name: '겨울 여행',
      startDate: DateTime(2026, 12, 1),
      endDate: DateTime(2026, 12, 3),
    );
    await _openEditor(
      tester,
      trip: trip,
      otherTrip: otherTrip,
      initialTripId: otherTrip.id,
      initialDate: DateTime(2026, 12, 2),
    );

    final tripDropdown = tester
        .widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .firstWhere(
          (DropdownButton<String> dropdown) =>
              dropdown.items?.any((item) => item.value == otherTrip.id) ??
              false,
        );
    expect(tripDropdown.value, otherTrip.id);
  });
}

const String _warningText = '선택한 날짜는 여행 기간 밖입니다. 여행 전후에 발생한 지출이면 그대로 입력해주세요.';

Future<_FakeLedgerNotifier> _openEditor(
  WidgetTester tester, {
  required Trip trip,
  required DateTime initialDate,
  Trip? otherTrip,
  String? initialTripId,
  List<ExpenseEntry> expenses = const [],
}) async {
  final ledgerState = LedgerState.initial().copyWith(expenses: expenses);
  final notifier = _FakeLedgerNotifier(ledgerState);
  final container = ProviderContainer(
    overrides: [
      ledgerProvider.overrideWith(() => notifier),
      travelProvider.overrideWith(
        () => _FakeTravelNotifier(<Trip>[trip, ?otherTrip], trip.id),
      ),
      localizedStringsProvider.overrideWithValue(const <String, String>{
        'datetime': '날짜',
        'categoryLabel': '소비구분',
        'subcategoryLabel': '소비 소구분',
        'paymentMethodLabel': '소비수단',
        'descriptionLabel': '내용',
        'amountLabel': '금액',
        'noteLabel': '메모',
        'expenseRequiredFieldsHint': '* 필수 항목',
        'expenseDescriptionSuggestions': '이번 달 자주 입력한 내용',
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
        home: Scaffold(
          body: _ExpenseEditorLauncher(
            initialDate: initialDate,
            initialTripId: initialTripId,
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('입력 열기'));
  await tester.pumpAndSettle();
  return notifier;
}

class _ExpenseEditorLauncher extends ConsumerWidget {
  const _ExpenseEditorLauncher({required this.initialDate, this.initialTripId});

  final DateTime initialDate;
  final String? initialTripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton(
        onPressed: () => showExpenseEditorSheet(
          context: context,
          ref: ref,
          initialDate: initialDate,
          initialTripId: initialTripId,
        ),
        child: const Text('입력 열기'),
      ),
    );
  }
}

class _FakeLedgerNotifier extends LedgerNotifier {
  _FakeLedgerNotifier(this.ledgerState);

  final LedgerState ledgerState;
  ExpenseEntry? saved;

  @override
  Future<void> addExpense(ExpenseEntry entry) async {
    saved = entry;
  }

  @override
  Future<LedgerState> build() async => ledgerState;
}

class _FakeTravelNotifier extends TravelNotifier {
  _FakeTravelNotifier(this.trips, this.activeTripId);

  final List<Trip> trips;
  final String activeTripId;

  @override
  Future<TravelState> build() async {
    return TravelState(trips: trips, activeTripId: activeTripId);
  }
}
