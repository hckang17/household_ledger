// """ MVVM 계층: View / generating_report_page """
// """ 역할: PDF 생성 안내와 단계별 진행률 표시 """

import 'package:flutter/material.dart';

/// PDF 생성 중 앱 종료 주의 문구와 진행률을 표시하는 카드다.
class ReportGenerationProgress extends StatelessWidget {
  const ReportGenerationProgress({
    required this.progress,
    required this.strings,
    super.key,
  });

  final double progress;
  final Map<String, String> strings;

  String _text(String key, String fallback) => strings[key] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final double safeProgress = progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F1FF),
        border: Border.all(color: const Color(0xFFB6D4FE)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: Color(0xFF084298),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _text(
                    'reportGeneratingNotice',
                    'PDF가 작성될 때까지 앱을 종료하지 말아주세요. '
                        '열심히 보고서를 작성 중입니다.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF084298),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: safeProgress,
              minHeight: 8,
              backgroundColor: const Color(0xFFD0E2FF),
              color: const Color(0xFF0D6EFD),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(safeProgress * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFF084298),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
