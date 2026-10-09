import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/services/ads/mobile_ads_service.dart';

import '../../support/ads_platform_fake.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdsPlatformFake platform;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    platform = AdsPlatformFake()..install();
  });
  tearDown(() {
    platform.uninstall();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'concurrent preparation gathers consent and initializes only once',
    () async {
      final service = MobileAdsService();
      final results = await Future.wait([service.prepare(), service.prepare()]);
      expect(results.every((s) => s.canRequestAds), isTrue);
      expect(
        platform.named('ConsentInformation#requestConsentInfoUpdate'),
        hasLength(1),
      );
      expect(platform.named('MobileAds#initialize'), hasLength(1));
      final names = platform.calls.map((c) => c.method).toList();
      expect(
        names.indexOf('ConsentInformation#canRequestAds'),
        lessThan(names.indexOf('MobileAds#initialize')),
      );
      expect(service.bannerId, MobileAdsService.testBannerId);
    },
  );

  test(
    'denied or unknown consent does not initialize SDK and can retry',
    () async {
      platform.allowed = false;
      final service = MobileAdsService();
      expect((await service.prepare()).canRequestAds, isFalse);
      expect(platform.named('MobileAds#initialize'), isEmpty);
      platform.allowed = true;
      expect((await service.prepare()).canRequestAds, isTrue);
      expect(
        platform.named('ConsentInformation#requestConsentInfoUpdate'),
        hasLength(2),
      );
    },
  );

  test('update failure uses only the permission returned by UMP', () async {
    platform.updateFails = true;
    platform.allowed = false;
    final service = MobileAdsService();
    expect((await service.prepare()).canRequestAds, isFalse);
    expect(platform.named('MobileAds#initialize'), isEmpty);
    platform.allowed = true;
    expect((await service.prepare()).canRequestAds, isTrue);
    expect(
      platform.named('UserMessagingPlatform#loadAndShowConsentFormIfRequired'),
      isEmpty,
    );
  });

  test(
    'privacy change replaces previously granted request permission',
    () async {
      platform.privacyRequired = true;
      final service = MobileAdsService();
      expect((await service.prepare()).canRequestAds, isTrue);
      platform.allowed = false;
      final updated = await service.showPrivacyOptions();
      expect(updated.canRequestAds, isFalse);
      expect(updated.privacyOptionsRequired, isTrue);
      expect((await service.prepare()).canRequestAds, isFalse);
    },
  );

  for (final target in [
    TargetPlatform.windows,
    TargetPlatform.iOS,
    TargetPlatform.linux,
  ]) {
    test('$target never invokes the mobile plugin', () async {
      debugDefaultTargetPlatformOverride = target;
      expect((await MobileAdsService().prepare()).canRequestAds, isFalse);
      expect(platform.calls, isEmpty);
    });
  }
}
