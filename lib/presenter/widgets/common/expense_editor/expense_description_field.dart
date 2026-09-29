import 'package:flutter/material.dart';
import 'package:household_ledger/features/expense/calculators/expense_description_suggestions.dart';

/// Inline completions stay inside the sheet's scroll area and above its keyboard
/// inset. Only an explicit selection changes text, including during IME input.
class ExpenseDescriptionField extends StatefulWidget {
  const ExpenseDescriptionField({
    required this.controller,
    required this.suggestions,
    required this.decoration,
    required this.suggestionsLabel,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final InputDecoration decoration;
  final String suggestionsLabel;
  final ValueChanged<String> onChanged;

  @override
  State<ExpenseDescriptionField> createState() =>
      _ExpenseDescriptionFieldState();
}

class _ExpenseDescriptionFieldState extends State<ExpenseDescriptionField> {
  final _focusNode = FocusNode();
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusChanged);
  }

  void _focusChanged() {
    setState(() => _completed = false);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_focusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      skipTraversal: true,
      child: TextFieldTapRegion(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: widget.controller,
              decoration: widget.decoration,
              onChanged: (value) {
                setState(() => _completed = false);
                widget.onChanged(value);
              },
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, child) {
                final matches = _focusNode.hasFocus && !_completed
                    ? matchExpenseDescriptions(widget.suggestions, value.text)
                    : const <String>[];
                if (matches.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      widget.suggestionsLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final suggestion in matches)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(suggestion),
                                onPressed: () {
                                  setState(() => _completed = true);
                                  widget.controller.value = TextEditingValue(
                                    text: suggestion,
                                    selection: TextSelection.collapsed(
                                      offset: suggestion.length,
                                    ),
                                  );
                                  widget.onChanged(suggestion);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
