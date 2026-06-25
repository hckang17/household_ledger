import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/nav_tab_provider.dart';

/// 앱 하단 공통 내비게이션 바다.
///
/// [수입] [분석] [홈] [소비기록] [고정지출] 다섯 항목을 제공한다.
/// [currentNavTabProvider]를 읽어 현재 탭을 표시하고,
/// 탭 전환 시 동일 프로바이더를 업데이트하여 [MainShellPage]의
/// [IndexedStack] 인덱스만 바꾼다 — 전체 화면 재생성 없음.
class LedgerBottomNavBar extends ConsumerWidget {
  /// [LedgerBottomNavBar]를 생성한다.
  const LedgerBottomNavBar({super.key});

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(icon: Icons.trending_up_rounded, labelKey: 'navIncome'),
    _NavItem(icon: Icons.insights_rounded, labelKey: 'navAnalysis'),
    _NavItem(icon: Icons.home_rounded, labelKey: 'navHome'),
    _NavItem(icon: Icons.calendar_month_rounded, labelKey: 'navExpenseRecord'),
    _NavItem(
      icon: Icons.account_balance_wallet_outlined,
      labelKey: 'navFixedExpense',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, String> strings = ref.watch(localizedStringsProvider);
    final int selectedIndex = ref.watch(currentNavTabProvider);

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (int index) {
        if (index == selectedIndex) return;
        ref.read(currentNavTabProvider.notifier).setTab(index);
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
  const _NavItem({required this.icon, required this.labelKey});

  final IconData icon;
  final String labelKey;
}
