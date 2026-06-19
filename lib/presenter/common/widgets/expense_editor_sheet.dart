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
  final savedEntry = await showModalBottomSheet<ExpenseEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return _ExpenseEditorSheetBody(
        entry: entry,
        selectedInitialDate: selectedInitialDate,
        categoryTags: categoryTags,
        subcategoryTags: subcategoryTags,
        paymentTags: paymentTags,
        strings: strings,
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
}

class _ExpenseEditorSheetBody extends StatefulWidget {
  const _ExpenseEditorSheetBody({
    required this.entry,
    required this.selectedInitialDate,
    required this.categoryTags,
    required this.subcategoryTags,
    required this.paymentTags,
    required this.strings,
  });

  final ExpenseEntry? entry;
  final DateTime selectedInitialDate;
  final List<MetadataTag> categoryTags;
  final List<MetadataTag> subcategoryTags;
  final List<MetadataTag> paymentTags;
  final Map<String, String> strings;

  @override
  State<_ExpenseEditorSheetBody> createState() =>
      _ExpenseEditorSheetBodyState();
}

class _ExpenseEditorSheetBodyState extends State<_ExpenseEditorSheetBody> {
  late final TextEditingController descriptionController;
  late final TextEditingController amountController;
  late final TextEditingController noteController;
  late final TextEditingController dateController;

  late String categoryCode;
  late String subcategoryCode;
  late String paymentCode;
  late DateTime selectedDate;
  bool isSaving = false;

  /// 내용 필드 에러 메시지. null이면 에러 없음.
  String? descriptionError;

  /// 금액 필드 에러 메시지. null이면 에러 없음.
  String? amountError;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.selectedInitialDate;
    categoryCode = widget.entry?.categoryCode ?? widget.categoryTags.first.code;
    subcategoryCode =
        widget.entry?.subcategoryCode ?? widget.subcategoryTags.first.code;
    paymentCode =
        widget.entry?.paymentMethodCode ?? widget.paymentTags.first.code;

    descriptionController = TextEditingController(
      text: widget.entry?.description ?? '',
    );
    amountController = TextEditingController(
      text: widget.entry?.amount.toString() ?? '',
    );
    noteController = TextEditingController(text: widget.entry?.note ?? '');
    dateController = TextEditingController(
      text: ExpenseEntry.normalizeDate(
        selectedDate,
      ).toString().substring(0, 16),
    );
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    descriptionController.dispose();
    amountController.dispose();
    noteController.dispose();
    dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: dateController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'DateTime'),
                onTap: () async {
                  FocusScope.of(context).unfocus();
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (!mounted || pickedDate == null) {
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
                  labelText: widget.strings['categoryLabel'],
                ),
                items: widget.categoryTags.map((MetadataTag tag) {
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
                  labelText: widget.strings['subcategoryLabel'],
                ),
                items: widget.subcategoryTags.map((MetadataTag tag) {
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
                  labelText: widget.strings['paymentMethodLabel'],
                ),
                items: widget.paymentTags.map((MetadataTag tag) {
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
                  labelText: widget.strings['descriptionLabel'],
                  hintText: widget.strings['descriptionHint'],
                  errorText: descriptionError,
                ),
                onChanged: (_) {
                  if (descriptionError != null) {
                    setState(() => descriptionError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.strings['amountLabel'],
                  hintText: widget.strings['amountHint'],
                  errorText: amountError,
                ),
                onChanged: (_) {
                  if (amountError != null) {
                    setState(() => amountError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: widget.strings['noteLabel'],
                  hintText: widget.strings['noteHint'],
                ),
              ),
              const SizedBox(height: 16),
              BootstrapActionButton(
                label: widget.strings['save'] ?? '저장',
                icon: Icons.save_outlined,
                onPressed: () async {
                  if (isSaving) {
                    return;
                  }

                  // ── 유효성 검사 ──────────────────────────────
                  final String rawDesc = descriptionController.text.trim();
                  final String rawAmount = amountController.text.trim();
                  final int? parsedAmount = int.tryParse(rawAmount);

                  String? newDescError;
                  String? newAmountError;

                  if (rawDesc.isEmpty) {
                    newDescError = widget.strings['descriptionRequired'] ??
                        '내용을 입력해주세요.';
                  }
                  if (rawAmount.isEmpty) {
                    newAmountError = widget.strings['amountRequired'] ??
                        '금액을 입력해주세요.';
                  } else if (parsedAmount == null) {
                    newAmountError = widget.strings['amountInvalid'] ??
                        '올바른 숫자를 입력해주세요.';
                  }

                  if (newDescError != null || newAmountError != null) {
                    setState(() {
                      descriptionError = newDescError;
                      amountError = newAmountError;
                    });
                    return;
                  }

                  setState(() {
                    isSaving = true;
                  });

                  final amount = parsedAmount!;
                  final next = ExpenseEntry.create(
                    id: widget.entry?.id,
                    spentAt: selectedDate,
                    categoryCode: categoryCode,
                    subcategoryCode: subcategoryCode,
                    paymentMethodCode: paymentCode,
                    description: descriptionController.text,
                    amount: amount,
                    note: noteController.text,
                  );
                  if (!mounted) {
                    return;
                  }
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).pop(next);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
