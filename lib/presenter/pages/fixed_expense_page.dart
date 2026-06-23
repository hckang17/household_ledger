import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/presenter/common/widgets/fixed_expense_editor_sheet.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/presenter/common/widgets/month_navigator_bar.dart';
import 'package:household_ledger/presenter/common/widgets/month_selector_dialog.dart';
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
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  Future<void> _pickMonth() async {
    final strings = ref.read(localizedStringsProvider);
    final picked = await showMonthSelectorDialog(
      context: context,
      initialMonth: _focusedMonth,
      strings: strings,
      allowFuture: true,
    );
    if (picked == null) return;
    setState(() => _focusedMonth = DateTime(picked.year, picked.month, 1));
  }

  String _text(Map<String, String> strings, String tag) {
    return strings[tag] ??
        '${strings['failedReadingData'] ?? 'ErrorCode: 4401'}+$tag';
  }

  String _monthNavLabel(Map<String, String> strings) {
    final template = strings['monthYearLabel'] ?? '{year}년 {month}월';
    return template
        .replaceAll('{year}', _focusedMonth.year.toString())
        .replaceAll('{month}', _focusedMonth.month.toString().padLeft(2, '0'));
  }

  String _totalLabel(Map<String, String> strings) {
    final template =
        strings['fixedExpenseMonthlyTotalLabel'] ?? '{year}년 {month}월 고정지출 합계';
    return template
        .replaceAll('{year}', _focusedMonth.year.toString())
        .replaceAll('{month}', _focusedMonth.month.toString().padLeft(2, '0'));
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
    final fixedExpensesAsync = ref.watch(
      monthlyFixedExpensesProvider(_focusedMonth),
    );

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
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRouter.settingsRoute),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFixedExpenseEditorSheet(
          context: context,
          ref: ref,
          focusedMonth: _focusedMonth,
        ),
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
              loading: () => const Center(child: CircularProgressIndicator()),
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
                    final categoryLabel = categoryTags.labelFor(
                      item.categoryCode,
                    );
                    final amountText = '${item.amount.toCurrency()}$currency';
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
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.description,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Text(
                                amountText,
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFDC3545),
                                    ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => showFixedExpenseEditorSheet(
                              context: context,
                              ref: ref,
                              focusedMonth: _focusedMonth,
                              item: item,
                            ),
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
