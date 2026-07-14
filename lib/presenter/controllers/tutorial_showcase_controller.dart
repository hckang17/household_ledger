// """ 계층: Presentation / UI Flow Controller """
// """ 역할: 여러 화면에서 반복되는 Showcase 시작, 재시작, 해제 흐름을 통합 """
// """ MVVM 메모: BuildContext에 의존하므로 ViewModel이 아니라 View 전용 Controller """

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

/// 페이지마다 반복되던 Showcase 시작·재시작·해제 흐름을 관리한다.
class TutorialShowcaseController {
  BuildContext? _context;
  bool _started = false;

  // """ Showcase 하위 Builder의 컨텍스트 연결 """
  void bind(BuildContext context) {
    _context = context;
  }

  // """ 조건이 충족될 때 한 번만 튜토리얼 시작 """
  void startIfReady({
    required bool enabled,
    required List<GlobalKey> keys,
    required bool Function() isMounted,
  }) {
    if (!enabled || _started || _context == null || keys.isEmpty) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _context;
      if (!isMounted() || context == null) return;
      ShowCaseWidget.of(context).startShowCase(keys);
    });
  }

  // """ 동일 화면에서 튜토리얼 재시작 허용 """
  void reset() {
    _started = false;
  }

  // """ 현재 Showcase 안전 해제 """
  void dismiss() {
    final context = _context;
    if (context == null) return;
    try {
      ShowCaseWidget.of(context).dismiss();
    } catch (_) {
      // Showcase가 아직 트리에 연결되지 않은 시점의 해제 요청은 무시한다.
    }
  }
}

/// 모든 튜토리얼 페이지에서 같은 종료 확인 UI를 사용한다.
// """ 공통 튜토리얼 종료 확인 Dialog """
Future<bool> showTutorialExitConfirmation({
  required BuildContext context,
  required Map<String, String> strings,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(strings['tutorialExitTitle'] ?? '튜토리얼 종료'),
          content: Text(
            strings['tutorialExitMessage'] ?? '튜토리얼을 종료하시겠습니까?\n완료로 처리됩니다.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings['tutorialContinue'] ?? '계속하기'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings['tutorialExitConfirm'] ?? '종료'),
            ),
          ],
        ),
      ) ??
      false;
}
