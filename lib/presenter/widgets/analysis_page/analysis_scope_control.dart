import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';

/// 기간별 분석과 여행별 분석의 상위 범위를 전환한다.
class AnalysisScopeControl extends StatelessWidget {
  const AnalysisScopeControl({
    required this.isTravel,
    required this.strings,
    required this.onChanged,
    super.key,
  });

  final bool isTravel;
  final Map<String, String> strings;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      padding: const EdgeInsets.all(10),
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: <ButtonSegment<bool>>[
          ButtonSegment<bool>(
            value: false,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(strings['analysisPeriodScope'] ?? '기간별 분석'),
          ),
          ButtonSegment<bool>(
            value: true,
            icon: const Icon(Icons.flight_takeoff_outlined),
            label: Text(strings['analysisTravelScope'] ?? '여행별 분석'),
          ),
        ],
        selected: <bool>{isTravel},
        onSelectionChanged: (Set<bool> values) => onChanged(values.first),
      ),
    );
  }
}
