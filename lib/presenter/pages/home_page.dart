import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/presenter/common/bottom_navigation_bar.dart';
import 'package:household_ledger/presenter/common/widgets/expense_editor_sheet.dart';
import 'package:household_ledger/presenter/common/widgets/expense_entry_tile.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';

/// 메인 대시보드 화면이다.
class HomePage extends ConsumerWidget {
  /// 메인 대시보드 화면을 생성한다.
  const HomePage({super.key});

  /// 특정 라우트로 이동한다.
  void _push(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  /// 태그 목록에서 code에 해당하는 label을 반환한다.
  String _resolveTagLabel(List<MetadataTag> tags, String code) {
    try {
      return tags.firstWhere((MetadataTag t) => t.code == code).label;
    } catch (_) {
      return code;
    }
  }

  /// 삭제 확인 다이얼로그를 표시한 뒤 소비 항목을 삭제한다.
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
          onPressed: () => _push(context, AppRouter.settingsRoute),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      bottomNavigationBar: const LedgerBottomNavBar(),
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
                      /// 월간 지출 표시
                      Expanded(
                        child: BootstrapSummaryTile(
                          label: strings['totalSpent'] ?? '',
                          value:
                              '${monthlyExpense.toCurrency()} ${strings['currencyUnit'] ?? ''}',
                          color: const Color(0xFFDC3545),
                        ),
                      ),
                      const SizedBox(width: 12),

                      /// 남은 예산 표시
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

            /// 빠른 지출 기록 버튼 (홈 화면에서 바로 지출 기록으로)
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

            /// 최근 소비 기록 섹션 헤더
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
                  onPressed: () => _push(context, AppRouter.expenseRecordRoute),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(strings['homeViewAll'] ?? '더보기'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            /// 최근 소비 기록 목록 (최대 5건, 날짜 내림차순)
            recentExpensesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, _) => const SizedBox.shrink(),
              data: (List<ExpenseEntry> entries) {
                if (ledger == null || entries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(strings['emptyData'] ?? '데이터가 없습니다.'),
                    ),
                  );
                }

                final sorted = entries.toList()
                  ..sort(
                    (ExpenseEntry a, ExpenseEntry b) =>
                        b.spentAt.compareTo(a.spentAt),
                  );
                final recent = sorted.take(5).toList();

                final grouped = <DateTime, List<ExpenseEntry>>{};
                for (final ExpenseEntry e in recent) {
                  final day = DateTime(
                    e.spentAt.year,
                    e.spentAt.month,
                    e.spentAt.day,
                  );
                  grouped.putIfAbsent(day, () => <ExpenseEntry>[]).add(e);
                }
                final groupedList = grouped.entries.toList()
                  ..sort(
                    (
                      MapEntry<DateTime, List<ExpenseEntry>> a,
                      MapEntry<DateTime, List<ExpenseEntry>> b,
                    ) => b.key.compareTo(a.key),
                  );

                final daySectionTemplate =
                    strings['expenseRecordDaySectionLabel'] ??
                    '{month}월 {day}일';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final MapEntry<DateTime, List<ExpenseEntry>> section
                        in groupedList) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 4,
                          top: 4,
                          bottom: 8,
                        ),
                        child: Text(
                          daySectionTemplate
                              .replaceAll(
                                '{month}',
                                section.key.month.toString().padLeft(2, '0'),
                              )
                              .replaceAll(
                                '{day}',
                                section.key.day.toString().padLeft(2, '0'),
                              ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1F3A5F),
                              ),
                        ),
                      ),
                      for (final ExpenseEntry entry in section.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ExpenseEntryTile(
                            entry: entry,
                            categoryLabel: _resolveTagLabel(
                              categoryTags,
                              entry.categoryCode,
                            ),
                            currency: currency,
                            editTooltip: strings['edit'] ?? '수정',
                            deleteTooltip: strings['delete'] ?? '삭제',
                            onTap: () => showExpenseDetailDialog(
                              context: context,
                              entry: entry,
                              categoryTags: categoryTags,
                              subcategoryTags: subcategoryTags,
                              paymentTags: paymentTags,
                              strings: strings,
                              currency: currency,
                            ),
                            onEdit: () => showExpenseEditorSheet(
                              context: context,
                              ref: ref,
                              entry: entry,
                              initialDate: entry.spentAt,
                            ),
                            onDelete: () => _deleteExpense(
                              context,
                              ref,
                              strings,
                              entry,
                              currency,
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
