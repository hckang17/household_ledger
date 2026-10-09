// SDK 플랫폼 경계만 대체하고 실제 Dart 광고 수명주기를 검증한다.
// ignore_for_file: implementation_imports
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:google_mobile_ads/src/ump/user_messaging_codec.dart';

class AdsPlatformFake {
  final calls = <MethodCall>[];
  bool allowed = true;
  bool privacyRequired = false;
  bool updateFails = false;
  bool loadThrows = false;
  bool privacyFails = false;

  final ump = MethodChannel(
    'plugins.flutter.io/google_mobile_ads/ump',
    StandardMethodCodec(UserMessagingCodec()),
  );

  void install() {
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'MobileAds#initialize':
          return InitializationStatus(<String, AdapterStatus>{});
        case '_init':
          return null;
        case 'loadBannerAd':
          if (loadThrows) throw PlatformException(code: 'load_failed');
          return null;
        case 'disposeAd':
          return null;
        default:
          throw StateError('Unexpected ads call: ${call.method}');
      }
    });
    messenger.setMockMethodCallHandler(ump, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'ConsentInformation#requestConsentInfoUpdate':
          if (updateFails) throw PlatformException(code: '1');
          return null;
        case 'ConsentInformation#canRequestAds':
          return allowed;
        case 'ConsentInformation#getPrivacyOptionsRequirementStatus':
          return privacyRequired ? 1 : 0;
        case 'UserMessagingPlatform#loadAndShowConsentFormIfRequired':
          return null;
        case 'UserMessagingPlatform#showPrivacyOptionsForm':
          if (privacyFails) throw PlatformException(code: '1');
          return null;
        default:
          throw StateError('Unexpected UMP call: ${call.method}');
      }
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'resize') {
        final args = call.arguments as Map;
        return {'width': args['width'], 'height': args['height']};
      }
      return null;
    });
  }

  List<MethodCall> named(String name) =>
      calls.where((c) => c.method == name).toList();

  BannerAd get lastBanner =>
      instanceManager.adFor(
            (named('loadBannerAd').last.arguments as Map)['adId'] as int,
          )!
          as BannerAd;

  void uninstall() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    messenger.setMockMethodCallHandler(ump, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  }
}
