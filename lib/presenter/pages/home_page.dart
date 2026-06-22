import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/widgets/expense_editor_sheet.dart';
import 'package:household_ledger/router/app_router.dart';

/// 메인 대시보드 화면이다.
class HomePage extends ConsumerWidget {
  /// 메인 대시보드 화면을 생성한다.
  const HomePage({super.key});

  /// 특정 라우트로 이동한다.
  void _push(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
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

    return BootstrapPage(
      /// 타이틀에 좌측 여백을 추가하여 앱 아이콘과의 간격을 확보한다.
      title: "    ${strings['homeTitle'] ?? ''}",
      actions: <Widget>[
        IconButton(
          onPressed: () => _push(context, AppRouter.settingsRoute),
          icon: const Icon(Icons.settings_outlined),
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
            const SizedBox(height: 20),

            /// 주요 기능 버튼들
            /// 각 버튼은 라우터를 통해 해당 기능 페이지로 이동한다.
            BootstrapActionButton(
              label: strings['incomeManage'] ?? '',
              icon: Icons.trending_up_rounded,
              onPressed: () => _push(context, AppRouter.incomeRoute),
              backgroundColor: const Color(0xFF6C757D),
            ),
            const SizedBox(height: 12),

            /// 고정지출 관리 버튼
            BootstrapActionButton(
              label: strings['fixedExpenseManage'] ?? '',
              icon: Icons.account_balance_wallet_outlined,
              onPressed: () => _push(context, AppRouter.fixedExpenseRoute),
            ),
            const SizedBox(height: 12),

            /// 지출 기록 버튼
            BootstrapActionButton(
              label: strings['expenseRecord'] ?? '',
              icon: Icons.calendar_month_rounded,
              onPressed: () => _push(context, AppRouter.expenseRecordRoute),
              backgroundColor: const Color(0xFF20C997),
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 12),

            /// 지출 분석 버튼
            BootstrapActionButton(
              label: strings['analysis'] ?? '',
              icon: Icons.insights_rounded,
              onPressed: () => _push(context, AppRouter.analysisRoute),
              backgroundColor: const Color(0xFF198754),
            ),
          ],
        ),
      ),
    );
  }
}
