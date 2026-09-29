import 'package:flutter/material.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/extensions/metadata_tag_icon_extension.dart';

/// Single-tap classification choices shared by the expense editor's fields.
class ExpenseTagSelector extends StatelessWidget {
  const ExpenseTagSelector({
    required this.label,
    required this.tags,
    required this.selectedCode,
    required this.onSelected,
    super.key,
  });

  final String label;
  final List<MetadataTag> tags;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tag in tags)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('${tag.type.name}-${tag.code}'),
                    label: Text(tag.label),
                    avatar: tag.type == MetadataTagType.category
                        ? Icon(tag.iconData, size: 18)
                        : null,
                    selected: selectedCode == tag.code,
                    onSelected: (_) => onSelected(tag.code),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
