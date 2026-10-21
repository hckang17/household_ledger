// """ MVVM 계층: View / Main Feature Shell """
// """ 역할: 가계부 주기능 페이지와 하단 Navigation 상태를 조합 """

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/main_shell_page/main_shell_bottom_bar.dart';
import 'package:household_ledger/presenter/pages/expense_page/analysis_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/expense_record_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/fixed_expense_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/home_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/income_page.dart';
import 'package:household_ledger/presenter/widgets/common/app_exit_guard.dart';
import 'package:household_ledger/provider/nav_tab_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';

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
  // 시간차로 다른 탭을 만들면 첫 스크롤과 무관한 레이아웃 작업이 겹친다.
  // 방문할 때만 생성하고 이후 인스턴스와 스크롤 위치를 보관한다.
  final Set<int> _loadedTabs = {2};

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
    final strings = ref.watch(localizedStringsProvider);

    // 현재 탭을 처음 방문하는 경우 로드 목록에 추가한다.
    _loadedTabs.add(tab);

    return AppExitGuard(
      strings: strings,
      child: Scaffold(
        body: IndexedStack(
          index: tab,
          children: List.generate(5, (i) {
            if (!_loadedTabs.contains(i)) {
              // 아직 방문하지 않은 탭은 빈 위젯으로 대체한다.
              return const SizedBox.shrink();
            }
            return TickerMode(enabled: i == tab, child: _pageForIndex(i));
          }),
        ),
        bottomNavigationBar: const MainShellBottomBar(),
      ),
    );
  }
}
