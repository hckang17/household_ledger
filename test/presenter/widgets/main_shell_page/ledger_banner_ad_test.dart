import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:household_ledger/presenter/widgets/main_shell_page/ledger_banner_ad.dart';
import 'package:household_ledger/presenter/widgets/main_shell_page/main_shell_bottom_bar.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/nav_tab_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/services/ads/mobile_ads_service.dart';

import '../../../support/ads_platform_fake.dart';

class _DelayedService extends MobileAdsService {
  final result = Completer<AdsAvailability>();
  @override
  Future<AdsAvailability> prepare() => result.future;
}

void main() {
  late AdsPlatformFake platform;
  late MobileAdsService service;
  late Map<String, String> strings;

  setUp(() {
    platform = AdsPlatformFake()..install();
    service = MobileAdsService();
    strings = Map<String, String>.from(
      jsonDecode(File('assets/language_data/ko.json').readAsStringSync())
          as Map,
    );
  });
  tearDown(() {
    platform.uninstall();
    debugDefaultTargetPlatformOverride = null;
  });

  Widget page() => MaterialApp(
    home: Scaffold(
      body: const Center(child: Text('Ledger')),
      bottomNavigationBar: LedgerBannerAd(strings: strings, service: service),
    ),
  );

  testWidgets('loading and failed ads occupy no space; request is a test ad', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(LedgerBannerAd)).height, 0);
    final ad = platform.lastBanner;
    expect(ad.adUnitId, MobileAdsService.testBannerId);
    ad.listener.onAdFailedToLoad!(ad, LoadAdError(3, 'test', 'no fill', null));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(LedgerBannerAd)).height, 0);
    expect(platform.named('disposeAd'), hasLength(1));
    expect(find.text('Ledger'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loaded banner fits small screen and reloads after width change',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      final ad = platform.lastBanner;
      ad.listener.onAdLoaded!(ad);
      await tester.pumpAndSettle();
      expect(find.byType(AdWidget), findsOneWidget);
      expect(tester.getSize(find.byType(AdWidget)), const Size(320, 50));
      expect(tester.getSize(find.byType(LedgerBannerAd)).height, 58);
      await tester.binding.setSurfaceSize(const Size(568, 320));
      await tester.pumpAndSettle();
      expect(platform.named('disposeAd'), hasLength(1));
      expect(platform.named('loadBannerAd'), hasLength(2));
      expect(platform.lastBanner.size, AdSize.banner);
      final rotated = platform.lastBanner;
      rotated.listener.onAdLoaded!(rotated);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(LedgerBannerAd)).height, 58);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(platform.named('disposeAd'), hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving while consent is pending never loads an ad', (
    tester,
  ) async {
    final delayed = _DelayedService();
    service = delayed;
    await tester.pumpWidget(page());
    await tester.pumpWidget(const SizedBox.shrink());
    delayed.result.complete(
      const AdsAvailability(canRequestAds: true, privacyOptionsRequired: false),
    );
    await tester.pumpAndSettle();
    expect(platform.named('loadBannerAd'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('platform loading error leaves the ledger usable', (
    tester,
  ) async {
    platform.loadThrows = true;
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.byType(AdWidget), findsNothing);
    expect(platform.named('disposeAd'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('consent change disposes an ad that has not finished loading', (
    tester,
  ) async {
    platform.privacyRequired = true;
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    final previous = platform.lastBanner;
    platform.allowed = false;
    await tester.tap(find.text(strings['adPrivacyOptions']!));
    await tester.pumpAndSettle();
    previous.listener.onAdLoaded!(previous);
    await tester.pumpAndSettle();
    expect(platform.named('loadBannerAd'), hasLength(1));
    expect(platform.named('disposeAd'), hasLength(1));
    expect(find.byType(AdWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screen omits banner without clipping or overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(platform.named('loadBannerAd'), isEmpty);
    expect(tester.getSize(find.byType(LedgerBannerAd)).height, 0);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['ko', 'jp']) {
    testWidgets('$locale privacy control remains available without an ad', (
      tester,
    ) async {
      strings = Map<String, String>.from(
        jsonDecode(File('assets/language_data/$locale.json').readAsStringSync())
            as Map,
      );
      platform.allowed = false;
      platform.privacyRequired = true;
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(platform.named('loadBannerAd'), isEmpty);
      await tester.tap(find.text(strings['adPrivacyOptions']!));
      await tester.pumpAndSettle();
      expect(
        platform.named('UserMessagingPlatform#showPrivacyOptionsForm'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'shell shares one banner across all five tabs, hides in tutorial and keyboard',
    (tester) async {
      final container = ProviderContainer(
        overrides: [localizedStringsProvider.overrideWithValue(strings)],
      );
      addTearDown(container.dispose);
      Widget shell({double keyboard = 0}) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: const Scaffold(bottomNavigationBar: MainShellBottomBar()),
          ),
        ),
      );
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      expect(find.byType(LedgerBannerAd), findsOneWidget);
      final first = platform.lastBanner;
      container.read(currentNavTabProvider.notifier).setTab(3);
      await tester.pumpAndSettle();
      expect(find.byType(LedgerBannerAd), findsOneWidget);
      expect(platform.lastBanner, same(first));
      for (final tab in [0, 1, 4]) {
        container.read(currentNavTabProvider.notifier).setTab(tab);
        await tester.pumpAndSettle();
        expect(find.byType(LedgerBannerAd), findsOneWidget);
        expect(platform.lastBanner, same(first));
      }
      expect(platform.named('loadBannerAd'), hasLength(1));
      expect(platform.named('disposeAd'), isEmpty);
      container.read(currentNavTabProvider.notifier).setTab(2);
      await tester.pumpWidget(shell(keyboard: 200));
      await tester.pumpAndSettle();
      expect(find.byType(LedgerBannerAd), findsNothing);
      expect(platform.named('disposeAd'), hasLength(1));
      container.read(tutorialProvider.notifier).startTutorial();
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      expect(find.byType(LedgerBannerAd), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Windows has no blank banner space or plugin calls', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(LedgerBannerAd)).height, 0);
    expect(platform.calls, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });
}
