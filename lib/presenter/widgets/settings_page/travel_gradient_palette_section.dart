import 'package:flutter/material.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:household_ledger/presenter/extensions/travel_gradient_palette_extension.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';

class TravelGradientPaletteSection extends StatelessWidget {
  const TravelGradientPaletteSection({
    required this.strings,
    required this.selectedPalette,
    required this.onChanged,
    super.key,
  });

  final Map<String, String> strings;
  final TravelGradientPalette selectedPalette;
  final ValueChanged<TravelGradientPalette> onChanged;

  String _text(String key, String fallback) => strings[key] ?? fallback;

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _text('travelGradientSettingsTitle', '여행 모드 배경'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _text(
              'travelGradientSettingsDescription',
              '여행 모드에서 사용할 은은한 색상을 선택하세요.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF627D98)),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: TravelGradientPalette.values.map((palette) {
                  return SizedBox(
                    width: itemWidth,
                    child: _PaletteChoice(
                      palette: palette,
                      label: _text(palette.labelKey, palette.code),
                      selected: selectedPalette == palette,
                      onTap: () => onChanged(palette),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final TravelGradientPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0D6EFD)
                    : const Color(0xFFD9E2EC),
                width: selected ? 2.5 : 1,
              ),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (selected) ...<Widget>[
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF0D6EFD),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
