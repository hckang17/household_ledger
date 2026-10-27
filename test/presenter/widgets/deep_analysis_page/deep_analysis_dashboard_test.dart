import '../../../support/deep_analysis_fixture.dart';
import 'package:household_ledger/features/analysis/calculators/deep_analysis_calculator.dart';
import 'dart:async';
import 'package:household_ledger/presenter/widgets/common/typewriter_text.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/features/analysis/models/deep_analysis_report.dart';
import 'package:household_ledger/presenter/pages/sub_page/deep_analysis_page.dart';
import 'package:household_ledger/presenter/widgets/deep_analysis_page/deep_analysis_dashboard.dart';
import 'package:household_ledger/provider/deep_analysis_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';

Map<String, String> strings(String locale) => Map<String, String>.from(
  jsonDecode(File('assets/language_data/$locale.json').readAsStringSync())
      as Map,
);

void main() {
  for (final locale in ['ko', 'jp']) {
    testWidgets('$locale narrow screen, enlarged text and period selection', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = strings(locale);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: DeepAnalysisDashboard(
                report: deepAnalysisPreview,
                strings: s,
              ),
            ),
          ),
        ),
      );
      final introduction = find.descendant(
        of: find.byType(TypewriterText),
        matching: find.byType(Text),
      );
      String visibleIntroduction() =>
          ((tester.widget<Text>(introduction).textSpan! as TextSpan)
                      .children!
                      .first
                  as TextSpan)
              .text!;
      expect(visibleIntroduction(), isEmpty);
      await tester.pumpAndSettle();
      expect(visibleIntroduction(), s['deepHeroNote']);
      expect(tester.takeException(), isNull);
      final button = find.byKey(const ValueKey('baseline-6'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(visibleIntroduction(), s['deepHeroNote']);
      await tester.pumpAndSettle();
      expect(find.textContaining('+190,000'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('baseline-12')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('IKEA').first);
      await tester.tap(find.text('IKEA').first);
      await tester.pumpAndSettle();
      expect(find.text(s['deepClose']!), findsOneWidget);
      await tester.tap(find.text(s['deepClose']!));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(s['deepFixedTitle']!));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty processed report has an explicit empty state', (
    tester,
  ) async {
    final report = DeepAnalysisReport(
      month: DateTime(2026, 9),
      total: 0,
      fixedTotal: 0,
      fixedShare: 0,
      topShare: 0,
      withoutTop: 0,
      baselines: const [],
      trend: const [],
      largeExpenses: const [],
      fixedBreakdown: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeepAnalysisDashboard(report: report, strings: strings('ko')),
        ),
      ),
    );
    expect(find.text(strings('ko')['deepEmpty']!), findsOneWidget);
  });

  testWidgets('loading, failure and retry preserve async states', (
    tester,
  ) async {
    final pending = Completer<DeepAnalysisSnapshot>();
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localizedStringsProvider.overrideWithValue(strings('ko')),
          deepAnalysisLoaderProvider.overrideWithValue((month, today) {
            attempts++;
            return attempts == 1
                ? pending.future
                : Future<DeepAnalysisSnapshot>.value((
                    input: (
                      month: month,
                      today: today,
                      expenses: <Never>[],
                      fixedExpenses: <Never>[],
                    ),
                    labels: <String, String>{},
                  ));
          }),
          deepAnalysisRunnerProvider.overrideWithValue(
            (DeepAnalysisInput input) async => deepAnalysisPreview,
          ),
        ],
        child: const MaterialApp(home: DeepAnalysisPage()),
      ),
    );
    expect(attempts, 0);
    expect(find.byType(DeepAnalysisDashboard), findsNothing);
    await tester.tap(find.text(strings('ko')['deepGenerate']!));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('test failure'));
    await tester.pumpAndSettle();
    expect(find.text(strings('ko')['deepLoadError']!), findsOneWidget);
    await tester.tap(find.text(strings('ko')['deepRetry']!));
    await tester.pumpAndSettle();
    expect(find.byType(DeepAnalysisDashboard), findsOneWidget);
  });

  testWidgets('desktop layout and optional visual preview', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (Platform.environment['DEEP_PREVIEW'] == '1') {
      final icons = File(
        'C:/BuildApps/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (icons.existsSync()) {
        final loader = FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
        await loader.load();
      }
      final font = File('C:/Windows/Fonts/malgun.ttf');
      if (font.existsSync()) {
        final loader = FontLoader('PreviewFont')
          ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
        await loader.load();
      }
    }
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'PreviewFont'),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F7F5),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: DeepAnalysisDashboard(
                report: deepAnalysisPreview,
                strings: strings('ko'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (Platform.environment['DEEP_PREVIEW'] == '1') {
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/deep_analysis_preview').createSync(recursive: true);
        File(
          'build/deep_analysis_preview/desktop.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
