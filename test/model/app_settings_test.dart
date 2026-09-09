import 'package:household_ledger/model/app_settings.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:test/test.dart';

void main() {
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
