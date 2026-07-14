// """ MVVM 계층: Shared View """
// """ 공통 근거: 홈, 분석, 소비 기록, 데이터 관리에서 소비 입력에 사용 """

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';

/// 튜토리얼 모드에서 사용할 초기값 프리셋.
class TutorialExpensePreset {
  const TutorialExpensePreset({
    required this.categoryCode,
    required this.subcategoryCode,
    required this.paymentMethodCode,
    required this.description,
    required this.amount,
    required this.note,
  });

  final String categoryCode;
  final String subcategoryCode;
  final String paymentMethodCode;
  final String description;
  final String amount;
  final String note;
}

/// 소비 기록 입력/수정 시트를 표시하고 저장한다.
Future<void> showExpenseEditorSheet({
  required BuildContext context,
  required WidgetRef ref,
  ExpenseEntry? entry,
  DateTime? initialDate,
  TutorialExpensePreset? tutorialPreset,
}) async {
  final ledger = ref.read(ledgerProvider).asData?.value;
  final strings = ref.read(localizedStringsProvider);
  if (ledger == null) {
    return;
  }

  final categoryTags = ledger.tagsByType(MetadataTagType.category);
  final subcategoryTags = ledger.tagsByType(MetadataTagType.subcategory);
  final diningOccasionTags = ledger.tagsByType(MetadataTagType.diningOccasion);
  final paymentTags = ledger.tagsByType(MetadataTagType.paymentMethod);
  if (categoryTags.isEmpty || subcategoryTags.isEmpty || paymentTags.isEmpty) {
    return;
  }

  final now = DateTime.now();
  final selectedInitialDate =
      entry?.spentAt ??
      (initialDate == null
          ? now
          : DateTime(
              initialDate.year,
              initialDate.month,
              initialDate.day,
              now.hour,
              now.minute,
            ));
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
        diningOccasionTags: diningOccasionTags,
        paymentTags: paymentTags,
        strings: strings,
        tutorialPreset: tutorialPreset,
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
    required this.diningOccasionTags,
    required this.paymentTags,
    required this.strings,
    this.tutorialPreset,
  });

  final ExpenseEntry? entry;
  final DateTime selectedInitialDate;
  final List<MetadataTag> categoryTags;
  final List<MetadataTag> subcategoryTags;
  final List<MetadataTag> diningOccasionTags;
  final List<MetadataTag> paymentTags;
  final Map<String, String> strings;
  final TutorialExpensePreset? tutorialPreset;

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
  String? diningOccasionCode;
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
    final preset = widget.tutorialPreset;
    categoryCode =
        preset?.categoryCode ??
        widget.entry?.categoryCode ??
        widget.categoryTags.first.code;
    subcategoryCode =
        preset?.subcategoryCode ??
        widget.entry?.subcategoryCode ??
        widget.subcategoryTags.first.code;
    diningOccasionCode = widget.entry?.diningOccasionCode;
    if (widget.entry == null && categoryCode == 'F') {
      diningOccasionCode = _recommendedDiningOccasion(selectedDate);
    }
    paymentCode =
        preset?.paymentMethodCode ??
        widget.entry?.paymentMethodCode ??
        widget.paymentTags.first.code;

    descriptionController = TextEditingController(
      text: preset?.description ?? widget.entry?.description ?? '',
    );
    amountController = TextEditingController(
      text: preset?.amount ?? widget.entry?.amount.toString() ?? '',
    );
    noteController = TextEditingController(
      text: preset?.note ?? widget.entry?.note ?? '',
    );
    dateController = TextEditingController(
      text: ExpenseEntry.normalizeDate(
        selectedDate,
      ).toString().substring(0, 16),
    );
  }

  String? _recommendedDiningOccasion(DateTime dateTime) {
    final hour = dateTime.hour;
    final String recommendedCode;
    if (hour >= 6 && hour < 10) {
      recommendedCode = 'breakfast';
    } else if (hour >= 10 && hour < 11) {
      recommendedCode = 'brunch';
    } else if (hour >= 11 && hour < 14) {
      recommendedCode = 'lunch';
    } else if (hour >= 14 && hour < 18) {
      recommendedCode = 'snack';
    } else if (hour >= 18 && hour < 21) {
      recommendedCode = 'dinner';
    } else {
      recommendedCode = 'company';
    }
    return widget.diningOccasionTags.any(
          (MetadataTag tag) => tag.code == recommendedCode,
        )
        ? recommendedCode
        : null;
  }

  List<MetadataTag> _orderedDiningOccasionTags() {
    final tags = <MetadataTag>[...widget.diningOccasionTags];
    final recommendedCode = _recommendedDiningOccasion(selectedDate);
    tags.sort((MetadataTag left, MetadataTag right) {
      if (left.code == recommendedCode) return -1;
      if (right.code == recommendedCode) return 1;
      return left.code.compareTo(right.code);
    });
    return tags;
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
                    if (categoryCode != 'F') {
                      diningOccasionCode = null;
                    } else if (widget.entry == null &&
                        diningOccasionCode == null) {
                      diningOccasionCode = _recommendedDiningOccasion(
                        selectedDate,
                      );
                    }
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
              if (categoryCode == 'F') ...<Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.strings['diningOccasionLabel'] ?? '식사 유형 (선택)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _orderedDiningOccasionTags().map((tag) {
                      final selected = diningOccasionCode == tag.code;
                      return ChoiceChip(
                        label: Text(tag.label),
                        selected: selected,
                        avatar: selected
                            ? const Icon(Icons.check, size: 18)
                            : null,
                        onSelected: (bool value) {
                          setState(() {
                            diningOccasionCode = value ? tag.code : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
                    newDescError =
                        widget.strings['descriptionRequired'] ?? '내용을 입력해주세요.';
                  }
                  if (rawAmount.isEmpty) {
                    newAmountError =
                        widget.strings['amountRequired'] ?? '금액을 입력해주세요.';
                  } else if (parsedAmount == null) {
                    newAmountError =
                        widget.strings['amountInvalid'] ?? '올바른 숫자를 입력해주세요.';
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
                    diningOccasionCode: categoryCode == 'F'
                        ? diningOccasionCode
                        : null,
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
