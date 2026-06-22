import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 현재 활성화된 바텀 내비게이션 탭 인덱스를 관리하는 Notifier다.
///
/// 인덱스 매핑:
/// - 0: 수입 (IncomePage)
/// - 1: 분석 (AnalysisPage)
/// - 2: 홈   (HomePage)  ← 기본값
/// - 3: 소비기록 (ExpenseRecordPage)
/// - 4: 고정지출 (FixedExpensePage)
class NavTabNotifier extends Notifier<int> {
  @override
  int build() => 2;

  void setTab(int index) => state = index;
}

final currentNavTabProvider = NotifierProvider<NavTabNotifier, int>(
  NavTabNotifier.new,
);
