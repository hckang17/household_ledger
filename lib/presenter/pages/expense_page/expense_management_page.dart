// """ MVVM 계층: View / Main Feature Page """
// """ 역할: 소비 기록과 고정지출 관리 화면으로 이동하는 주기능 진입점 """

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/router/app_router.dart';

/// 지출 관리 상위 페이지다.
class ExpenseManagementPage extends ConsumerWidget {
  /// 지출 관리 상위 페이지를 생성한다.
  const ExpenseManagementPage({super.key});

  /// 특정 상세 페이지로 이동한다.
  void _open(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);

    return BootstrapPage(
      title: strings['expenseTopTitle'] ?? '',
      child: Column(
        children: <Widget>[
          BootstrapActionButton(
            label: strings['fixedExpenseManage'] ?? '',
            icon: Icons.account_balance_wallet_outlined,
            onPressed: () => _open(context, AppRouter.fixedExpenseRoute),
          ),
          const SizedBox(height: 12),
          BootstrapActionButton(
            label: strings['expenseRecord'] ?? '',
            icon: Icons.calendar_month_rounded,
            onPressed: () => _open(context, AppRouter.expenseRecordRoute),
            backgroundColor: const Color(0xFF20C997),
          ),
        ],
      ),
    );
  }
}
