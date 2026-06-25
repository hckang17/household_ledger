import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';

/// 도넛 그래프 하나의 섹션(카테고리) 데이터를 보관하는 모델이다.
class DonutSection {
  /// 도넛 섹션 데이터를 생성한다.
  const DonutSection({
    required this.categoryCode,
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
  });

  /// 카테고리 코드를 보관한다(필터링에 사용됨).
  final String categoryCode;

  /// 화면에 표시할 카테고리 이름을 보관한다.
  final String label;

  /// 이 카테고리의 합계 금액을 보관한다.
  final int amount;

  /// 전체 지출 대비 비율(0~100)을 보관한다.
  final double percentage;

  /// 그래프 상의 섹션 색상을 보관한다.
  final Color color;
}

/// 카테고리별 섹션에 사용할 색상 팔레트를 정의한다.
const List<Color> kDonutSectionColors = <Color>[
  Color(0xFF1ABC9C),
  Color(0xFF3498DB),
  Color(0xFF9B59B6),
  Color(0xFFE74C3C),
  Color(0xFFF39C12),
  Color(0xFF27AE60),
  Color(0xFFE67E22),
  Color(0xFF2980B9),
  Color(0xFFD35400),
  Color(0xFF8E44AD),
  Color(0xFF16A085),
  Color(0xFF2C3E50),
];

/// 카테고리별 지출 비율을 도넛 형태의 원형 그래프로 표시하는 위젯이다.
///
/// 사용자가 섹션을 터치하면 [onTouchUpdate]가 호출되어 부모에서 상태를 관리한다.
/// 손가락을 뗄 때([FlTapUpEvent]) [onSectionTap]이 호출되어 탭 액션을 처리한다.
/// 선택된 섹션은 반경이 커지면서 강조 표시된다.
/// 금액 기준 상위 3개 섹션에는 외부 뱃지 라벨이 표시된다.
class AnalysisDonutChart extends StatelessWidget {
  /// 도넛 차트 위젯을 생성한다.
  const AnalysisDonutChart({
    required this.sections,
    required this.touchedIndex,
    required this.onTouchUpdate,
    required this.totalLabel,
    required this.totalAmount,
    this.currency = '',
    this.onSectionTap,
    this.totalDiffText,
    this.totalDiffColor,
    super.key,
  });

  /// 표시할 섹션 목록을 보관한다.
  final List<DonutSection> sections;

  /// 현재 터치된 섹션 인덱스를 보관한다(-1이면 선택 없음).
  final int touchedIndex;

  /// 터치 상태 변화 시 호출되는 콜백이다(-1은 선택 해제).
  final void Function(int index) onTouchUpdate;

  /// 손가락을 뗄 때 호출되는 탭 콜백이다. 탭 기반 내비게이션에 사용한다.
  final void Function(int index)? onSectionTap;

  /// 그래프 중앙 하단에 표시할 "전체" 라벨 텍스트다.
  final String totalLabel;

  /// 전체 합계 금액 문자열이다.
  final String totalAmount;

  /// 외부 뱃지 라벨에 표시할 통화 기호다(예: "₩").
  final String currency;

  /// 전월동기 대비 차액 텍스트다(예: "▲1,234₩"). null이면 표시하지 않는다.
  final String? totalDiffText;

  /// 전월동기 차액 텍스트의 색상이다.
  final Color? totalDiffColor;

  @override
  Widget build(BuildContext context) {
    /// 섹션이 없을 때 표시하는 빈 상태 아이콘 영역이다.
    if (sections.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.pie_chart_outline,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 8),
              Text(
                totalAmount,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final DonutSection? touched =
        touchedIndex >= 0 && touchedIndex < sections.length
        ? sections[touchedIndex]
        : null;

    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          /// fl_chart PieChart로 도넛 그래프를 그리는 영역이다.
          /// centerSpaceRadius로 가운데를 비워 도넛 형태를 만든다.
          /// 상위 3개 섹션에는 외부 뱃지 라벨([_SectionBadge])을 표시한다.
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback:
                    (FlTouchEvent event, PieTouchResponse? response) {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        onTouchUpdate(-1);
                        return;
                      }
                      final int idx =
                          response.touchedSection!.touchedSectionIndex;
                      onTouchUpdate(idx);

                      /// 손가락을 뗄 때만 탭 콜백을 호출해 불필요한 중복 발동을 막는다.
                      if (event is FlTapUpEvent) {
                        onSectionTap?.call(idx);
                      }
                    },
              ),
              centerSpaceRadius: 72,
              sectionsSpace: 2,
              sections: sections.asMap().entries.map((
                MapEntry<int, DonutSection> entry,
              ) {
                final bool isTouched = entry.key == touchedIndex;

                /// 터치되지 않은 상위 3개 섹션에만 외부 라벨 뱃지를 표시한다.
                final bool showBadge = !isTouched && entry.key < 3;
                final DonutSection s = entry.value;
                return PieChartSectionData(
                  color: s.color,
                  value: s.amount.toDouble(),

                  /// 터치된 섹션만 반경을 크게 해서 강조 표시한다.
                  radius: isTouched ? 64 : 50,

                  /// 터치된 섹션에만 비율 텍스트를 섹션 내부에 표시한다.
                  title: isTouched ? '${s.percentage.toStringAsFixed(0)}%' : '',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    shadows: <Shadow>[
                      Shadow(blurRadius: 2, color: Colors.black26),
                    ],
                  ),
                  badgeWidget: showBadge
                      ? _SectionBadge(section: s, currency: currency)
                      : null,
                  badgePositionPercentageOffset: 1.35,
                );
              }).toList(),
            ),
          ),

          /// 도넛 중앙에 선택된 카테고리 이름과 비율을 오버레이로 표시하는 영역이다.
          /// 아무것도 선택되지 않으면 전체 합계를 표시한다.
          Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  touched?.label ?? totalLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  touched != null
                      ? '${touched.percentage.toStringAsFixed(1)}%'
                      : totalAmount,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: touched?.color ?? const Color(0xFF0D6EFD),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (touched == null && totalDiffText != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    totalDiffText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: totalDiffColor ?? Colors.grey.shade500,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 도넛 차트 섹션 외부에 표시되는 카테고리 라벨 뱃지다.
/// 카테고리명(색상)과 합계 금액을 2줄로 표시한다.
class _SectionBadge extends StatelessWidget {
  const _SectionBadge({required this.section, required this.currency});

  final DonutSection section;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            section.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: section.color,
            ),
          ),
          Text(
            '${section.amount.toCurrency()}$currency',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}
