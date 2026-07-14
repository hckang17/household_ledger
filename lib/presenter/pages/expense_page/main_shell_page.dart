// """ MVVM 계층: View / Main Feature Shell """
// """ 역할: 가계부 주기능 페이지와 하단 Navigation 상태를 조합 """

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/main_shell_page/bottom_navigation_bar.dart';
import 'package:household_ledger/presenter/pages/expense_page/analysis_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/expense_record_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/fixed_expense_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/home_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/income_page.dart';
import 'package:household_ledger/provider/nav_tab_provider.dart';

/// 바텀 내비게이션 바를 포함하는 공통 쉘 화면이다.
///
/// [IndexedStack]으로 탭 페이지를 보관하며, 처음 방문한 탭만 생성한다(지연 로딩).
/// 탭 전환 시 위젯 트리를 재생성하지 않고 표시/숨김만 전환하므로
/// 스크롤 위치·입력 상태가 탭 전환 후에도 유지된다.
///
/// 현재 탭 인덱스는 [currentNavTabProvider]가 관리한다.
class MainShellPage extends ConsumerStatefulWidget {
  /// [MainShellPage]를 생성한다.
  const MainShellPage({super.key});

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  // 최초 방문한 탭 번호를 추적한다. 홈(2)만 초기에 포함.
  final Set<int> _loadedTabs = {2};

  @override
  void initState() {
    super.initState();
    // 홈 탭이 표시된 직후 나머지 탭을 백그라운드에서 600 ms 간격으로 순차 빌드한다.
    // 사용자가 실제로 보게 될 인스턴스를 미리 준비하므로 첫 탭 전환이 빨라진다.
    const gap = Duration(milliseconds: 600);
    const warmupOrder = <int>[0, 1, 3, 4]; // 수입, 분석, 지출기록, 고정지출
    for (int i = 0; i < warmupOrder.length; i++) {
      final int tab = warmupOrder[i];
      Future.delayed(gap * (i + 1), () {
        if (!mounted) return;
        setState(() => _loadedTabs.add(tab));
      });
    }
  }

  Widget _pageForIndex(int index) {
    switch (index) {
      case 0:
        return const IncomePage();
      case 1:
        return const AnalysisPage();
      case 2:
        return const HomePage();
      case 3:
        return const ExpenseRecordPage();
      case 4:
        return const FixedExpensePage();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int tab = ref.watch(currentNavTabProvider);

    // 현재 탭을 처음 방문하는 경우 로드 목록에 추가한다.
    _loadedTabs.add(tab);

    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: List.generate(5, (i) {
          if (!_loadedTabs.contains(i)) {
            // 아직 방문하지 않은 탭은 빈 위젯으로 대체한다.
            return const SizedBox.shrink();
          }
          return _pageForIndex(i);
        }),
      ),
      bottomNavigationBar: const LedgerBottomNavBar(),
    );
  }
}
