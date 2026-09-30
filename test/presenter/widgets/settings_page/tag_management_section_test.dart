import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/settings_page/tag_management_section.dart';

void main() {
  testWidgets('태그 관리 아이콘은 동작과 대상을 알리고 48dp 터치 영역을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.8),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TagManagementSection(
                title: '支出カテゴリー',
                tags: const <MetadataTag>[
                  MetadataTag(
                    type: MetadataTagType.category,
                    code: 'u1',
                    label: 'ユーザー分類',
                  ),
                ],
                strings: const <String, String>{
                  'addTag': 'タグ追加',
                  'edit': '編集',
                  'delete': '削除',
                  'expandSection': '展開',
                  'collapseSection': '折りたたむ',
                },
                onAdd: () {},
                onEdit: (_) {},
                onDelete: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('支出カテゴリー タグ追加'), findsOneWidget);
    expect(find.byTooltip('展開'), findsOneWidget);
    expect(find.bySemanticsLabel('支出カテゴリー 展開'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('支出カテゴリー タグ追加')).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byTooltip('展開'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('ユーザー分類 編集'), findsOneWidget);
    expect(find.byTooltip('ユーザー分類 削除'), findsOneWidget);
    expect(
      tester.getSize(find.byTooltip('ユーザー分類 編集')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byTooltip('ユーザー分類 削除')).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}
