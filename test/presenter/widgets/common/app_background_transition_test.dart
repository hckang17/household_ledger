import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/app_settings.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/presenter/widgets/common/app_background.dart';
import 'package:household_ledger/presenter/widgets/common/side_bar.dart';
import 'package:household_ledger/provider/app_background_provider.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_page_transitions.dart';
import 'package:household_ledger/router/app_router.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final useGradient in [true, false]) {
      testWidgets('사이드바 이동·뒤로가기 중간 프레임 배경: $platform gradient=$useGradient', (
        tester,
      ) async {
        final settings = AppSettings.initial().copyWith(
          useGradientBackground: useGradient,
        );
        final container = ProviderContainer(
          overrides: [
            startupSettingsProvider.overrideWithValue(settings),
            ledgerProvider.overrideWith(() => _Ledger(settings)),
            localizedStringsProvider.overrideWithValue({
              'sideBarMyPage': 'My page',
            }),
          ],
        );
        addTearDown(container.dispose);
        final capture = GlobalKey();
        final observer = _RouteObserver();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData(
                platform: platform,
                scaffoldBackgroundColor: Colors.transparent,
                pageTransitionsTheme: appPageTransitionsTheme,
              ),
              navigatorObservers: [observer],
              builder: (context, child) => RepaintBoundary(
                key: capture,
                child: AppBackground(child: child!),
              ),
              home: Scaffold(
                endDrawer: const RightSideBar(),
                appBar: AppBar(actions: const [SideBarButton()]),
              ),
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(key: ValueKey('destination')),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        final backgroundElement = tester.element(find.byType(AppBackground));
        final savedPreference = container.read(appBackgroundProvider);

        Future<List<int>> pixels(RenderRepaintBoundary boundary) async {
          final image = await boundary.toImage();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final bytes = data.buffer.asUint8List();
          final result = <int>[];
          // 사이드바와 AppBar를 피해 빈 배경의 세 지점을 비교한다.
          for (final point in [
            const Offset(40, 180),
            const Offset(40, 360),
            const Offset(200, 500),
          ]) {
            final offset =
                (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
            result.add(
              (bytes[offset] << 24) |
                  (bytes[offset + 1] << 16) |
                  (bytes[offset + 2] << 8) |
                  bytes[offset + 3],
            );
          }
          image.dispose();
          return result;
        }

        Future<void> checkFrame({required bool drawerClosed}) async {
          final screen =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final visible = (await tester.runAsync(() => pixels(screen)))!;
          if (useGradient) {
            expect(
              visible.toSet().length,
              greaterThan(1),
              reason: '전환 중 단색 덮개가 그라데이션을 가리면 안 된다',
            );
            if (drawerClosed) {
              final gradient = tester.renderObject<RenderRepaintBoundary>(
                find
                    .descendant(
                      of: find.byType(AppBackground),
                      matching: find.byType(RepaintBoundary),
                    )
                    .first,
              );
              final expected = await tester.runAsync(() => pixels(gradient));
              expect(
                visible,
                expected,
                reason: '전환 중인 화면 픽셀이 실제 애니메이션 배경과 같아야 한다',
              );
            }
          } else if (drawerClosed) {
            expect(visible, everyElement(0xF4F7FBFF));
          }
          expect(container.read(appBackgroundProvider), savedPreference);
          expect(
            identical(
              backgroundElement,
              tester.element(find.byType(AppBackground)),
            ),
            isTrue,
          );
        }

        await checkFrame(drawerClosed: true);
        await tester.tap(find.byIcon(Icons.menu_open_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('My page'));
        await tester.pump();
        final route = observer.latest!;
        expect(route.settings.name, AppRouter.myPageRoute);
        var elapsed = 0;
        for (final delta in [16, 64, 100, 120, 80, 40]) {
          elapsed += delta;
          await tester.pump(Duration(milliseconds: delta));
          expect(
            route.animation!.isAnimating,
            isTrue,
            reason: '완료 후가 아닌 전환 중간 프레임을 검증한다',
          );
          await checkFrame(drawerClosed: elapsed >= 300);
        }
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const ValueKey('destination')), findsOneWidget);
        await checkFrame(drawerClosed: true);

        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump();
        for (final delta in [16, 64, 100, 120, 80, 40]) {
          await tester.pump(Duration(milliseconds: delta));
          expect(route.animation!.isAnimating, isTrue);
          await checkFrame(drawerClosed: true);
        }
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const ValueKey('destination')), findsNothing);
        await checkFrame(drawerClosed: true);
      });
    }
  }
}

class _RouteObserver extends NavigatorObserver {
  PageRoute<dynamic>? latest;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) latest = route;
  }
}

class _Ledger extends LedgerNotifier {
  _Ledger(this.settings);
  final AppSettings settings;
  @override
  Future<LedgerState> build() async =>
      LedgerState.initial().copyWith(settings: settings);
}
