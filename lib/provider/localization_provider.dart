import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/services/debugging_logger.dart';
import 'package:household_ledger/services/localization_service.dart';

void _logLocalizationProvider(String methodName, String action) {
  logger.d('[localization_provider.dart] $methodName ( $action )');
}

/// 언어 리소스 서비스를 주입한다.
final localizationServiceProvider = Provider<LocalizationService>((Ref ref) {
  _logLocalizationProvider(
    'localizationServiceProvider',
    'LocalizationService 인스턴스 생성',
  );
  return LocalizationService();
});

/// 현재 언어 문자열을 비동기 로딩한다.
final localizedStringsLoaderProvider = FutureProvider<Map<String, String>>((
  Ref ref,
) async {
  _logLocalizationProvider(
    'localizedStringsLoaderProvider',
    '현재 로케일 문자열 로딩 시작',
  );
  final localeCode = ref.watch(
    ledgerProvider.select(
      (AsyncValue<LedgerState> state) =>
          state.asData?.value.settings.localeCode ?? 'ko',
    ),
  );
  final service = ref.watch(localizationServiceProvider);
  final strings = await service.loadStrings(localeCode);
  _logLocalizationProvider(
    'localizedStringsLoaderProvider',
    '현재 로케일 문자열 로딩 완료',
  );
  return strings;
});

/// 현재 화면에서 즉시 사용할 문자열 맵을 제공한다.
final localizedStringsProvider = Provider<Map<String, String>>((Ref ref) {
  _logLocalizationProvider('localizedStringsProvider', '화면 표시용 문자열 맵 제공');
  final baseStrings =
      ref.watch(localizedStringsLoaderProvider).asData?.value ??
      LocalizationService.fallbackStrings;
  final currencyUnit = ref.watch(
    ledgerProvider.select(
      (AsyncValue<LedgerState> state) =>
          state.asData?.value.settings.currencyUnit ?? '원',
    ),
  );
  return <String, String>{...baseStrings, 'currencyUnit': currencyUnit};
});
