import 'package:flutter/material.dart';

/// Reveals the text once while retaining its complete text layout.
/// Screen readers receive the full heading from the first frame.
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    required this.text,
    required this.animate,
    this.style,
    this.header = false,
    this.slowEnding = false,
    super.key,
  });

  final String text;
  final bool animate;
  final TextStyle? style;
  final bool header;

  /// Keeps the opening brisk and slows the last six graphemes down.
  final bool slowEnding;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<String> _characters;
  int _visible = 0;
  bool _started = false;
  List<int> _revealTimes = const [];

  @override
  void initState() {
    super.initState();
    _characters = widget.text.characters.toList();
    _controller = AnimationController(vsync: this)..addListener(_reveal);
  }

  void _reveal() {
    final elapsed =
        _controller.value * (_controller.duration?.inMilliseconds ?? 0);
    final count = widget.slowEnding
        ? _revealTimes.where((time) => time <= elapsed).length
        : (_controller.value * _characters.length).floor();
    if (count != _visible) setState(() => _visible = count);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // A language change should immediately show the new heading.
      _characters = widget.text.characters.toList();
      _controller.stop();
      _visible = _characters.length;
      _started = true;
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    if (!widget.animate ||
        MediaQuery.disableAnimationsOf(context) ||
        _characters.isEmpty) {
      _controller.stop();
      _visible = _characters.length;
      _started = true;
    } else if (!_started) {
      _started = true;
      var elapsed = 0;
      _revealTimes = List.generate(_characters.length, (index) {
        final remaining = _characters.length - index;
        elapsed += remaining > 6 ? 30 : 80 + (6 - remaining) * 10;
        return elapsed;
      });
      _controller.duration = Duration(
        milliseconds: widget.slowEnding
            ? elapsed
            : (_characters.length * 35).clamp(35, 1000),
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.text,
      header: widget.header,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: _characters.take(_visible).join()),
              TextSpan(
                text: _characters.skip(_visible).join(),
                style: const TextStyle(color: Colors.transparent),
              ),
            ],
          ),
          style: widget.style,
        ),
      ),
    );
  }
}
