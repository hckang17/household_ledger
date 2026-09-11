import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('배경 저장 후 시작 설정을 다시 읽으면 선택이 보존된다', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [ledgerProvider.overrideWith(_Ledger.new)],
    );
    addTearDown(container.dispose);
    await container.read(ledgerProvider.future);
    final notifier = container.read(ledgerProvider.notifier);
    await notifier.changeAppBackground(TravelGradientPalette.sunset);
    var startup = LocalStorageService.readStartupSettings(preferences);
    expect(startup.useGradientBackground, isTrue);
    expect(startup.travelGradientPalette, TravelGradientPalette.sunset);
    await notifier.changeAppBackground(null);
    startup = LocalStorageService.readStartupSettings(preferences);
    expect(startup.useGradientBackground, isFalse);
    expect(startup.travelGradientPalette, TravelGradientPalette.sunset);
    final persisted = jsonDecode(
      preferences.getString(LocalStorageService.storageKey)!,
    );
    expect(persisted.containsKey('expenses'), isFalse);
  });

  test('저장 실패는 화면의 배경 설정을 바꾸지 않는다', () async {
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWith(_Ledger.new),
        localStorageServiceProvider.overrideWithValue(_FailingStorage()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(ledgerProvider.future);
    await expectLater(
      container
          .read(ledgerProvider.notifier)
          .changeAppBackground(TravelGradientPalette.ocean),
      throwsStateError,
    );
    expect(
      container
          .read(ledgerProvider)
          .requireValue
          .settings
          .useGradientBackground,
      isFalse,
    );
  });

  test('시작 설정은 구버전·손상 데이터에서 안전하게 읽힌다', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      LocalStorageService.storageKey,
      jsonEncode({
        'settings': {'travelGradientPalette': 'ocean'},
      }),
    );
    expect(
      LocalStorageService.readStartupSettings(
        preferences,
      ).useGradientBackground,
      isTrue,
    );
    for (final raw in [
      'invalid',
      '[]',
      '{"settings":42}',
      '{"settings":{"useGradientBackground":"wrong"}}',
    ]) {
      await preferences.setString(LocalStorageService.storageKey, raw);
      expect(
        LocalStorageService.readStartupSettings(
          preferences,
        ).useGradientBackground,
        isFalse,
      );
    }
  });
}

class _Ledger extends LedgerNotifier {
  @override
  Future<LedgerState> build() async => LedgerState.initial();
}

class _FailingStorage extends LocalStorageService {
  @override
  Future<void> saveState(LedgerState state) async =>
      throw StateError('save failed');
}
