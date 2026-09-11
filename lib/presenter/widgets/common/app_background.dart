import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:household_ledger/presenter/extensions/travel_gradient_palette_extension.dart';
import 'package:household_ledger/provider/app_background_provider.dart';

/// Displays the selected app background independently of travel mode.
///
/// The animation is isolated behind [child], so route contents are not rebuilt
/// on every frame. It also follows the platform's reduced-motion preference.
class AppBackground extends ConsumerWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = ref.watch(appBackgroundProvider);

    return _AnimatedAppBackground(
      useGradient: background.useGradient,
      palette: background.palette,
      child: child,
    );
  }
}

class _AnimatedAppBackground extends StatefulWidget {
  const _AnimatedAppBackground({
    required this.useGradient,
    required this.palette,
    required this.child,
  });

  final bool useGradient;
  final TravelGradientPalette palette;
  final Widget child;

  @override
  State<_AnimatedAppBackground> createState() => _AnimatedAppBackgroundState();
}

class _AnimatedAppBackgroundState extends State<_AnimatedAppBackground>
    with SingleTickerProviderStateMixin {
  static const Duration _cycleDuration = Duration(seconds: 12);

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
  void didUpdateWidget(covariant _AnimatedAppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useGradient != widget.useGradient) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.useGradient && !_reduceMotion) {
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
          const ColoredBox(
            key: ValueKey<String>('default-app-background'),
            color: Color(0xFFF4F7FB),
          ),
          if (widget.useGradient)
            IgnorePointer(
              child: RepaintBoundary(
                child: Opacity(
                  key: const ValueKey<String>('app-gradient'),
                  opacity: 1,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) {
                      final phase = Curves.easeInOut.transform(
                        _controller.value,
                      );
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
