import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/services/tutorial_service.dart';

/// 튜토리얼이 현재 어느 화면/단계에 있는지를 나타낸다.
enum TutorialPhase {
  none,
  setup,
  home,
  income,
  fixedExpense,
  expenseRecord,
  analysis,
  pdfReport,
  dataManage,
  settings,
  exportData,
}

/// 튜토리얼 전체 상태를 보관한다.
class TutorialState {
  const TutorialState({
    this.phase = TutorialPhase.none,
    this.isActive = false,
  });

  /// 현재 튜토리얼 단계.
  final TutorialPhase phase;

  /// 튜토리얼이 활성화된 상태인지 여부.
  final bool isActive;

  TutorialState copyWith({TutorialPhase? phase, bool? isActive}) {
    return TutorialState(
      phase: phase ?? this.phase,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// 튜토리얼 상태를 관리하는 Notifier다.
class TutorialNotifier extends Notifier<TutorialState> {
  @override
  TutorialState build() => const TutorialState();

  /// 튜토리얼을 초기 단계(setup)부터 시작한다.
  void startTutorial() {
    state = const TutorialState(
      phase: TutorialPhase.setup,
      isActive: true,
    );
  }

  /// 다음 단계로 전진한다.
  void setPhase(TutorialPhase phase) {
    state = TutorialState(phase: phase, isActive: true);
  }

  /// 튜토리얼을 종료하고 SharedPreferences에 완료 플래그를 저장한다.
  Future<void> completeTutorial() async {
    state = const TutorialState(
      phase: TutorialPhase.none,
      isActive: false,
    );
    await TutorialService().setCompleted(completed: true);
  }

  /// 뒤로가기나 앱 종료로 인해 중도 이탈할 때도 완료 처리한다.
  Future<void> exitTutorial() async {
    state = const TutorialState(
      phase: TutorialPhase.none,
      isActive: false,
    );
    await TutorialService().setCompleted(completed: true);
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, TutorialState>(
  TutorialNotifier.new,
);
