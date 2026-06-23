import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_chart_helpers.dart';
import 'package:household_ledger/presenter/common/widgets/analysis_daily_chart.dart';
import 'package:intl/intl.dart';

/// 분석 화면의 수입 탭 콘텐츠다.
///
/// 수입 합계 요약·수입 내역 목록·일별 추이 차트를 포함한다.
class AnalysisIncomeTabSection extends StatelessWidget {
  const AnalysisIncomeTabSection({
    required this.incomes,
    required this.strings,
    required this.currency,
    required this.chartRangeStart,
    super.key,
  });

  final List<IncomeEntry> incomes;
  final Map<String, String> strings;
  final String currency;
  final DateTime chartRangeStart;

  String _text(String key, [String fallback = '']) =>
      strings[key] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final int incomeTotal =
        incomes.fold(0, (int s, IncomeEntry e) => s + e.amount);
    final List<FlSpot> spots = buildDailyIncomeSpots(incomes, chartRangeStart);

    return Column(
      children: <Widget>[
        BootstrapSectionCard(
          child: BootstrapSummaryTile(
            label: _text('analysisIncomeTotal', '수입 합계'),
            value: '${incomeTotal.toCurrency()}$currency',
            color: const Color(0xFF198754),
          ),
        ),
        const SizedBox(height: 16),
        if (incomes.isNotEmpty)
          BootstrapSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _text('incomeTotal', '수입 내역'),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...incomes.map(
                  (IncomeEntry item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: <Widget>[
                        Text(
                          DateFormat('MM/dd').format(item.earnedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.description,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${item.amount.toCurrency()}$currency',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF198754),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (incomes.isNotEmpty) const SizedBox(height: 16),
        if (spots.isNotEmpty)
          BootstrapSectionCard(
            child: AnalysisDailyChart(
              spots: spots,
              currency: currency,
              title: _text('analysisIncomeDailyTrendTitle', '일별 수입 추이'),
              rangeStart: chartRangeStart,
            ),
          ),
        if (spots.isNotEmpty) const SizedBox(height: 16),
        if (incomes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                _text('emptyData', '아직 입력된 데이터가 없습니다.'),
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ),
      ],
    );
  }
}
