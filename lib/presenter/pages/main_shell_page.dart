import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/common/bottom_navigation_bar.dart';
import 'package:household_ledger/presenter/pages/analysis_page.dart';
import 'package:household_ledger/presenter/pages/expense_record_page.dart';
import 'package:household_ledger/presenter/pages/fixed_expense_page.dart';
import 'package:household_ledger/presenter/pages/home_page.dart';
import 'package:household_ledger/presenter/pages/income_page.dart';
import 'package:household_ledger/provider/nav_tab_provider.dart';

/// 바텀 내비게이션 바를 포함하는 공통 쉘 화면이다.
///
/// [IndexedStack]으로 5개 탭 페이지를 동시에 보관하므로
/// 탭 전환 시 위젯 트리를 재생성하지 않고 표시/숨김만 전환한다.
/// 각 페이지의 스크롤 위치·입력 상태가 탭 전환 후에도 유지된다.
///
/// 현재 탭 인덱스는 [currentNavTabProvider]가 관리한다.
class MainShellPage extends ConsumerWidget {
  /// [MainShellPage]를 생성한다.
  const MainShellPage({super.key});

  static const List<Widget> _pages = <Widget>[
    IncomePage(), // 0: 수입
    AnalysisPage(), // 1: 분석
    HomePage(), // 2: 홈
    ExpenseRecordPage(), // 3: 소비기록
    FixedExpensePage(), // 4: 고정지출
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int tab = ref.watch(currentNavTabProvider);
    return Scaffold(
      body: IndexedStack(index: tab, children: _pages),
      bottomNavigationBar: const LedgerBottomNavBar(),
    );
  }
}
