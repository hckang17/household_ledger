import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/presenter/common/widgets/month_navigator_bar.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';

/// 고정지출 관리 페이지다.
class FixedExpensePage extends ConsumerStatefulWidget {
  /// 고정지출 관리 페이지를 생성한다.
  const FixedExpensePage({super.key});

  @override
  ConsumerState<FixedExpensePage> createState() => _FixedExpensePageState();
}

class _FixedExpensePageState extends ConsumerState<FixedExpensePage> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _focusedMonth = DateTime(picked.year, picked.month, 1);
    });
  }

  String _text(Map<String, String> strings, String tag) {
    return strings[tag] ??
        '${strings['failedReadingData'] ?? 'ErrorCode: 4401'}+$tag';
  }

  String _monthNavLabel(Map<String, String> strings) {
    final template = strings['monthYearLabel'] ?? '{year}년 {month}월';
    return template
        .replaceAll('{year}', _focusedMonth.year.toString())
        .replaceAll(
          '{month}',
          _focusedMonth.month.toString().padLeft(2, '0'),
        );
  }

  String _totalLabel(Map<String, String> strings) {
    final template =
        strings['fixedExpenseMonthlyTotalLabel'] ?? '{year}년 {month}월 고정지출 합계';
    return template
        .replaceAll('{year}', _focusedMonth.year.toString())
        .replaceAll(
          '{month}',
          _focusedMonth.month.toString().padLeft(2, '0'),
        );
  }

  String _resolveTagLabel(List<MetadataTag> tags, String code) {
    try {
      return tags.firstWhere((MetadataTag tag) => tag.code == code).label;
    } catch (_) {
      return code;
    }
  }

  Future<void> _showDetail({
    required FixedExpense item,
    required List<MetadataTag> categoryTags,
    required List<MetadataTag> paymentTags,
    required Map<String, String> strings,
    required String currency,
  }) async {
    final monthLabel = _monthNavLabel(strings);
    await showFixedExpenseDetailDialog(
      context: context,
      entry: item,
      categoryTags: categoryTags,
      paymentTags: paymentTags,
      strings: strings,
      currency: currency,
      appliedMonthText: monthLabel,
    );
  }

  Future<void> _showEditor({FixedExpense? item}) async {
    final ledger = ref.read(ledgerProvider).asData?.value;
    final strings = ref.read(localizedStringsProvider);
    if (ledger == null) return;

    final descriptionController =
        TextEditingController(text: item?.description ?? '');
    final amountController =
        TextEditingController(text: item?.amount.toString() ?? '');
    final noteController = TextEditingController(text: item?.note ?? '');
    String categoryCode =
        item?.categoryCode ??
        ledger.tagsByType(MetadataTagType.category).first.code;
    String paymentCode =
        item?.paymentMethodCode ??
        ledger.tagsByType(MetadataTagType.paymentMethod).first.code;
    DateTime appliedAt = item?.appliedAt ?? _focusedMonth;
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
              builder: (BuildContext context, StateSetter setState) {
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
                          setState(() => categoryCode = value);
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
                          setState(() => paymentCode = value);
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
                            setState(() => descriptionError = null);
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
                            setState(() => amountError = null);
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
                                context: context,
                                initialDate: appliedAt,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked == null) return;
                              setState(() {
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

                          final String rawDesc =
                              descriptionController.text.trim();
                          final String rawAmount =
                              amountController.text.trim();
                          final int? parsedAmount =
                              int.tryParse(rawAmount);

                          String? newDescError;
                          String? newAmountError;

                          if (rawDesc.isEmpty) {
                            newDescError =
                                strings['descriptionRequired'] ??
                                '내용을 입력해주세요.';
                          }
                          if (rawAmount.isEmpty) {
                            newAmountError =
                                strings['amountRequired'] ??
                                '금액을 입력해주세요.';
                          } else if (parsedAmount == null) {
                            newAmountError =
                                strings['amountInvalid'] ??
                                '올바른 숫자를 입력해주세요.';
                          }

                          if (newDescError != null ||
                              newAmountError != null) {
                            setState(() {
                              descriptionError = newDescError;
                              amountError = newAmountError;
                            });
                            return;
                          }

                          setState(() => isSaving = true);
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

    if (savedItem != null && mounted) {
      if (item == null) {
        await ref.read(ledgerProvider.notifier).addFixedExpense(savedItem);
      } else {
        await ref.read(ledgerProvider.notifier).updateFixedExpense(savedItem);
      }
      ref.invalidate(ledgerProvider);
      ref.invalidate(monthlyFixedExpensesProvider);
    }
  }

  Future<void> _delete(String id, Map<String, String> strings) async {
    final confirmed = await showLedgerConfirmDialog(
      context: context,
      title: _text(strings, 'confirmDelete'),
      message: _text(strings, 'fixedExpenseTitle'),
      confirmLabel: _text(strings, 'delete'),
      cancelLabel: _text(strings, 'cancel'),
    );
    if (!confirmed) return;

    await ref.read(ledgerProvider.notifier).deleteFixedExpense(id);
    ref.invalidate(ledgerProvider);
    ref.invalidate(monthlyFixedExpensesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final categoryTags = ledger.tagsByType(MetadataTagType.category);
    final paymentTags = ledger.tagsByType(MetadataTagType.paymentMethod);
    final currency = strings['currencyUnit'] ?? '';
    final fixedExpensesAsync =
        ref.watch(monthlyFixedExpensesProvider(_focusedMonth));

    return BootstrapPage(
      title: strings['fixedExpenseTitle'] ?? '',
      actions: <Widget>[
        IconButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRouter.dataManageRoute),
          icon: const Icon(Icons.manage_search_rounded),
          tooltip: strings['dataManageTitle'] ?? '데이터 관리',
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRouter.settingsRoute),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        label: Text(strings['addFixedExpense'] ?? ''),
        icon: const Icon(Icons.add),
      ),
      child: Column(
        children: <Widget>[
          BootstrapSectionCard(
            child: Column(
              children: <Widget>[
                MonthNavigatorBar(
                  displayText: _monthNavLabel(strings),
                  onPrevious: _prevMonth,
                  onNext: _nextMonth,
                  onTap: _pickMonth,
                ),
                const SizedBox(height: 12),
                fixedExpensesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (Object e, _) => Text(e.toString()),
                  data: (List<FixedExpense> items) {
                    final total = items.fold<int>(
                      0,
                      (int sum, FixedExpense e) => sum + e.amount,
                    );
                    return BootstrapSummaryTile(
                      label: _totalLabel(strings),
                      value: '${total.toCurrency()}$currency',
                      color: const Color(0xFF0D6EFD),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: fixedExpensesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Center(child: Text(e.toString())),
              data: (List<FixedExpense> items) {
                if (items.isEmpty) {
                  return Center(child: Text(_text(strings, 'emptyData')));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final item = items[index];
                    final categoryLabel =
                        _resolveTagLabel(categoryTags, item.categoryCode);
                    final amountText =
                        '${item.amount.toCurrency()}$currency';
                    return GestureDetector(
                      onTap: () => _showDetail(
                        item: item,
                        categoryTags: categoryTags,
                        paymentTags: paymentTags,
                        strings: strings,
                        currency: currency,
                      ),
                      child: BootstrapSectionCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              flex: 3,
                              child: Text(
                                categoryLabel,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.description,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Text(
                                amountText,
                                textAlign: TextAlign.right,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFDC3545),
                                    ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showEditor(item: item),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Color(0xFFDC3545),
                              ),
                              onPressed: () => _delete(item.id, strings),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
