import 'package:flutter/material.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';

/// Presentation values for each persisted travel gradient palette.
extension TravelGradientPalettePresentation on TravelGradientPalette {
  String get labelKey => switch (this) {
    TravelGradientPalette.breeze => 'travelGradientBreeze',
    TravelGradientPalette.ocean => 'travelGradientOcean',
    TravelGradientPalette.sunset => 'travelGradientSunset',
    TravelGradientPalette.forest => 'travelGradientForest',
  };

  List<Color> get colors => switch (this) {
    TravelGradientPalette.breeze => const <Color>[
      Color(0xFFEAF8F4),
      Color(0xFFE7F1FF),
      Color(0xFFF2EDFF),
      Color(0xFFFFF4E8),
    ],
    TravelGradientPalette.ocean => const <Color>[
      Color(0xFFE7F8F7),
      Color(0xFFDDEFFF),
      Color(0xFFE8EBFF),
      Color(0xFFF3F8FF),
    ],
    TravelGradientPalette.sunset => const <Color>[
      Color(0xFFFFF3E5),
      Color(0xFFFFE8EC),
      Color(0xFFF4E9FF),
      Color(0xFFEAF3FF),
    ],
    TravelGradientPalette.forest => const <Color>[
      Color(0xFFE9F8EE),
      Color(0xFFE0F3EC),
      Color(0xFFE7F1F4),
      Color(0xFFF7F3E6),
    ],
  };
}
