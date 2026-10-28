import 'dart:math';

import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/widgets/common/typewriter_text.dart';

/// Holds one greeting for the lifetime of the home tab, including data refreshes.
class HomeGreeting extends StatefulWidget {
  const HomeGreeting({required this.name, required this.strings, super.key});

  final String? name;
  final Map<String, String> strings;

  @override
  State<HomeGreeting> createState() => _HomeGreetingState();
}

class _HomeGreetingState extends State<HomeGreeting> {
  final int _index = Random().nextInt(10) + 1;
  String? _text;

  @override
  Widget build(BuildContext context) {
    // Do not consume the one-shot animation before profile and locale load.
    final template = widget.strings['homeGreeting$_index'];
    if (widget.name != null && template != null) {
      final name = widget.name!.trim();
      _text = name.isEmpty
          ? widget.strings['homeGreeting7']
          : template.replaceAll('{name}', name);
    }
    if (_text == null) return const SizedBox(height: 32);
    return TypewriterText(
      text: _text!,
      animate: true,
      slowEnding: true,
      header: true,
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}
