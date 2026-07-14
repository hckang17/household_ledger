// """ MVVM 계층: View / fixed_expense_page """
// """ 역할: 고정지출 등록과 수정을 위한 BottomSheet 제공 """

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';

/// 고정지출 항목을 추가하거나 수정하는 바텀 시트를 표시한 뒤 결과를 저장한다.
Future<void> showFixedExpenseEditorSheet({
  required BuildContext context,
  required WidgetRef ref,
  required DateTime focusedMonth,
  FixedExpense? item,
}) async {
  final ledger = ref.read(ledgerProvider).asData?.value;
  final strings = ref.read(localizedStringsProvider);
  if (ledger == null) return;

  final descriptionController = TextEditingController(
    text: item?.description ?? '',
  );
  final amountController = TextEditingController(
    text: item?.amount.toString() ?? '',
  );
  final noteController = TextEditingController(text: item?.note ?? '');
  String categoryCode =
      item?.categoryCode ??
      ledger.tagsByType(MetadataTagType.category).first.code;
  String paymentCode =
      item?.paymentMethodCode ??
      ledger.tagsByType(MetadataTagType.paymentMethod).first.code;
  DateTime appliedAt = item?.appliedAt ?? focusedMonth;
  bool isSaving = false;
  String? descriptionError;
  String? amountError;

  final savedItem = await showModalBottomSheet<FixedExpense>(
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
                    DropdownButtonFormField<String>(
                      initialValue: categoryCode,
                      decoration: InputDecoration(
                        labelText: strings['categoryLabel'],
                      ),
                      items: ledger
                          .tagsByType(MetadataTagType.category)
                          .map(
                            (MetadataTag tag) => DropdownMenuItem<String>(
                              value: tag.code,
                              child: Text('${tag.code} · ${tag.label}'),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value == null) return;
                        setModalState(() => categoryCode = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: paymentCode,
                      decoration: InputDecoration(
                        labelText: strings['paymentMethodLabel'],
                      ),
                      items: ledger
                          .tagsByType(MetadataTagType.paymentMethod)
                          .map(
                            (MetadataTag tag) => DropdownMenuItem<String>(
                              value: tag.code,
                              child: Text('${tag.code} · ${tag.label}'),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value == null) return;
                        setModalState(() => paymentCode = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: strings['descriptionLabel'],
                        hintText: strings['descriptionHint'],
                        errorText: descriptionError,
                      ),
                      onChanged: (_) {
                        if (descriptionError != null) {
                          setModalState(() => descriptionError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: strings['amountLabel'],
                        hintText: strings['amountHint'],
                        errorText: amountError,
                      ),
                      onChanged: (_) {
                        if (amountError != null) {
                          setModalState(() => amountError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: strings['noteLabel'],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${strings['yearLabel'] ?? '연도'}-${strings['monthLabel'] ?? '월'}: '
                            '${appliedAt.year}-${appliedAt.month.toString().padLeft(2, '0')}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: appliedAt,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked == null) return;
                            setModalState(() {
                              appliedAt = DateTime(
                                picked.year,
                                picked.month,
                                1,
                              );
                            });
                          },
                          child: Text(strings['selectMonth'] ?? '달 선택'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    BootstrapActionButton(
                      label: strings['save'] ?? '',
                      icon: Icons.save_outlined,
                      onPressed: () async {
                        if (isSaving) return;

                        final String rawDesc = descriptionController.text
                            .trim();
                        final String rawAmount = amountController.text.trim();
                        final int? parsedAmount = int.tryParse(rawAmount);

                        String? newDescError;
                        String? newAmountError;

                        if (rawDesc.isEmpty) {
                          newDescError =
                              strings['descriptionRequired'] ?? '내용을 입력해주세요.';
                        }
                        if (rawAmount.isEmpty) {
                          newAmountError =
                              strings['amountRequired'] ?? '금액을 입력해주세요.';
                        } else if (parsedAmount == null) {
                          newAmountError =
                              strings['amountInvalid'] ?? '올바른 숫자를 입력해주세요.';
                        }

                        if (newDescError != null || newAmountError != null) {
                          setModalState(() {
                            descriptionError = newDescError;
                            amountError = newAmountError;
                          });
                          return;
                        }

                        setModalState(() => isSaving = true);
                        final next = FixedExpense.create(
                          id: item?.id,
                          appliedAt: appliedAt,
                          categoryCode: categoryCode,
                          paymentMethodCode: paymentCode,
                          description: descriptionController.text,
                          amount: parsedAmount!,
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

  if (savedItem != null && context.mounted) {
    if (item == null) {
      await ref.read(ledgerProvider.notifier).addFixedExpense(savedItem);
    } else {
      await ref.read(ledgerProvider.notifier).updateFixedExpense(savedItem);
    }
    ref.invalidate(ledgerProvider);
    ref.invalidate(monthlyFixedExpensesProvider);
  }
}
