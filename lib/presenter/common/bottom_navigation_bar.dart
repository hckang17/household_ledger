import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';

/// 앱 하단 공통 내비게이션 바다.
///
/// [수입] [분석] [홈] [소비기록] [고정지출] 다섯 항목을 제공하며,
/// 현재 라우트를 자동으로 감지해 해당 탭을 활성화한다.
/// 탭 전환은 [Navigator.pushReplacementNamed]로 처리하므로
/// 기존 라우팅 스택과 충돌하지 않는다.
class LedgerBottomNavBar extends ConsumerWidget {
  /// [LedgerBottomNavBar]를 생성한다.
  const LedgerBottomNavBar({super.key});

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(
      route: AppRouter.incomeRoute,
      icon: Icons.trending_up_rounded,
      labelKey: 'navIncome',
    ),
    _NavItem(
      route: AppRouter.analysisRoute,
      icon: Icons.insights_rounded,
      labelKey: 'navAnalysis',
    ),
    _NavItem(
      route: AppRouter.homeRoute,
      icon: Icons.home_rounded,
      labelKey: 'navHome',
    ),
    _NavItem(
      route: AppRouter.expenseRecordRoute,
      icon: Icons.calendar_month_rounded,
      labelKey: 'navExpenseRecord',
    ),
    _NavItem(
      route: AppRouter.fixedExpenseRoute,
      icon: Icons.account_balance_wallet_outlined,
      labelKey: 'navFixedExpense',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final selectedIndex = _items.indexWhere(
      (_NavItem item) => item.route == currentRoute,
    );

    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 2 : selectedIndex,
      onDestinationSelected: (int index) {
        final String targetRoute = _items[index].route;
        if (targetRoute == currentRoute) return;
        Navigator.of(context).pushReplacementNamed(targetRoute);
      },
      destinations: _items.map((_NavItem item) {
        return NavigationDestination(
          icon: Icon(item.icon),
          label: strings[item.labelKey] ?? item.labelKey,
        );
      }).toList(),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.icon,
    required this.labelKey,
  });

  final String route;
  final IconData icon;
  final String labelKey;
}
