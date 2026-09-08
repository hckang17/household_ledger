import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:household_ledger/presenter/extensions/travel_gradient_palette_extension.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';

/// Displays the app background and softly animates it while travel mode is on.
///
/// The animation is isolated behind [child], so route contents are not rebuilt
/// on every frame. It also follows the platform's reduced-motion preference.
class TravelModeBackground extends ConsumerWidget {
  const TravelModeBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTravelModeOn = ref.watch(
      travelProvider.select(
        (AsyncValue<TravelState> value) =>
            value.asData?.value.activeTrip != null,
      ),
    );
    final palette = ref.watch(
      ledgerProvider.select(
        (value) =>
            value.asData?.value.settings.travelGradientPalette ??
            TravelGradientPalette.breeze,
      ),
    );

    return _AnimatedTravelBackground(
      isTravelModeOn: isTravelModeOn,
      palette: palette,
      child: child,
    );
  }
}

class _AnimatedTravelBackground extends StatefulWidget {
  const _AnimatedTravelBackground({
    required this.isTravelModeOn,
    required this.palette,
    required this.child,
  });

  final bool isTravelModeOn;
  final TravelGradientPalette palette;
  final Widget child;

  @override
  State<_AnimatedTravelBackground> createState() =>
      _AnimatedTravelBackgroundState();
}

class _AnimatedTravelBackgroundState extends State<_AnimatedTravelBackground>
    with SingleTickerProviderStateMixin {
  static const Duration _cycleDuration = Duration(seconds: 12);
  static const Duration _fadeDuration = Duration(milliseconds: 650);

  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _cycleDuration,
      value: 0.5,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedTravelBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTravelModeOn != widget.isTravelModeOn) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isTravelModeOn && !_reduceMotion) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
      return;
    }
    _controller.stop();
    if (_reduceMotion) {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F7FB),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            key: ValueKey<String>('default-app-background'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFFF4F7FB), Color(0xFFE8EEF8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedOpacity(
                key: const ValueKey<String>('travel-mode-gradient'),
                opacity: widget.isTravelModeOn ? 1 : 0,
                duration: _reduceMotion ? Duration.zero : _fadeDuration,
                curve: Curves.easeInOut,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    final phase = Curves.easeInOut.transform(_controller.value);
                    final wave = math.sin(phase * math.pi);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.palette.colors,
                          stops: <double>[
                            0,
                            0.28 + (wave * 0.08),
                            0.68 + (phase * 0.06),
                            1,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          transform: GradientRotation(math.pi * phase),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
