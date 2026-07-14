// """ MVVM 계층: Shared View """
// """ 공통 근거: 데이터 가져오기와 내보내기의 진행 상태 표시에 사용 """

import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';

/// 진행 중 상태를 나타내는 전체화면 반투명 오버레이 위젯이다.
///
/// [Stack] 내부에서 [Positioned.fill]로 사용하며,
/// 화면을 어둡게 가리고 중앙에 진행 카드를 표시한다.
///
/// 사용 예:
/// ```dart
/// Stack(
///   children: [
///     // 본문 내용
///     if (_isLoading)
///       LoadingOverlay(
///         keepOpenMessage: strings['keepAppOpenMessage'] ?? '',
///         progressMessage: strings['exportingMessage'] ?? '',
///       ),
///   ],
/// )
/// ```
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    required this.keepOpenMessage,
    required this.progressMessage,
    super.key,
  });

  /// 상단에 표시할 안내 문구 (예: "앱을 열어 두세요").
  final String keepOpenMessage;

  /// 하단에 표시할 진행 상태 문구 (예: "내보내는 중...").
  final String progressMessage;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: BootstrapSectionCard(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  keepOpenMessage,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  progressMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
