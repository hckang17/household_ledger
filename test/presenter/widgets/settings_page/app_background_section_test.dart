import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:household_ledger/presenter/widgets/settings_page/app_background_section.dart';

void main() {
  testWidgets('palette preview cards report the selected palette', (
    WidgetTester tester,
  ) async {
    TravelGradientPalette? changedPalette;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppBackgroundSection(
              strings: const <String, String>{
                'travelGradientSettingsTitle': 'Travel background',
                'travelGradientSettingsDescription': 'Choose a palette',
                'travelGradientBreeze': 'Breeze',
                'travelGradientOcean': 'Ocean',
                'travelGradientSunset': 'Sunset',
                'travelGradientForest': 'Forest',
                'appBackgroundSolid': 'Solid',
              },
              selectedPalette: TravelGradientPalette.breeze,
              onChanged: (TravelGradientPalette? palette) {
                changedPalette = palette;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Travel background'), findsOneWidget);
    expect(find.text('Breeze'), findsOneWidget);
    expect(find.text('Ocean'), findsOneWidget);
    expect(find.text('Sunset'), findsOneWidget);
    expect(find.text('Forest'), findsOneWidget);

    await tester.tap(find.text('Sunset'));
    await tester.pump();

    expect(changedPalette, TravelGradientPalette.sunset);
    await tester.tap(find.text('Solid'));
    await tester.pump();
    expect(changedPalette, isNull);
  });
}
