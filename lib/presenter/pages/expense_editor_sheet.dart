import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';

/// 소비 기록 입력/수정 시트를 표시하고 저장한다.
Future<void> showExpenseEditorSheet({
  required BuildContext context,
  required WidgetRef ref,
  ExpenseEntry? entry,
  DateTime? initialDate,
}) async {
  final ledger = ref.read(ledgerProvider).asData?.value;
  final strings = ref.read(localizedStringsProvider);
  if (ledger == null) {
    return;
  }

  final categoryTags = ledger.tagsByType(MetadataTagType.category);
  final subcategoryTags = ledger.tagsByType(MetadataTagType.subcategory);
  final paymentTags = ledger.tagsByType(MetadataTagType.paymentMethod);
  if (categoryTags.isEmpty || subcategoryTags.isEmpty || paymentTags.isEmpty) {
    return;
  }

  final selectedInitialDate = entry?.spentAt ?? initialDate ?? DateTime.now();
  final descriptionController = TextEditingController(
    text: entry?.description ?? '',
  );
  final amountController = TextEditingController(
    text: entry?.amount.toString() ?? '',
  );
  final noteController = TextEditingController(text: entry?.note ?? '');
  final dateController = TextEditingController(
    text: ExpenseEntry.normalizeDate(
      selectedInitialDate,
    ).toString().substring(0, 16),
  );

  String categoryCode = entry?.categoryCode ?? categoryTags.first.code;
  String subcategoryCode = entry?.subcategoryCode ?? subcategoryTags.first.code;
  String paymentCode = entry?.paymentMethodCode ?? paymentTags.first.code;
  DateTime selectedDate = selectedInitialDate;
  bool isSaving = false;

  try {
    final savedEntry = await showModalBottomSheet<ExpenseEntry>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'DateTime',
                        ),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate == null) {
                            return;
                          }

                          setState(() {
                            selectedDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              selectedDate.hour,
                              selectedDate.minute,
                            );
                            dateController.text = ExpenseEntry.normalizeDate(
                              selectedDate,
                            ).toString().substring(0, 16);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: categoryCode,
                        decoration: InputDecoration(
                          labelText: strings['categoryLabel'],
                        ),
                        items: categoryTags.map((MetadataTag tag) {
                          return DropdownMenuItem<String>(
                            value: tag.code,
                            child: Text('${tag.code} · ${tag.label}'),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            categoryCode = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: subcategoryCode,
                        decoration: InputDecoration(
                          labelText: strings['subcategoryLabel'],
                        ),
                        items: subcategoryTags.map((MetadataTag tag) {
                          return DropdownMenuItem<String>(
                            value: tag.code,
                            child: Text('${tag.code} · ${tag.label}'),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            subcategoryCode = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: paymentCode,
                        decoration: InputDecoration(
                          labelText: strings['paymentMethodLabel'],
                        ),
                        items: paymentTags.map((MetadataTag tag) {
                          return DropdownMenuItem<String>(
                            value: tag.code,
                            child: Text('${tag.code} · ${tag.label}'),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            paymentCode = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: strings['descriptionLabel'],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: strings['amountLabel'],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: strings['noteLabel'],
                        ),
                      ),
                      const SizedBox(height: 16),
                      BootstrapActionButton(
                        label: strings['save'] ?? '저장',
                        icon: Icons.save_outlined,
                        onPressed: () async {
                          if (isSaving) {
                            return;
                          }

                          setState(() {
                            isSaving = true;
                          });

                          final amount =
                              int.tryParse(amountController.text.trim()) ?? 0;
                          final next = ExpenseEntry.create(
                            id: entry?.id,
                            spentAt: selectedDate,
                            categoryCode: categoryCode,
                            subcategoryCode: subcategoryCode,
                            paymentMethodCode: paymentCode,
                            description: descriptionController.text,
                            amount: amount,
                            note: noteController.text,
                          );
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop(next);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (savedEntry != null) {
      if (entry == null) {
        await ref.read(ledgerProvider.notifier).addExpense(savedEntry);
      } else {
        await ref.read(ledgerProvider.notifier).updateExpense(savedEntry);
      }
      ref.invalidate(monthlyExpensesProvider);
      ref.invalidate(rangeExpensesProvider);
    }
  } finally {
    descriptionController.dispose();
    amountController.dispose();
    noteController.dispose();
    dateController.dispose();
  }
}
