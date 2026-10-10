import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:household_ledger/services/ads/mobile_ads_service.dart';

/// 메인 쉘의 모든 탭에서 공유하는 높이 50의 표준 배너다.
/// 키보드와 튜토리얼 중에는 호출부가 제거하며, 미지원 플랫폼은 공간도 차지하지 않는다.
class LedgerBannerAd extends StatelessWidget {
  const LedgerBannerAd({super.key, required this.strings, this.service});

  final Map<String, String> strings;
  final MobileAdsService? service;

  @override
  Widget build(BuildContext context) {
    final ads = service ?? MobileAdsService.instance;
    if (!ads.isSupported) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.floor();
          if (width < 1) return const SizedBox.shrink();
          final orientation = MediaQuery.orientationOf(context);
          return _BannerSlot(
            key: ValueKey('$width/$orientation'),
            availableWidth: width,
            service: ads,
            strings: strings,
          );
        },
      ),
    );
  }
}

class _BannerSlot extends StatefulWidget {
  const _BannerSlot({
    super.key,
    required this.availableWidth,
    required this.service,
    required this.strings,
  });

  final int availableWidth;
  final MobileAdsService service;
  final Map<String, String> strings;

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  BannerAd? _banner;
  bool _loaded = false;
  bool _privacyRequired = false;
  bool _changingPrivacy = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load({AdsAvailability? availability}) async {
    final generation = ++_requestGeneration;
    try {
      final status = availability ?? await widget.service.prepare();
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _privacyRequired = status.privacyOptionsRequired);
      // 광고 자체를 자르거나 축소하지 않고, 표준 배너가 들어갈 때만 요청한다.
      if (!status.canRequestAds ||
          widget.availableWidth < AdSize.banner.width) {
        return;
      }
      final banner = BannerAd(
        adUnitId: widget.service.bannerId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted && identical(_banner, ad)) {
              setState(() => _loaded = true);
            }
          },
          onAdFailedToLoad: (ad, error) {
            if (mounted && identical(_banner, ad)) {
              setState(() {
                _banner = null;
                _loaded = false;
              });
            }
            unawaited(ad.dispose());
          },
        ),
      );
      _banner = banner;
      await banner.load();
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      // 네트워크/플러그인 실패로 가계부 화면에 오류를 전파하지 않는다.
      final banner = _banner;
      _banner = null;
      if (mounted) setState(() => _loaded = false);
      if (banner != null) unawaited(banner.dispose());
    }
  }

  Future<void> _showPrivacyOptions() async {
    // 동의 설정 진입 전부터 진행 중이던 광고 요청을 무효화한다.
    _requestGeneration++;
    final previous = _banner;
    setState(() {
      _changingPrivacy = true;
      _loaded = false;
      _banner = null;
    });
    // 기존 플랫폼 뷰를 먼저 제거한 뒤 광고 리소스를 해제한다.
    await WidgetsBinding.instance.endOfFrame;
    await previous?.dispose();
    if (!mounted) return;
    try {
      final status = await widget.service.showPrivacyOptions();
      if (mounted) await _load(availability: status);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.strings['adPrivacyOptionsError']!)),
        );
      }
    } finally {
      if (mounted) setState(() => _changingPrivacy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_banner?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!_loaded && !_privacyRequired) return const SizedBox.shrink();
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_loaded && banner != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: SizedBox(
                  width: banner.size.width.toDouble(),
                  height: banner.size.height.toDouble(),
                  child: AdWidget(ad: banner),
                ),
              ),
            ),
          if (_privacyRequired)
            TextButton(
              onPressed: _changingPrivacy ? null : _showPrivacyOptions,
              child: Text(
                widget.strings['adPrivacyOptions']!,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
