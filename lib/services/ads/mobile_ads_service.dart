import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UMP가 판단한 광고 요청 가능 여부와 개인정보 선택 화면의 필요 여부다.
class AdsAvailability {
  const AdsAvailability({
    required this.canRequestAds,
    required this.privacyOptionsRequired,
  });

  final bool canRequestAds;
  final bool privacyOptionsRequired;
}

/// Android 광고 초기화와 동의 확인을 세션 내에서 공유한다.
/// 가계부 데이터는 광고 요청에 전달하지 않는다.
class MobileAdsService {
  static final instance = MobileAdsService();

  static const productionBannerId = 'ca-app-pub-2692116402537120/2562704214';
  static const testBannerId = 'ca-app-pub-3940256099942544/9214589741';

  /// 프로파일/디버그는 항상 테스트 광고를 사용한다. 릴리즈 기기 검증도
  /// --dart-define=ADMOB_TEST_ADS=true로 실제 광고 요청 없이 진행할 수 있다.
  String get bannerId =>
      !kReleaseMode || const bool.fromEnvironment('ADMOB_TEST_ADS')
      ? testBannerId
      : productionBannerId;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<AdsAvailability>? _preparation;
  Future<InitializationStatus>? _initialization;

  Future<AdsAvailability> prepare() async {
    if (!isSupported) {
      return const AdsAvailability(
        canRequestAds: false,
        privacyOptionsRequired: false,
      );
    }
    try {
      final availability = await (_preparation ??= _prepare());
      // 오프라인 등으로 동의를 확인하지 못했다면 다음 진입 때 재시도한다.
      if (!availability.canRequestAds) _preparation = null;
      return availability;
    } catch (_) {
      _preparation = null;
      rethrow;
    }
  }

  Future<AdsAvailability> _prepare() async {
    final updated = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => updated.complete(true),
      (_) => updated.complete(false),
    );
    if (await updated.future) {
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    }
    return _readAvailability();
  }

  Future<AdsAvailability> _readAvailability() async {
    final canRequest = await ConsentInformation.instance.canRequestAds();
    final privacyRequired =
        await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (canRequest) {
      try {
        await (_initialization ??= MobileAds.instance.initialize());
      } catch (_) {
        _initialization = null;
        rethrow;
      }
    }
    return AdsAvailability(
      canRequestAds: canRequest,
      privacyOptionsRequired: privacyRequired,
    );
  }

  /// 동의 변경 후 광고는 최신 UMP 상태를 확인한 뒤 다시 생성한다.
  Future<AdsAvailability> showPrivacyOptions() async {
    if (!isSupported) return prepare();
    FormError? error;
    await ConsentForm.showPrivacyOptionsForm((value) => error = value);
    _preparation = null;
    if (error != null) throw StateError('Privacy options unavailable');
    final availability = await _readAvailability();
    _preparation = Future.value(availability);
    return availability;
  }
}
