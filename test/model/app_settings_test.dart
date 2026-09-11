import 'package:household_ledger/model/app_settings.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:test/test.dart';

void main() {
  test('새 설치는 단색, 구버전 팔레트는 그라데이션으로 승계한다', () {
    expect(AppSettings.initial().useGradientBackground, isFalse);
    expect(AppSettings.fromJson({}).useGradientBackground, isFalse);
    for (final palette in TravelGradientPalette.values) {
      final restored = AppSettings.fromJson({
        'travelGradientPalette': palette.code,
      });
      expect(restored.useGradientBackground, isTrue);
      expect(restored.travelGradientPalette, palette);
    }
  });

  test('명시적인 단색 선택은 저장된 팔레트가 있어도 재시작 후 유지된다', () {
    for (final enabled in [true, false]) {
      final settings = AppSettings.initial().copyWith(
        useGradientBackground: enabled,
        travelGradientPalette: TravelGradientPalette.forest,
      );
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.useGradientBackground, enabled);
      expect(restored.travelGradientPalette, TravelGradientPalette.forest);
    }
  });

  group('AppSettings travel gradient palette', () {
    test('older saved data uses the breeze palette', () {
      final settings = AppSettings.fromJson(const <String, dynamic>{});

      expect(settings.travelGradientPalette, TravelGradientPalette.breeze);
    });

    test('selected palette survives a JSON round trip', () {
      final original = AppSettings.initial().copyWith(
        travelGradientPalette: TravelGradientPalette.sunset,
      );

      final restored = AppSettings.fromJson(original.toJson());

      expect(restored.travelGradientPalette, TravelGradientPalette.sunset);
    });

    test('unknown palette codes safely use the default', () {
      final settings = AppSettings.fromJson(const <String, dynamic>{
        'travelGradientPalette': 'unknown',
      });

      expect(settings.travelGradientPalette, TravelGradientPalette.breeze);
    });
  });
}
