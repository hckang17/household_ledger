import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/widgets/common/typewriter_text.dart';

/// The welcome heading shares its reveal behavior with report introductions.
class OnboardingTitle extends StatelessWidget {
  const OnboardingTitle({
    required this.text,
    required this.animate,
    this.style,
    super.key,
  });
  final String text;
  final bool animate;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) =>
      TypewriterText(text: text, animate: animate, style: style, header: true);
}
