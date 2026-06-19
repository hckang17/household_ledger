import 'package:flutter/material.dart';

/// 부트스트랩 스타일을 참고한 카드 래퍼를 제공한다.
class BootstrapSectionCard extends StatelessWidget {
  /// 공통 카드 위젯을 생성한다.
  const BootstrapSectionCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.width = double.infinity,
  });

  /// 카드 내부 자식을 보관한다.
  final Widget child;

  /// 카드 내부 여백을 보관한다.
  final EdgeInsetsGeometry padding;

  /// 카드의 넓이를 보관한다.
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// 메인 액션 버튼 스타일을 제공한다.
class BootstrapActionButton extends StatelessWidget {
  /// 액션 버튼을 생성한다.
  const BootstrapActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
    this.backgroundColor = const Color(0xFF0D6EFD),
    this.foregroundColor = Colors.white,
  });

  /// 버튼 라벨을 보관한다.
  final String label;

  /// 버튼 아이콘을 보관한다.
  final IconData icon;

  /// 버튼 클릭 동작을 보관한다.
  final VoidCallback? onPressed;

  /// 버튼 배경색을 보관한다.
  final Color backgroundColor;

  /// 버튼 전경색을 보관한다.
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

/// 요약 정보를 시각적으로 보여주는 타일을 제공한다.
class BootstrapSummaryTile extends StatelessWidget {
  /// 요약 타일을 생성한다.
  const BootstrapSummaryTile({
    required this.label,
    required this.value,
    required this.color,
    super.key,
    this.fontSize = 18,
  });

  /// 타일 라벨을 보관한다.
  final String label;

  /// 타일 값을 보관한다.
  final String value;

  /// 타일 강조 색상을 보관한다.
  final double fontSize;

  /// 강조 색상을 보관한다.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면 공통 배경 레이아웃을 제공한다.
class BootstrapPage extends StatelessWidget {
  /// 공통 페이지 래퍼를 생성한다.
  const BootstrapPage({
    required this.title,
    required this.child,
    super.key,
    this.actions,
    this.floatingActionButton,
  });

  /// 페이지 제목을 보관한다.
  final String title;

  /// 페이지 본문을 보관한다.
  final Widget child;

  /// 앱바 액션을 보관한다.
  final List<Widget>? actions;

  /// 플로팅 버튼을 보관한다.
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// 앱바는 페이지마다 일관된 스타일을 유지하되, 제목과 액션은 페이지별로 다르게 설정할 수 있도록 한다.
      appBar: AppBar(
        titleSpacing: 0,
        scrolledUnderElevation: 0,
        actionsPadding: const EdgeInsets.only(right: 16),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: actions,
      ),

      /// 프롤팅 버튼이 있을 경우, 플로팅 버튼을 상속받아온다.
      floatingActionButton: floatingActionButton,

      /// 페이지 본문은 공통된 배경과 여백을 갖게 한다.
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F7FB), Color(0xFFE8EEF8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    );
  }
}
