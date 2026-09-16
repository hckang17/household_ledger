import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_dialog.dart';

/// 최상위 화면의 시스템 뒤로가기를 앱 종료 확인 흐름으로 변환한다.
///
/// 광고나 종료 전 저장 같은 비동기 작업은 [onBeforeExit]에 연결한다. 해당
/// 작업이 끝난 뒤 [exitApp]을 호출하므로 종료 UI와 부가 동작이 결합되지 않는다.
class AppExitGuard extends StatefulWidget {
  const AppExitGuard({
    required this.child,
    required this.strings,
    this.onBeforeExit,
    this.exitApp,
    super.key,
  });

  final Widget child;
  final Map<String, String> strings;
  final Future<void> Function()? onBeforeExit;
  final Future<void> Function()? exitApp;

  @override
  State<AppExitGuard> createState() => _AppExitGuardState();
}

class _AppExitGuardState extends State<AppExitGuard> {
  bool _handlingPop = false;

  String _text(String key, String fallback) => widget.strings[key] ?? fallback;

  Future<void> _requestExit() async {
    if (_handlingPop) return;
    _handlingPop = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => BootstrapDialog(
          title: _text('appExitTitle', '앱 종료'),
          icon: Icons.logout_rounded,
          iconColor: const Color(0xFF6C757D),
          content: Text(_text('appExitMessage', '가계부 앱을 종료하시겠습니까?')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_text('cancel', '취소')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_text('appExitConfirm', '종료')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await widget.onBeforeExit?.call();
      if (!mounted) return;
      await (widget.exitApp?.call() ?? _systemExit());
    } finally {
      _handlingPop = false;
    }
  }

  Future<void> _systemExit() => SystemNavigator.pop();

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_requestExit());
      },
      child: widget.child,
    );
  }
}
