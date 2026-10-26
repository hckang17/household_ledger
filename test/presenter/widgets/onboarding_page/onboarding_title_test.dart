import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/presenter/widgets/onboarding_page/onboarding_title.dart';

Widget host(String text, {bool animate = true, bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(1.5),
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OnboardingTitle(
                  text: text,
                  animate: animate,
                  style: const TextStyle(fontSize: 28),
                ),
                TextButton(onPressed: () {}, child: const Text('Continue')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String visibleText(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.descendant(
      of: find.byType(OnboardingTitle),
      matching: find.byType(Text),
    ),
  );
  return ((text.textSpan! as TextSpan).children!.first as TextSpan).text!;
}

void main() {
  for (final title in ['생활비 흐름을 한 화면에서 관리하세요', '生活費の流れを一つの画面で管理できます']) {
    testWidgets('reveals $title without shifting layout or replaying', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(title));
      expect(visibleText(tester), isEmpty);
      expect(find.bySemanticsLabel(title), findsOneWidget);
      semantics.dispose();
      final position = tester.getTopLeft(find.byType(TextButton));
      final size = tester.getSize(find.byType(OnboardingTitle));
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNotNull,
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(visibleText(tester), isNotEmpty);
      expect(visibleText(tester), isNot(title));
      expect(tester.getSize(find.byType(OnboardingTitle)), size);
      expect(tester.getTopLeft(find.byType(TextButton)), position);
      await tester.pumpAndSettle();
      expect(visibleText(tester), title);
      expect(tester.getTopLeft(find.byType(TextButton)), position);
      await tester.pumpWidget(host(title));
      expect(visibleText(tester), title);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows full text for returning users and reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(host('안녕하세요', animate: false));
    expect(visibleText(tester), '안녕하세요');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host('こんにちは', reducedMotion: true));
    expect(visibleText(tester), 'こんにちは');
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'preserves graphemes and stops on preference or language changes',
    (tester) async {
      const text = '👨‍👩‍👧‍👦か\u3099한';
      await tester.pumpWidget(host(text));
      await tester.pump(const Duration(milliseconds: 40));
      expect(visibleText(tester), '👨‍👩‍👧‍👦');
      await tester.pumpWidget(host(text, reducedMotion: true));
      expect(visibleText(tester), text);
      await tester.pumpWidget(host('새로운 문장'));
      expect(visibleText(tester), '새로운 문장');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('handles empty text and leaving during playback', (tester) async {
    await tester.pumpWidget(host(''));
    expect(visibleText(tester), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host('생활비 흐름을 한 화면에서 관리하세요'));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
