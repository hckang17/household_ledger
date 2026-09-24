import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/data_search_filter.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/pages/sub_page/data_managing_page.dart';
import 'package:household_ledger/provider/data_manage_provider.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';

void main() {
  testWidgets('검색 완료 결과를 인위적인 1.5초 대기 없이 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWith(
          () => _FakeLedgerNotifier(LedgerState.initial()),
        ),
        travelProvider.overrideWith(
          () => _FakeTravelNotifier(
            Trip.create(
              id: 'trip-a',
              name: '여행',
              startDate: DateTime(2026, 9, 1),
              endDate: DateTime(2026, 9, 2),
            ),
          ),
        ),
        dataManageProvider.overrideWith(_ImmediateSearchNotifier.new),
        localizedStringsProvider.overrideWithValue(const <String, String>{
          'dataManageTitle': '데이터 관리',
          'dataManageFilterTitle': '검색 조건',
          'dataManageTableExpense': '소비기록',
          'dataManageTableFixed': '고정지출',
          'dataManageTableIncome': '수입',
          'dataManageAllPeriod': '전체',
          'dataManageMonthPeriod': '특정 달',
          'dataManageRangePeriod': '기간 지정',
          'dataManageAll': '전체',
          'dataManageResultCount': '건',
          'dataManageSelectAll': '전체선택',
          'dataManageUnselectAll': '전체해제',
          'paymentMethodLabel': '소비수단',
          'categoryLabel': '소비구분',
          'subcategoryLabel': '소비 소구분',
          'descriptionLabel': '내용',
          'noteLabel': '비고',
          'dataManageSearch': '검색',
          'dataManageSearching1': '검색 중',
          'dataManageSearching2': '검색 중',
          'dataManageSearching3': '검색 중',
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(ledgerProvider.future);
    await container.read(travelProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DataManagingPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('검색'));
    await tester.pump();
    await tester.pump();

    expect(find.text('즉시 표시 결과'), findsOneWidget);
    expect(find.text('검색 중'), findsNothing);
  });

  testWidgets('소비 소구분 검색과 여행 연결 일괄 변경 UI를 표시한다', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final trip = Trip.create(
      id: 'trip-a',
      name: '가을 여행',
      startDate: DateTime(2026, 9, 3),
      endDate: DateTime(2026, 9, 5),
    );
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWith(
          () => _FakeLedgerNotifier(LedgerState.initial()),
        ),
        travelProvider.overrideWith(() => _FakeTravelNotifier(trip)),
        dataManageProvider.overrideWith(_FakeDataManageNotifier.new),
        localizedStringsProvider.overrideWithValue(const <String, String>{
          'dataManageTitle': '데이터 관리',
          'dataManageFilterTitle': '검색 조건',
          'dataManageTableExpense': '소비기록',
          'dataManageTableFixed': '고정지출',
          'dataManageTableIncome': '수입',
          'dataManageAllPeriod': '전체',
          'dataManageMonthPeriod': '특정 달',
          'dataManageRangePeriod': '기간 지정',
          'dataManageAll': '전체',
          'dataManageResultCount': '건',
          'dataManageSelectAll': '전체선택',
          'dataManageUnselectAll': '전체해제',
          'dataManageDeleteSelected': '선택삭제',
          'dataManageChangeTag': '태그변경',
          'dataManageChangeTagTitle': '태그 일괄 변경',
          'dataManageSelectedCount': '건 선택됨',
          'dataManageNoChange': '변경 안함',
          'dataManageTripChangeLabel': '여행 연결',
          'paymentMethodLabel': '소비수단',
          'categoryLabel': '소비구분',
          'subcategoryLabel': '소비 소구분',
          'travelUnassignedLabel': '미지정',
          'descriptionLabel': '내용',
          'noteLabel': '비고',
          'dataManageSearch': '검색',
          'dataManageChangeTagApply': '변경 적용',
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(ledgerProvider.future);
    await container.read(travelProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DataManagingPage()),
      ),
    );
    await tester.pump();

    expect(find.text('소비 소구분'), findsOneWidget);

    await tester.ensureVisible(find.text('태그변경'));
    await tester.tap(find.text('태그변경'));
    await tester.pumpAndSettle();

    expect(find.text('태그 일괄 변경'), findsOneWidget);
    expect(find.text('여행 연결'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeLedgerNotifier extends LedgerNotifier {
  _FakeLedgerNotifier(this.value);

  final LedgerState value;

  @override
  Future<LedgerState> build() async => value;
}

class _FakeTravelNotifier extends TravelNotifier {
  _FakeTravelNotifier(this.trip);

  final Trip trip;

  @override
  Future<TravelState> build() async {
    return TravelState(trips: <Trip>[trip], activeTripId: trip.id);
  }
}

class _FakeDataManageNotifier extends DataManageNotifier {
  @override
  DataManageState build() {
    return DataManageState(
      filter: const DataSearchFilter(tableType: DataTableType.expense),
      expenses: <ExpenseEntry>[
        ExpenseEntry.create(
          id: 'expense-a',
          spentAt: DateTime(2026, 8, 1),
          categoryCode: 'E',
          description: '항공권',
          amount: 100000,
        ),
      ],
      searchedTableType: DataTableType.expense,
      selectedIds: const <String>{'expense-a'},
      status: DataManageStatus.found,
    );
  }
}

class _ImmediateSearchNotifier extends DataManageNotifier {
  @override
  DataManageState build() => const DataManageState(
    filter: DataSearchFilter(tableType: DataTableType.expense),
  );

  @override
  Future<void> search() async {
    state = state.copyWith(status: DataManageStatus.searching);
    await Future<void>.value();
    state = state.copyWith(
      status: DataManageStatus.found,
      searchedTableType: DataTableType.expense,
      expenses: <ExpenseEntry>[
        ExpenseEntry.create(
          id: 'instant',
          spentAt: DateTime(2026, 9, 1),
          categoryCode: 'E',
          description: '즉시 표시 결과',
          amount: 1000,
        ),
      ],
    );
  }
}
