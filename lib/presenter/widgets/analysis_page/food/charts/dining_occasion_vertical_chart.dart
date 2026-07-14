// """ 계층: Presentation / Chart View """
// """ 역할: 현재 기간과 전월동기의 외식 유형별 횟수를 세로 막대로 비교 """
// """ 입력: 계산이 끝난 태그별 횟수만 받고 집계 로직은 수행하지 않음 """

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:household_ledger/model/metadata_tag.dart';

// """ 외식 유형 비교 차트 """
class DiningOccasionVerticalChart extends StatelessWidget {
  const DiningOccasionVerticalChart({
    required this.tags,
    required this.currentCounts,
    required this.previousCounts,
    required this.color,
    super.key,
  });

  final List<MetadataTag> tags;
  final Map<String, int> currentCounts;
  final Map<String, int> previousCounts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final int maxCount = <int>[
      ...currentCounts.values,
      ...previousCounts.values,
      1,
    ].reduce(math.max);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double minimumGroupWidth = 52;
        final double groupWidth = tags.length <= 6
            ? math.max(minimumGroupWidth, constraints.maxWidth / tags.length)
            : minimumGroupWidth;
        final double chartWidth = math.max(
          constraints.maxWidth,
          groupWidth * tags.length,
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            height: 210,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tags.map((MetadataTag tag) {
                final int current = currentCounts[tag.code] ?? 0;
                final int previous = previousCounts[tag.code] ?? 0;
                return Semantics(
                  label: '${tag.label}, $current, $previous',
                  child: SizedBox(
                    width: groupWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                _AnimatedVerticalBar(
                                  value: current,
                                  maxValue: maxCount,
                                  color: color,
                                ),
                                const SizedBox(width: 1),
                                _AnimatedVerticalBar(
                                  value: previous,
                                  maxValue: maxCount,
                                  color: const Color(0xFFB8C4D1),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 7),
                          SizedBox(
                            height: 42,
                            child: Text(
                              tag.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// """ 애니메이션 막대 단위 """
class _AnimatedVerticalBar extends StatelessWidget {
  const _AnimatedVerticalBar({
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double fraction = maxValue <= 0 ? 0 : value / maxValue;
    return SizedBox(
      width: 17,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder:
            (BuildContext context, double animatedFraction, Widget? child) {
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double maximumBarHeight = math.max(
                    0,
                    constraints.maxHeight - 20,
                  );
                  final double barHeight = maximumBarHeight * animatedFraction;
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: barHeight + 2,
                        height: 16,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$value',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
      ),
    );
  }
}
