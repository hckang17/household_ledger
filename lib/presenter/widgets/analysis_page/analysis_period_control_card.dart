// """ MVVM 계층: View / analysis_page """
// """ 역할: 월별·기간별 분석 범위 선택 UI를 제공 """

import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/widgets/common/month_selector_dialog.dart';
import 'package:intl/intl.dart';

/// 분석 화면 최상단의 탭·기간 컨트롤 카드다.
///
/// 지출/수입 탭 전환, 월간/기간 모드 전환, 월 내비게이션/기간 선택을 포함한다.
/// 다이얼로그와 팝업 메뉴는 위젯 내부에서 처리하고 결과를 콜백으로 전달한다.
class AnalysisPeriodControlCard extends StatelessWidget {
  const AnalysisPeriodControlCard({
    required this.showExpense,
    required this.isRangeMode,
    required this.selectedMonth,
    required this.selectedRange,
    required this.periodSubtitle,
    required this.localeCode,
    required this.strings,
    required this.onTabChanged,
    required this.onMonthPrev,
    required this.onMonthNext,
    required this.onMonthChanged,
    required this.onRangeChanged,
    required this.onModeChanged,
    super.key,
  });

  final bool showExpense;
  final bool isRangeMode;
  final DateTime selectedMonth;
  final DateTimeRange? selectedRange;
  final String periodSubtitle;
  final String localeCode;
  final Map<String, String> strings;

  /// 지출(true) / 수입(false) 탭 전환.
  final ValueChanged<bool> onTabChanged;

  /// 이전 달 버튼.
  final VoidCallback onMonthPrev;

  /// 다음 달 버튼.
  final VoidCallback onMonthNext;

  /// 월 선택 다이얼로그에서 달이 선택됐을 때 호출된다.
  final ValueChanged<DateTime> onMonthChanged;

  /// 기간 선택 피커에서 결과가 확정됐을 때 호출된다. null이면 기간 초기화.
  final ValueChanged<DateTimeRange?> onRangeChanged;

  /// 기간 모드(true=기간, false=월간)가 변경됐을 때 호출된다.
  final ValueChanged<bool> onModeChanged;

  // ─── 내부 헬퍼 ───────────────────────────────────────────────────

  String _text(String key, [String fallback = '']) => strings[key] ?? fallback;

  String _intlLocale() => localeCode == 'jp' ? 'ja' : 'ko';

  int _lastDayOfMonth() =>
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;

  String _monthRangeLabel() {
    final String mm = selectedMonth.month.toString().padLeft(2, '0');
    final String dd = _lastDayOfMonth().toString().padLeft(2, '0');
    return '$mm.01 - $mm.$dd';
  }

  String _formatRange(DateTimeRange range) {
    final DateFormat fmt = DateFormat('MM.dd', _intlLocale());
    return '${fmt.format(range.start)} - ${fmt.format(range.end)}';
  }

  // ─── 다이얼로그 / 메뉴 ───────────────────────────────────────────

  Future<void> _showModeMenu(BuildContext btnCtx) async {
    final RenderBox button = btnCtx.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Navigator.of(btnCtx).overlay!.context.findRenderObject()! as RenderBox;
    final Offset offset = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );
    final RelativeRect position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy,
      overlay.size.width - offset.dx - button.size.width,
      0,
    );

    final String? selected = await showMenu<String>(
      context: btnCtx,
      position: position,
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'monthly',
          child: Text(_text('analysisPeriodMonthly', '월간')),
        ),
        PopupMenuItem<String>(
          value: 'range',
          child: Text(_text('analysisPeriodRange', '기간')),
        ),
      ],
    );
    if (selected != null) onModeChanged(selected == 'range');
  }

  Future<void> _pickMonth(BuildContext context) async {
    final DateTime? picked = await showMonthSelectorDialog(
      context: context,
      initialMonth: selectedMonth,
      strings: strings,
    );
    if (picked != null) onMonthChanged(DateTime(picked.year, picked.month));
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      locale: Locale(_intlLocale()),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: selectedRange,
      helpText: _text('selectDateRange', '기간 선택'),
      cancelText: _text('cancel', '취소'),
      saveText: _text('apply', '적용'),
    );
    if (picked != null) {
      onRangeChanged(
        DateTimeRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        ),
      );
    }
  }

  // ─── UI 빌더 ─────────────────────────────────────────────────────

  Widget _buildPeriodHeader(BuildContext context) {
    final String modeLabel = isRangeMode
        ? _text('analysisPeriodRange', '기간')
        : _text('analysisPeriodMonthly', '월간');

    return Row(
      children: <Widget>[
        Builder(
          builder: (BuildContext btnCtx) => GestureDetector(
            onTap: () => _showModeMenu(btnCtx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    modeLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isRangeMode
              ? _buildRangeNavRow(context)
              : _buildMonthNavRow(context),
        ),
      ],
    );
  }

  Widget _buildMonthNavRow(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      IconButton(
        onPressed: onMonthPrev,
        icon: const Icon(Icons.chevron_left),
        visualDensity: VisualDensity.compact,
        splashRadius: 20,
      ),
      GestureDetector(
        onTap: () => _pickMonth(context),
        child: Text(
          _monthRangeLabel(),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      IconButton(
        onPressed: onMonthNext,
        icon: const Icon(Icons.chevron_right),
        visualDensity: VisualDensity.compact,
        splashRadius: 20,
      ),
    ],
  );

  Widget _buildRangeNavRow(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => _pickDateRange(context),
          icon: const Icon(Icons.date_range_outlined, size: 16),
          label: Text(
            selectedRange == null
                ? _text('selectDateRange', '기간 선택')
                : _formatRange(selectedRange!),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
      if (selectedRange != null) ...<Widget>[
        const SizedBox(width: 6),
        IconButton(
          onPressed: () => onRangeChanged(null),
          icon: const Icon(Icons.close, size: 18),
          visualDensity: VisualDensity.compact,
          tooltip: _text('clearSelection', '선택 초기화'),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              expandedInsets: EdgeInsets.zero,
              selected: <bool>{showExpense},
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: true,
                  label: Text(_text('analysisTabExpense', '지출')),
                  icon: const Icon(Icons.trending_down_rounded),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text(_text('analysisTabIncome', '수입')),
                  icon: const Icon(Icons.trending_up_rounded),
                ),
              ],
              onSelectionChanged: (Set<bool> val) => onTabChanged(val.first),
            ),
          ),
          const SizedBox(height: 14),
          _buildPeriodHeader(context),
          const SizedBox(height: 4),
          Text(
            periodSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
