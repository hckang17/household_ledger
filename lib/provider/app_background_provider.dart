import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/app_settings.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:household_ledger/provider/ledger_provider.dart';

/// 첫 Flutter 프레임 전에 읽은 설정. 앱 재시작 시 저장소 캐시에서 다시 읽는다.
final startupSettingsProvider = Provider<AppSettings>(
  (ref) => AppSettings.initial(),
);

typedef AppBackgroundPreference = ({
  bool useGradient,
  TravelGradientPalette palette,
});

final appBackgroundProvider =
    NotifierProvider<AppBackgroundNotifier, AppBackgroundPreference>(
      AppBackgroundNotifier.new,
    );

/// 가계부를 재조회하는 동안에도 마지막 배경을 유지한다.
class AppBackgroundNotifier extends Notifier<AppBackgroundPreference> {
  @override
  AppBackgroundPreference build() {
    ref.listen(ledgerProvider, (_, next) {
      final settings = next.asData?.value.settings;
      if (settings != null) state = _preference(settings);
    });
    return _preference(
      ref.read(ledgerProvider).asData?.value.settings ??
          ref.read(startupSettingsProvider),
    );
  }

  AppBackgroundPreference _preference(AppSettings settings) => (
    useGradient: settings.useGradientBackground,
    palette: settings.travelGradientPalette,
  );
}
