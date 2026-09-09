/// Palettes available for the animated travel-mode background.
enum TravelGradientPalette {
  breeze('breeze'),
  ocean('ocean'),
  sunset('sunset'),
  forest('forest');

  const TravelGradientPalette(this.code);

  final String code;

  /// Restores a palette while safely falling back for older or invalid data.
  static TravelGradientPalette fromCode(String? code) {
    for (final palette in values) {
      if (palette.code == code) return palette;
    }
    return TravelGradientPalette.breeze;
  }
}
