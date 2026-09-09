import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/data_managing_page/bulk_expense_classification_fields.dart';

void main() {
  testWidgets('여행 소구분을 선택하면 활성 여행을 기본 연결한다', (WidgetTester tester) async {
    final trip = Trip.create(
      id: 'trip-active',
      name: '가을 여행',
      startDate: DateTime(2026, 9, 3),
      endDate: DateTime(2026, 9, 5),
    );
    BulkExpenseClassificationChange? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BulkExpenseClassificationFields(
            subcategoryTags: const <MetadataTag>[
              MetadataTag(
                type: MetadataTagType.subcategory,
                code: '_',
                label: '평상시',
              ),
              MetadataTag(
                type: MetadataTagType.subcategory,
                code: 't',
                label: '여행',
              ),
            ],
            trips: <Trip>[trip],
            activeTripId: trip.id,
            strings: const <String, String>{
              'subcategoryLabel': '소비 소구분',
              'dataManageNoChange': '변경 안함',
              'dataManageTripChangeLabel': '여행 연결',
              'dataManageTripChangeHint': '여행 연결 안내',
              'travelUnassignedLabel': '미지정',
            },
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('여행').last);
    await tester.pumpAndSettle();

    expect(changed?.subcategoryCode, 't');
    expect(changed?.changeTripId, isTrue);
    expect(changed?.tripId, trip.id);
    expect(find.text('여행 연결 안내'), findsOneWidget);
  });
}
