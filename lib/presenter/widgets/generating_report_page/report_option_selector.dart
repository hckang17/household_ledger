// """ MVVM 계층: View / generating_report_page """
// """ 역할: PDF에 포함할 리포트 섹션 옵션 선택 UI 제공 """

import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';

/// PDF 리포트에 포함할 데이터를 체크박스로 선택하는 카드다.
class ReportOptionSelector extends StatelessWidget {
  const ReportOptionSelector({
    required this.includeTop10,
    required this.includeFixedExpenses,
    required this.includePaymentSummary,
    required this.includeDetailedData,
    required this.includePrevComparison,
    required this.includePrevCategoryAnalysis,
    required this.strings,
    required this.onTop10Changed,
    required this.onFixedChanged,
    required this.onPaymentChanged,
    required this.onDetailedChanged,
    required this.onPrevComparisonChanged,
    required this.onPrevCategoryAnalysisChanged,
    super.key,
  });

  final bool includeTop10;
  final bool includeFixedExpenses;
  final bool includePaymentSummary;
  final bool includeDetailedData;
  final bool includePrevComparison;
  final bool includePrevCategoryAnalysis;
  final Map<String, String> strings;
  final ValueChanged<bool> onTop10Changed;
  final ValueChanged<bool> onFixedChanged;
  final ValueChanged<bool> onPaymentChanged;
  final ValueChanged<bool> onDetailedChanged;
  final ValueChanged<bool> onPrevComparisonChanged;
  final ValueChanged<bool> onPrevCategoryAnalysisChanged;

  String _text(String key, [String fallback = '']) => strings[key] ?? fallback;

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _text('reportIncludeDataTitle', '포함할 데이터'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('reportIncludeTop10', 'Top 10 지출 내역')),
            value: includeTop10,
            onChanged: (bool? v) => onTop10Changed(v ?? true),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('reportIncludeFixedExpenses', '고정지출 내역')),
            value: includeFixedExpenses,
            onChanged: (bool? v) => onFixedChanged(v ?? true),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('reportIncludePaymentSummary', '소비수단 별 요약')),
            value: includePaymentSummary,
            onChanged: (bool? v) => onPaymentChanged(v ?? true),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text('reportIncludeDetailedData', '전체 거래내역 (부록)')),
            value: includeDetailedData,
            onChanged: (bool? v) => onDetailedChanged(v ?? true),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _text('reportIncludePrevComparison', '전월동기대비 소비데이터 포함'),
            ),
            value: includePrevComparison,
            onChanged: (bool? v) => onPrevComparisonChanged(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _text(
                'reportIncludePrevCategoryAnalysis',
                '전월동기대비 카테고리별 분석결과 포함',
              ),
            ),
            value: includePrevCategoryAnalysis,
            onChanged: (bool? v) => onPrevCategoryAnalysisChanged(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}
