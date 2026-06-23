import 'dart:async';

import 'package:flutter/material.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/provider/comparison_provider.dart';

/// 비교 카드 내 메시지 한 항목이다.
class _CompMsg {
  const _CompMsg({
    required this.text,
    this.boldText,
    required this.color,
    this.categoryText,
  });
  final String text;
  final String? boldText;     // 금액 — bold + [color]
  final Color color;          // 도트 색 및 boldText 색
  final String? categoryText; // 카테고리명 — 초록색
}

/// 전월동기 비교 카드 위젯이다.
///
/// [result]에서 연산 결과를 받아 메시지를 구성하고 AnimatedSwitcher로 순환 표시한다.
class ComparisonCard extends StatefulWidget {
  const ComparisonCard({
    required this.result,
    required this.strings,
    required this.categoryTags,
    required this.currency,
    super.key,
  });

  final ComparisonResult result;
  final Map<String, String> strings;
  final List<MetadataTag> categoryTags;
  final String currency;

  @override
  State<ComparisonCard> createState() => _ComparisonCardState();
}

class _ComparisonCardState extends State<ComparisonCard> {
  static const Color _categoryGreen = Color(0xFF198754);

  int _msgPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _msgPage++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// _CompMsg의 텍스트를 InlineSpan 목록으로 변환한다.
  ///
  /// - boldText  → FontWeight.w800 + msg.color
  /// - categoryText → FontWeight.w700 + _categoryGreen
  ///
  /// 두 하이라이트 구간을 위치 순서대로 정렬해 단일 패스로 span을 생성한다.
  List<InlineSpan> _buildSpans(_CompMsg msg) {
    final List<(int, int, TextStyle)> hl = <(int, int, TextStyle)>[];

    void addHL(String? sub, TextStyle style) {
      if (sub == null || sub.isEmpty) return;
      final int idx = msg.text.indexOf(sub);
      if (idx >= 0) hl.add((idx, idx + sub.length, style));
    }

    addHL(
      msg.boldText,
      TextStyle(fontWeight: FontWeight.w800, color: msg.color),
    );
    addHL(
      msg.categoryText,
      const TextStyle(fontWeight: FontWeight.w700, color: _categoryGreen),
    );

    if (hl.isEmpty) return <InlineSpan>[TextSpan(text: msg.text)];

    hl.sort((a, b) => a.$1.compareTo(b.$1));

    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final (int start, int end, TextStyle style) in hl) {
      if (start > cursor) {
        spans.add(TextSpan(text: msg.text.substring(cursor, start)));
      }
      spans.add(TextSpan(text: msg.text.substring(start, end), style: style));
      cursor = end;
    }
    if (cursor < msg.text.length) {
      spans.add(TextSpan(text: msg.text.substring(cursor)));
    }
    return spans;
  }

  /// _CompMsg의 실제 렌더 높이를 TextPainter로 측정한다.
  double _measureHeight(_CompMsg msg, double textWidth) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.5),
        children: _buildSpans(msg),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textWidth);
    return tp.height;
  }

  /// 불릿 항목을 빌드한다.
  Widget _bullet(_CompMsg msg) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: msg.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, height: 1.5),
              children: _buildSpans(msg),
            ),
          ),
        ),
      ],
    );
  }

  /// [msgs] 목록을 [page] 인덱스로 순환하는 AnimatedSwitcher 섹션을 빌드한다.
  ///
  /// LayoutBuilder + TextPainter로 최대 높이를 사전 계산해 고정함으로써
  /// 카드 높이가 애니메이션 도중 변동되지 않도록 한다.
  Widget _animatedSection(List<_CompMsg> msgs, int page) {
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints bc) {
        final double textWidth = bc.maxWidth - 13.0;
        const double lineH = 13.0 * 1.5;
        double maxH = lineH;
        for (final _CompMsg msg in msgs) {
          final double h = _measureHeight(msg, textWidth);
          if (h > maxH) maxH = h;
        }
        // TextPainter의 디센더/서브픽셀 오차 보정값
        final double fixedH = maxH + lineH * 0.5;
        final int idx = page % msgs.length;

        return SizedBox(
          height: fixedH,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (Widget child, Animation<double> anim) =>
                FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOut),
                ),
                child: child,
              ),
            ),
            child: SizedBox(
              key: ValueKey<int>(idx),
              width: double.infinity,
              height: fixedH,
              child: _bullet(msgs[idx]),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ComparisonResult result = widget.result;
    final Map<String, String> strings = widget.strings;
    final String currency = widget.currency;

    final Color accentColor =
        result.moreSpent ? const Color(0xFFDC3545) : const Color(0xFF0D6EFD);
    final String amountText = '${result.diff.abs().toCurrency()}$currency';
    final String percentText = result.diffPercent.toStringAsFixed(1);

    final String headerLine = result.moreSpent
        ? (strings['homeCompMorePercent'] ?? '{percent}% 더 사용하셨네요!')
            .replaceAll('{percent}', percentText)
        : (strings['homeCompLessPercent'] ?? '{percent}% 덜 사용하셨네요!')
            .replaceAll('{percent}', percentText);

    // [1] 총액 고정 메시지
    final _CompMsg msg1 = result.moreSpent
        ? _CompMsg(
            text: (strings['homeCompMoreAmountMsg'] ??
                    '지난달 보다 {amount} 더 사용하셨어요.')
                .replaceAll('{amount}', amountText),
            boldText: amountText,
            color: accentColor,
          )
        : _CompMsg(
            text: (strings['homeCompLessAmountMsg'] ??
                    '지난달 보다 {amount} 덜 사용하고 있어요!! 이대로 관리해볼까요?')
                .replaceAll('{amount}', amountText),
            boldText: amountText,
            color: accentColor,
          );

    // [2] 카테고리별 증감 메시지 목록 (모든 카테고리 순환)
    final List<_CompMsg> categoryMsgs =
        result.catDiffs.map((MapEntry<String, int> e) {
      final bool catMore = e.value > 0;
      final String catAmt = '${e.value.abs().toCurrency()}$currency';
      final String label = widget.categoryTags.labelFor(e.key);
      return catMore
          ? _CompMsg(
              text: (strings['homeCompMoreCategoryMsg'] ??
                      '지난달 보다 {category}에서 {amount} 더 지출이 많아요.')
                  .replaceAll('{category}', label)
                  .replaceAll('{amount}', catAmt),
              boldText: catAmt,
              color: const Color(0xFFDC3545),
              categoryText: label,
            )
          : _CompMsg(
              text: (strings['homeCompLessCategoryAmountMsg'] ??
                      '지난달 보다 {category}에서 {amount} 지출이 줄었어요.')
                  .replaceAll('{category}', label)
                  .replaceAll('{amount}', catAmt),
              boldText: catAmt,
              color: const Color(0xFF0D6EFD),
              categoryText: label,
            );
    }).toList();

    // [3] 지출 증가 카테고리별 절감 권유 메시지 순환
    final List<_CompMsg> adviceMsgs = <_CompMsg>[];
    if (result.moreSpent) {
      const List<String> adviceKeys = <String>[
        'homeCompMoreAdviceMsg',
        'homeCompMoreAdviceMsg2',
        'homeCompMoreAdviceMsg3',
      ];
      final List<MapEntry<String, int>> gainers = result.gainers;
      for (int i = 0; i < gainers.length; i++) {
        final String label = widget.categoryTags.labelFor(gainers[i].key);
        final String template =
            strings[adviceKeys[i % adviceKeys.length]] ??
            '{category}의 소비를 줄여볼까요?';
        adviceMsgs.add(_CompMsg(
          text: template.replaceAll('{category}', label),
          color: Colors.orange.shade700,
          categoryText: label,
        ));
      }
    }

    return BootstrapSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 헤더
          Row(
            children: <Widget>[
              Icon(
                result.moreSpent
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 6),
              Text(
                strings['homeCompPrevPeriodTitle'] ?? '지난달 동기 대비',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            headerLine,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 6),

          // [1] 총액 고정 불릿
          _bullet(msg1),

          // [2] 카테고리별 순환 불릿
          if (categoryMsgs.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            _animatedSection(categoryMsgs, _msgPage),
          ],

          // [3] 절감 권유 순환 불릿
          if (adviceMsgs.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            _animatedSection(adviceMsgs, _msgPage),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
