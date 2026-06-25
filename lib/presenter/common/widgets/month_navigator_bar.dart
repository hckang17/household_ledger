import 'package:flutter/material.dart';

/// 월 단위 이동을 위한 네비게이터 바다.
///
/// `< YYYY년 MM월 >` 형태로 표시되며, 중앙 텍스트 탭 시 콜백이 호출된다.
class MonthNavigatorBar extends StatelessWidget {
  /// 월 네비게이터 바를 생성한다.
  const MonthNavigatorBar({
    required this.displayText,
    required this.onPrevious,
    required this.onNext,
    required this.onTap,
    super.key,
    this.textStyle,
  });

  /// 중앙에 표시할 월 텍스트 (예: "2025년 06월").
  final String displayText;

  /// 이전 달 버튼 콜백.
  final VoidCallback onPrevious;

  /// 다음 달 버튼 콜백.
  final VoidCallback onNext;

  /// 중앙 텍스트 탭 콜백 (달 선택 다이얼로그 등).
  final VoidCallback onTap;

  /// 중앙 텍스트 스타일 (null이면 titleMedium bold).
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          splashRadius: 24,
        ),
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              displayText,
              style:
                  textStyle ??
                  Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          splashRadius: 24,
        ),
      ],
    );
  }
}
