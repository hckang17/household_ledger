import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:intl/intl.dart';

/// 수입 항목을 추가하거나 수정하는 바텀 시트를 표시한 뒤 결과를 저장한다.
Future<void> showIncomeEditorSheet({
  required BuildContext context,
  required WidgetRef ref,
  required DateTime focusedMonth,
  required Map<String, String> strings,
  IncomeEntry? item,
}) async {
  String t(String key, String fallback) => strings[key] ?? fallback;

  final dateController = TextEditingController(
    text: DateFormat('yyyy-MM-dd HH:mm').format(item?.earnedAt ?? focusedMonth),
  );
  final amountController = TextEditingController(
    text: item?.amount.toString() ?? '',
  );
  final descriptionController = TextEditingController(
    text: item?.description ?? '',
  );
  var selectedDate = item?.earnedAt ?? focusedMonth;
  var isSaving = false;

  final saved = await showModalBottomSheet<IncomeEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
            builder: (BuildContext ctx, StateSetter setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: t('dateLabel', '날짜'),
                      ),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate == null) return;
                        setModalState(() {
                          selectedDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            selectedDate.hour,
                            selectedDate.minute,
                          );
                          dateController.text =
                              DateFormat('yyyy-MM-dd HH:mm').format(selectedDate);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t('amountLabel', '금액'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: t('descriptionLabel', '내용'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    BootstrapActionButton(
                      label: t('save', '저장'),
                      icon: Icons.save_outlined,
                      onPressed: () async {
                        if (isSaving) return;
                        setModalState(() => isSaving = true);
                        final amount =
                            int.tryParse(amountController.text.trim()) ?? 0;
                        final next = IncomeEntry.create(
                          id: item?.id,
                          earnedAt: selectedDate,
                          amount: amount,
                          description: descriptionController.text,
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

  if (saved == null) return;
  if (!context.mounted) return;
  if (saved.id == null) {
    await ref.read(ledgerProvider.notifier).addIncome(saved);
  } else {
    await ref.read(ledgerProvider.notifier).updateIncome(saved);
  }
  if (!context.mounted) return;
  ref.invalidate(monthlyIncomesProvider(focusedMonth));
}
