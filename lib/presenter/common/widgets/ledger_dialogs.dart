import 'package:flutter/material.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_dialog.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';

/// 공통 확인(주로 삭제 등) 다이얼로그를 표시한다.
Future<bool> showLedgerConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return BootstrapDialog(
        title: title,
        icon: Icons.warning_amber_rounded,
        content: Text(
          message,
          style: Theme.of(dialogContext).textTheme.bodyMedium,
        ),

        actions: <Widget>[
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),

          const SizedBox(width: 8),

          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC3545),
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

// Future<bool> showLedgerConfirmDialog({
//   required BuildContext context,
//   required String title,
//   required String message,
//   required String confirmLabel,
//   required String cancelLabel,
// }) async {
//   final result = await showDialog<bool>(
//     context: context,
//     builder: (BuildContext dialogContext) {
//       return AlertDialog(
//         title: Text(title),
//         content: Text(message),
//         actions: <Widget>[
//           TextButton(
//             onPressed: () => Navigator.of(dialogContext).pop(false),
//             child: Text(cancelLabel),
//           ),
//           FilledButton(
//             onPressed: () => Navigator.of(dialogContext).pop(true),
//             child: Text(confirmLabel),
//           ),
//         ],
//       );
//     },
//   );

//   return result ?? false;
// }

/// 새 태그 입력 다이얼로그를 표시한다.
Future<MetadataTag?> showTagEditorDialog({
  required BuildContext context,
  required MetadataTagType type,
  required String title,
  required String saveLabel,
  required String cancelLabel,
  String initialCode = '',
  String initialLabel = '',
}) async {
  String code = initialCode;
  String label = initialLabel;

  final result = await showDialog<MetadataTag>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              initialValue: initialCode,
              decoration: const InputDecoration(labelText: 'Code'),
              onChanged: (String value) {
                code = value;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: initialLabel,
              decoration: const InputDecoration(labelText: 'Label'),
              onChanged: (String value) {
                label = value;
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () {
              final trimmedCode = code.trim();
              final trimmedLabel = label.trim();
              if (trimmedCode.isEmpty || trimmedLabel.isEmpty) {
                return;
              }

              Navigator.of(dialogContext).pop(
                MetadataTag(type: type, code: trimmedCode, label: trimmedLabel),
              );
            },
            child: Text(saveLabel),
          ),
        ],
      );
    },
  );

  return result;
}

/// 태그 삭제 시 대체 태그를 선택하는 다이얼로그를 표시한다.
Future<String?> showReplacementTagDialog({
  required BuildContext context,
  required String title,
  required String saveLabel,
  required String cancelLabel,
  required List<MetadataTag> candidates,
}) async {
  if (candidates.isEmpty) {
    return null;
  }

  String selectedCode = candidates.first.code;
  final result = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DropdownButtonFormField<String>(
              initialValue: selectedCode,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: candidates
                  .map(
                    (MetadataTag tag) => DropdownMenuItem<String>(
                      value: tag.code,
                      child: Text('${tag.code} · ${tag.label}'),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  selectedCode = value;
                });
              },
            );
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(selectedCode),
            child: Text(saveLabel),
          ),
        ],
      );
    },
  );

  return result;
}

Future<void> showExpenseDetailDialog({
  required BuildContext context,
  required ExpenseEntry entry,
  required List<MetadataTag> categoryTags,
  required List<MetadataTag> subcategoryTags,
  required List<MetadataTag> paymentTags,
  required Map<String, String> strings,
  required String currency,
}) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return BootstrapDialog(
        title: strings['expenseRecordTitle'] ?? '',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DetailRow(
              label: strings['descriptionLabel'] ?? '',
              value: entry.description,
            ),

            DetailRow(
              label: strings['dateLabel'] ?? '',
              value: entry.formattedDate,
            ),

            DetailRow(
              label: strings['categoryLabel'] ?? '',
              value: _resolveTagLabel(categoryTags, entry.categoryCode),
            ),

            DetailRow(
              label: strings['subcategoryLabel'] ?? '',
              value: _resolveTagLabel(subcategoryTags, entry.subcategoryCode),
            ),

            DetailRow(
              label: strings['paymentMethodLabel'] ?? '',
              value: _resolveTagLabel(paymentTags, entry.paymentMethodCode),
            ),

            if (entry.note.isNotEmpty)
              DetailRow(label: strings['noteLabel'] ?? '', value: entry.note),

            const SizedBox(height: 20),

            const Divider(),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                strings['amountLabel'] ?? '',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${entry.amount.toCurrency()}$currency',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: entry.amount < 0
                      ? const Color(0xFF0D6EFD)
                      : const Color(0xFFDC3545),
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings['cancel'] ?? 'Close'),
          ),
        ],
      );
    },
  );
}

String _resolveTagLabel(List<MetadataTag> tags, String code) {
  try {
    return tags.firstWhere((tag) => tag.code == code).label;
  } catch (e) {
    return '';
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
