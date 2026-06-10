import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';

/// 고정지출 관리 페이지다.
class FixedExpensePage extends ConsumerStatefulWidget {
  /// 고정지출 관리 페이지를 생성한다.
  const FixedExpensePage({super.key});

  @override
  ConsumerState<FixedExpensePage> createState() => _FixedExpensePageState();
}

/// 고정지출 관리 페이지의 입력 상태를 관리한다.
class _FixedExpensePageState extends ConsumerState<FixedExpensePage> {
  String _text(Map<String, String> strings, String tag) {
    return strings[tag] ??
        '${strings['failedReadingData'] ?? 'ErrorCode: 4401'}+$tag';
  }

  /// 고정지출 입력 시트를 표시한다.
  Future<void> _showEditor({FixedExpense? item}) async {
    final ledger = ref.read(ledgerProvider).asData?.value;
    final strings = ref.read(localizedStringsProvider);
    if (ledger == null) {
      return;
    }

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
    bool isSaving = false;

    final savedItem = await showModalBottomSheet<FixedExpense>(
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
                        label: strings['save'] ?? '',
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
                          final next = FixedExpense.create(
                            id: item?.id,
                            categoryCode: categoryCode,
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

    if (savedItem != null && mounted) {
      if (item == null) {
        await ref.read(ledgerProvider.notifier).addFixedExpense(savedItem);
      } else {
        await ref.read(ledgerProvider.notifier).updateFixedExpense(savedItem);
      }

      ref.invalidate(ledgerProvider);
    }
  }

  /// 고정지출 삭제 여부를 확인한 뒤 삭제한다.
  Future<void> _delete(String id) async {
    final strings = ref.read(localizedStringsProvider);
    final confirmed = await showLedgerConfirmDialog(
      context: context,
      title: _text(strings, 'confirmDelete'),
      message: _text(strings, 'fixedExpenseTitle'),
      confirmLabel: _text(strings, 'delete'),
      cancelLabel: _text(strings, 'cancel'),
    );
    if (!confirmed) {
      return;
    }

    await ref.read(ledgerProvider.notifier).deleteFixedExpense(id);
    ref.invalidate(ledgerProvider);
  }

  /// 코드에 해당하는 태그 이름을 반환한다.
  String _resolveTagLabel(List<MetadataTag> tags, String code) {
    return tags.firstWhere((MetadataTag tag) => tag.code == code).label;
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

    return BootstrapPage(
      title: strings['fixedExpenseTitle'] ?? '',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        label: Text(strings['addFixedExpense'] ?? ''),
        icon: const Icon(Icons.add),
      ),
      child: Column(
        children: <Widget>[
          BootstrapSectionCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: BootstrapSummaryTile(
                    label: strings['fixedExpenseTotal'] ?? '',
                    value:
                        '${ledger.fixedExpenseTotal} ${strings['currencyUnit'] ?? ''}',
                    color: const Color(0xFF0D6EFD),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ledger.fixedExpenses.isEmpty
                ? Center(child: Text(strings['emptyData'] ?? ''))
                : ListView.separated(
                    itemCount: ledger.fixedExpenses.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final item = ledger.fixedExpenses[index];
                      return BootstrapSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.description,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_resolveTagLabel(categoryTags, item.categoryCode)} · ${_resolveTagLabel(paymentTags, item.paymentMethodCode)}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${item.amount} ${strings['currencyUnit'] ?? ''}',
                            ),
                            if (item.note.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(item.note),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                TextButton(
                                  onPressed: () => _showEditor(item: item),
                                  child: Text(strings['edit'] ?? ''),
                                ),
                                TextButton(
                                  onPressed: () => _delete(item.id),
                                  child: Text(strings['delete'] ?? ''),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
