// """ MVVM 계층: View / generating_report_page """
// """ 역할: PDF 리포트 대상 월과 기간 선택 UI 제공 """

import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/widgets/common/month_selector_dialog.dart';
import 'package:intl/intl.dart';

/// PDF 리포트 기간 설정 카드다.
///
/// 월간·기간 모드 전환과 날짜 선택 UI를 포함한다.
/// 다이얼로그 결과는 [onMonthChanged] / [onRangeChanged] 콜백으로 전달한다.
class ReportPeriodSelector extends StatelessWidget {
  const ReportPeriodSelector({
    required this.isRangeMode,
    required this.selectedMonth,
    required this.selectedRange,
    required this.strings,
    required this.onModeChanged,
    required this.onMonthChanged,
    required this.onRangeChanged,
    super.key,
  });

  final bool isRangeMode;
  final DateTime selectedMonth;
  final DateTimeRange? selectedRange;
  final Map<String, String> strings;

  /// 모드 변경 콜백. true = 기간 모드, false = 월간 모드.
  final ValueChanged<bool> onModeChanged;

  /// 월 선택 다이얼로그에서 달이 확정됐을 때 호출된다.
  final ValueChanged<DateTime> onMonthChanged;

  /// 날짜 범위 피커에서 범위가 확정됐을 때 호출된다.
  final ValueChanged<DateTimeRange> onRangeChanged;

  String _text(String key, [String fallback = '']) => strings[key] ?? fallback;

  Future<void> _pickMonth(BuildContext context) async {
    final DateTime? picked = await showMonthSelectorDialog(
      context: context,
      initialMonth: selectedMonth,
      strings: strings,
    );
    if (picked != null) onMonthChanged(picked);
  }

  Future<void> _pickRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: selectedRange,
    );
    if (picked != null) onRangeChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _text('reportPeriodLabel', '기간 설정 (필수)'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              expandedInsets: EdgeInsets.zero,
              selected: <bool>{isRangeMode},
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(_text('analysisPeriodMonthly', '월간')),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(_text('analysisPeriodRange', '기간')),
                ),
              ],
              onSelectionChanged: (Set<bool> val) => onModeChanged(val.first),
            ),
          ),
          const SizedBox(height: 12),
          if (!isRangeMode)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickMonth(context),
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(DateFormat('yyyy.MM').format(selectedMonth)),
              ),
            ),
          if (isRangeMode)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickRange(context),
                icon: const Icon(Icons.date_range_rounded),
                label: Text(
                  selectedRange != null
                      ? '${DateFormat('yyyy-MM-dd').format(selectedRange!.start)} ~ ${DateFormat('yyyy-MM-dd').format(selectedRange!.end)}'
                      : _text('exportRangeStartDateLabel', '기간을 선택해주세요'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
