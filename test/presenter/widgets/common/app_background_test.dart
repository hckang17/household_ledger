import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/app_settings.dart';
import 'package:household_ledger/main.dart' show AppRestartWidget;
import 'package:household_ledger/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:household_ledger/presenter/extensions/travel_gradient_palette_extension.dart';
import 'package:household_ledger/presenter/widgets/common/app_background.dart';
import 'package:household_ledger/provider/app_background_provider.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';

void main() {
  testWidgets('앱 내부 재시작 시 초기 스냅샷 대신 최신 저장 배경을 첫 프레임에 읽는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings.initial().copyWith(
      useGradientBackground: true,
      travelGradientPalette: TravelGradientPalette.forest,
    );
    await preferences.setString(
      LocalStorageService.storageKey,
      jsonEncode({'settings': settings.toJson()}),
    );
    await tester.pumpWidget(
      AppRestartWidget(
        child: ProviderScope(
          overrides: [
            startupSettingsProvider.overrideWith(
              (ref) => LocalStorageService.readStartupSettings(preferences),
            ),
            ledgerProvider.overrideWith(
              () => _Ledger(Completer<LedgerState>().future),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: AppBackground(child: child!),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => AppRestartWidget.restartApp(context),
                  child: const Text('restart'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('app-gradient')), findsOneWidget);
    await preferences.setString(
      LocalStorageService.storageKey,
      jsonEncode({
        'settings': settings.copyWith(useGradientBackground: false).toJson(),
      }),
    );
    await tester.tap(find.text('restart'));
    await tester.pump();
    expect(find.byKey(const ValueKey('app-gradient')), findsNothing);
  });

  for (final gradient in [true, false]) {
    testWidgets('첫 프레임에 저장된 배경 적용: gradient=$gradient, 여행 및 DB 로딩 독립', (
      tester,
    ) async {
      final delayed = Completer<LedgerState>();
      final settings = AppSettings.initial().copyWith(
        useGradientBackground: gradient,
        travelGradientPalette: TravelGradientPalette.ocean,
      );
      final container = ProviderContainer(
        overrides: [
          startupSettingsProvider.overrideWithValue(settings),
          ledgerProvider.overrideWith(() => _Ledger(delayed.future)),
          travelProvider.overrideWith(
            () => throw StateError('Background must not read travel'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container));
      expect(
        find.byKey(const ValueKey('app-gradient')),
        gradient ? findsOneWidget : findsNothing,
      );
      if (gradient) {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('app-gradient')),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          ((box.decoration as BoxDecoration).gradient as LinearGradient).colors,
          TravelGradientPalette.ocean.colors,
        );
      }
      // 여행 상태를 구독하지 않고 첫 화면부터 렌더링한다.
      expect(container.exists(travelProvider), isFalse);
      final background = container.read(appBackgroundProvider);
      delayed.complete(LedgerState.initial().copyWith(settings: settings));
      await tester.pump();
      expect(container.read(appBackgroundProvider), background);
      (container.read(ledgerProvider.notifier) as _Ledger).reload();
      await tester.pump();
      expect(container.read(appBackgroundProvider), background);
    });
  }

  testWidgets('화면 이동·로딩·오류에도 배경을 유지하고 새 선택은 즉시 적용한다', (tester) async {
    final settings = AppSettings.initial().copyWith(
      useGradientBackground: true,
    );
    final container = ProviderContainer(
      overrides: [
        startupSettingsProvider.overrideWithValue(settings),
        ledgerProvider.overrideWith(
          () => _Ledger(
            Future.value(LedgerState.initial().copyWith(settings: settings)),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    final notifier = container.read(ledgerProvider.notifier) as _Ledger;
    notifier.fail();
    await tester.pump();
    expect(find.byKey(const ValueKey('app-gradient')), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('settings')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-gradient')), findsOneWidget);
    notifier.apply(settings.copyWith(useGradientBackground: false));
    await tester.pump();
    expect(find.byKey(const ValueKey('app-gradient')), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('그라데이션 애니메이션은 동작 줄이기 설정을 따른다', (tester) async {
    final container = ProviderContainer(
      overrides: [
        startupSettingsProvider.overrideWithValue(
          AppSettings.initial().copyWith(useGradientBackground: true),
        ),
        ledgerProvider.overrideWith(
          () => _Ledger(Completer<LedgerState>().future),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_app(container, reduceMotion: false));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

Widget _app(ProviderContainer container, {bool reduceMotion = true}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: AppBackground(child: child!),
        ),
        home: const Scaffold(body: Text('first screen')),
      ),
    );

class _Ledger extends LedgerNotifier {
  _Ledger(this.loaded);
  final Future<LedgerState> loaded;
  @override
  Future<LedgerState> build() => loaded;
  void reload() => state = const AsyncLoading();
  void fail() => state = AsyncError(StateError('failure'), StackTrace.empty);
  void apply(AppSettings settings) =>
      state = AsyncData(LedgerState.initial().copyWith(settings: settings));
}
