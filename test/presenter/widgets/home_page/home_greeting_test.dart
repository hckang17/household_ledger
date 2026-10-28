import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/presenter/widgets/common/typewriter_text.dart';
import 'package:household_ledger/presenter/widgets/home_page/home_greeting.dart';

Map<String, String> strings(String locale) =>
    (jsonDecode(File('assets/language_data/$locale.json').readAsStringSync())
            as Map<String, dynamic>)
        .cast<String, String>();

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: SizedBox(width: 280, child: child)),
  ),
);

String visible(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byType(TypewriterText),
      matching: find.byType(Text),
    ),
  );
  return ((text.textSpan! as TextSpan).children!.first as TextSpan).text!;
}

void main() {
  testWidgets('waits for data, keeps selection and never replays on refresh', (
    tester,
  ) async {
    final ko = strings('ko');
    Widget greeting(String? name, Map<String, String> data) =>
        host(HomeGreeting(name: name, strings: data));
    await tester.pumpWidget(greeting(null, {}));
    expect(find.byType(TypewriterText), findsNothing);
    await tester.pumpWidget(greeting('민수', ko));
    expect(visible(tester), isEmpty);
    final selected = tester
        .widget<TypewriterText>(find.byType(TypewriterText))
        .text;
    await tester.pumpAndSettle();
    expect(visible(tester), selected);
    await tester.pumpWidget(greeting(null, {}));
    expect(visible(tester), selected);
    await tester.pumpWidget(greeting('민수', ko));
    expect(visible(tester), selected);
    await tester.pumpWidget(greeting('美咲', strings('jp')));
    expect(
      visible(tester),
      tester.widget<TypewriterText>(find.byType(TypewriterText)).text,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fast opening, slower ending, stable layout and full semantics', (
    tester,
  ) async {
    const text = '가나다라마바사아자차';
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(const TypewriterText(text: text, animate: true, slowEnding: true)),
    );
    final initialSize = tester.getSize(find.byType(TypewriterText));
    expect(find.bySemanticsLabel(text), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));
    expect(visible(tester), '가나다라');
    await tester.pump(const Duration(milliseconds: 70));
    expect(visible(tester), '가나다라');
    await tester.pump(const Duration(milliseconds: 20));
    expect(visible(tester), '가나다라마');
    await tester.pumpAndSettle();
    expect(visible(tester), text);
    expect(tester.getSize(find.byType(TypewriterText)), initialSize);
    semantics.dispose();
  });

  for (final locale in ['ko', 'jp']) {
    testWidgets(
      '$locale long greeting fits narrow screen and respects reduced motion',
      (tester) async {
        final data = strings(locale);
        for (var i = 1; i <= 10; i++) {
          final text = data['homeGreeting$i']!.replaceAll(
            '{name}',
            '아주 긴 사용자 이름 美咲',
          );
          await tester.pumpWidget(
            host(
              TypewriterText(
                text: text,
                animate: true,
                slowEnding: true,
                style: const TextStyle(fontSize: 32),
              ),
              reduced: true,
            ),
          );
          expect(visible(tester), text);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('empty name uses a greeting without a salutation', (
    tester,
  ) async {
    final ko = strings('ko');
    await tester.pumpWidget(
      host(HomeGreeting(name: '', strings: ko), reduced: true),
    );
    expect(visible(tester), ko['homeGreeting7']);
  });

  testWidgets('disposing during typing leaves no pending work', (tester) async {
    await tester.pumpWidget(
      host(HomeGreeting(name: '민수', strings: strings('ko'))),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
