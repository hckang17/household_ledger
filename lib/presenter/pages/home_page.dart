import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/presenter/common/widgets/comparison_card.dart';
import 'package:household_ledger/presenter/common/widgets/expense_editor_sheet.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/presenter/common/widgets/recent_expenses_list.dart';
import 'package:household_ledger/provider/comparison_provider.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';

/// 메인 대시보드 화면이다.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _deleteExpense(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> strings,
    ExpenseEntry entry,
    String currency,
  ) async {
    final summary =
        '${entry.description} : ${entry.amount.toCurrency()}$currency\n'
        '${strings['deleteAlertCaution'] ?? ''}';
    final confirmed = await showLedgerConfirmDialog(
      context: context,
      title: strings['confirmDelete'] ?? '삭제 확인',
      message: '$summary ${strings['confirmDeleteQuestion'] ?? ''}',
      confirmLabel: strings['delete'] ?? '삭제',
      cancelLabel: strings['cancel'] ?? '취소',
    );
    if (!confirmed) return;
    await ref.read(ledgerProvider.notifier).deleteExpense(entry.id);
    ref.invalidate(monthlyExpensesProvider);
    ref.invalidate(rangeExpensesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    final compResult = ref.watch(comparisonProvider);
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final monthlyExpense = ledger?.monthlyExpenseTotal(month) ?? 0;
    final monthlyIncomes = ref
        .watch(monthlyIncomesProvider(month))
        .asData
        ?.value;
    final monthlyIncomeTotal = (monthlyIncomes ?? const <IncomeEntry>[])
        .fold<int>(0, (int total, IncomeEntry entry) => total + entry.amount);
    final monthlyBudget = ledger == null
        ? 0
        : (monthlyIncomeTotal > 0
              ? monthlyIncomeTotal
              : ledger.settings.monthlyBudget);
    final monthlyFixedExpense = ledger?.fixedExpenseTotalForMonth(month) ?? 0;
    final remainingBudget = ledger == null
        ? 0
        : monthlyBudget - monthlyExpense - monthlyFixedExpense;
    final greeting = ledger == null
        ? ''
        : (strings['homepageGreeting'] ?? '{name}').replaceAll(
            '{name}',
            ledger.userProfile.name,
          );

    final recentExpensesAsync = ref.watch(monthlyExpensesProvider(month));
    final currency = strings['currencyUnit'] ?? '';
    final categoryTags =
        ledger?.tagsByType(MetadataTagType.category) ?? const <MetadataTag>[];
    final subcategoryTags =
        ledger?.tagsByType(MetadataTagType.subcategory) ??
        const <MetadataTag>[];
    final paymentTags =
        ledger?.tagsByType(MetadataTagType.paymentMethod) ??
        const <MetadataTag>[];

    return BootstrapPage(
      title: strings['homeTitle'] ?? '',
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
          tooltip: strings['settingsTitle'] ?? '설정',
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BootstrapSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: BootstrapSummaryTile(
                          label: strings['totalSpent'] ?? '',
                          value:
                              '${monthlyExpense.toCurrency()} ${strings['currencyUnit'] ?? ''}',
                          color: const Color(0xFFDC3545),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BootstrapSummaryTile(
                          label: strings['remainingBudget'] ?? '',
                          value:
                              '${remainingBudget.toCurrency()} ${strings['currencyUnit'] ?? ''}',
                          color: const Color(0xFF198754),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 전월동기 비교 카드 (전월 데이터가 있을 때만 표시)
            if (compResult != null) ...<Widget>[
              ComparisonCard(
                result: compResult,
                strings: strings,
                categoryTags: categoryTags,
                currency: currency,
              ),
              const SizedBox(height: 10),
            ],

            // 빠른 지출 기록 버튼
            BootstrapActionButton(
              label: strings['quickExpense'] ?? '',
              icon: Icons.add_circle_outline_rounded,
              onPressed: () => showExpenseEditorSheet(
                context: context,
                ref: ref,
                initialDate: DateTime.now(),
              ),
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: const Color(0xFF102A43),
            ),

            const SizedBox(height: 10),

            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    strings['homeRecentExpensesTitle'] ?? '최근 소비 기록',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(AppRouter.expenseRecordRoute),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(strings['homeViewAll'] ?? '더보기'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            recentExpensesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, _) => const SizedBox.shrink(),
              data: (List<ExpenseEntry> entries) => RecentExpensesList(
                entries: entries,
                categoryTags: categoryTags,
                subcategoryTags: subcategoryTags,
                paymentTags: paymentTags,
                currency: currency,
                strings: strings,
                onTap: (ExpenseEntry entry) => showExpenseDetailDialog(
                  context: context,
                  entry: entry,
                  categoryTags: categoryTags,
                  subcategoryTags: subcategoryTags,
                  paymentTags: paymentTags,
                  strings: strings,
                  currency: currency,
                ),
                onEdit: (ExpenseEntry entry) => showExpenseEditorSheet(
                  context: context,
                  ref: ref,
                  entry: entry,
                  initialDate: entry.spentAt,
                ),
                onDelete: (ExpenseEntry entry) =>
                    _deleteExpense(context, ref, strings, entry, currency),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
