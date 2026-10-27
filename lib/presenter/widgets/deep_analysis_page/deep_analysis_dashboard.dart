import 'package:household_ledger/model/metadata_tag.dart';
import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/widgets/common/typewriter_text.dart';
import 'package:household_ledger/presenter/widgets/common/entrance_reveal.dart';
import 'package:household_ledger/features/analysis/models/deep_analysis_report.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/deep_analysis_page/deep_analysis_visuals.dart';

/// 가공된 결과와 언어팩을 표시한다. 기간 선택은 원본 데이터 조회를 하지 않는다.
class DeepAnalysisDashboard extends StatefulWidget {
  const DeepAnalysisDashboard({
    required this.report,
    required this.strings,
    this.categoryLabels = const {},
    super.key,
  });
  final DeepAnalysisReport report;
  final Map<String, String> strings;
  final Map<String, String> categoryLabels;
  @override
  State<DeepAnalysisDashboard> createState() => _DeepAnalysisDashboardState();
}

class _DeepAnalysisDashboardState extends State<DeepAnalysisDashboard> {
  int _months = 3;
  String t(String key) => widget.strings[key] ?? '';
  String money(int value) => '${value.toCurrency()} ${t('currencyUnit')}';
  String period(int n) => t('deepMonths').replaceAll('{months}', '$n');
  String label(DeepAnalysisItem item) {
    final code = item.categoryCode;
    if (code == '__fixed__') return t('deepFixed');
    if (code != null) {
      final key =
          systemMetadataTagLocalizationKeys[MetadataTagType.category]?[code];
      return key == null ? (widget.categoryLabels[code] ?? code) : t(key);
    }
    return item.labelKey == null ? item.label : t(item.labelKey!);
  }

  String signed(int n) =>
      '${n > 0
          ? '+'
          : n < 0
          ? '-'
          : ''}${money(n.abs())}';

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    if (report.trend.isEmpty || report.baselines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t('deepEmpty')),
        ),
      );
    }
    final baseline = report.baselines.firstWhere(
      (b) => b.months == _months && b.average != null,
      orElse: () => report.baselines.firstWhere(
        (b) => b.average != null,
        orElse: () => report.baselines.first,
      ),
    );
    final available = baseline.average != null;
    final maximumChange = baseline.changes.fold<int>(
      1,
      (v, e) => e.amount.abs() > v ? e.amount.abs() : v,
    );
    final cards = <Widget>[
      DeepCard(
        number: '01',
        title: t('deepChangesTitle'),
        subtitle: t('deepChangesSubtitle'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              available ? signed(baseline.difference) : t('deepInsufficient'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: deepInk,
              ),
            ),
            Text(
              '${period(baseline.months)} · ${t('deepCompared')}',
              style: deepMutedStyle,
            ),
            const SizedBox(height: 20),
            for (final item in baseline.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    DeepLabelValue(
                      label: label(item),
                      value: signed(item.amount),
                      color: item.amount > 0 ? deepCoral : deepTeal,
                    ),
                    const SizedBox(height: 7),
                    DeepDivergingBar(
                      value: item.amount,
                      maximum: maximumChange,
                    ),
                  ],
                ),
              ),
            Text(t('deepChangesNote'), style: deepMutedStyle),
          ],
        ),
      ),
      DeepCard(
        number: '02',
        title: t('deepTrendTitle'),
        subtitle: t('deepTrendSubtitle'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DeepLabelValue(
              label: period(baseline.months),
              value: available ? money(baseline.average!) : '—',
            ),
            const SizedBox(height: 20),
            DeepTrendChart(
              points: report.trend,
              average: baseline.average,
              money: money,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                DeepLegend(color: deepTeal, text: t('deepMonthlyTotal')),
                DeepLegend(color: deepCoral, text: t('deepAverageLine')),
              ],
            ),
            const SizedBox(height: 12),
            Text(t('deepAverageNote'), style: deepMutedStyle),
          ],
        ),
      ),
      DeepCard(
        number: '03',
        title: t('deepLargeTitle'),
        subtitle: t('deepLargeSubtitle'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report.topShare.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: deepInk,
              ),
            ),
            Text(t('deepTopShare'), style: deepMutedStyle),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (report.topShare / 100).clamp(0, 1),
                minHeight: 10,
                color: deepTeal,
                backgroundColor: deepTrack,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in report.largeExpenses)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    label(item),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    item.date == null
                        ? money(item.amount)
                        : '${item.date!.month}/${item.date!.day} · ${money(item.amount)}',
                  ),
                  trailing: const Icon(Icons.north_east_rounded, size: 18),
                  onTap: () => _showRecord(item),
                ),
              ),
            const Divider(height: 28),
            DeepLabelValue(
              label: t('deepWithoutTop'),
              value: money(report.withoutTop),
            ),
            const SizedBox(height: 12),
            Text(t('deepLargeNote'), style: deepMutedStyle),
          ],
        ),
      ),
      DeepCard(
        number: '04',
        title: t('deepFixedTitle'),
        subtitle: t('deepFixedSubtitle'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              money(report.fixedTotal),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: deepInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'deepFixedShare',
              ).replaceAll('{share}', report.fixedShare.toStringAsFixed(1)),
              style: deepMutedStyle,
            ),
            const SizedBox(height: 20),
            for (final item in report.fixedBreakdown)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  children: [
                    DeepLabelValue(
                      label: label(item),
                      value: money(item.amount),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (item.share / 100).clamp(0, 1),
                        minHeight: 8,
                        color: deepTeal,
                        backgroundColor: deepTrack,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            DeepLabelValue(
              label: '${period(baseline.months)} ${t('deepAverage')}',
              value: available ? money(baseline.fixedAverage) : '—',
            ),
            const SizedBox(height: 12),
            Text(t('deepFixedNote'), style: deepMutedStyle),
          ],
        ),
      ),
    ];
    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];
      cards[i] = EntranceReveal(key: ValueKey('reveal-$i'), child: card);
    }
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (report.isDemo)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      t('deepDemo'),
                      style: const TextStyle(color: Color(0xFF785514)),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: deepInk,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${report.month.year}.${report.month.month.toString().padLeft(2, '0')}  /  ${t('deepMonthlyReview')}',
                        style: const TextStyle(
                          color: Color(0xFFBBDFD8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        t('deepMonthlyTotal'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        money(report.total),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TypewriterText(
                        text: t('deepHeroNote'),
                        animate: true,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  t('deepBaselineTitle'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: deepInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(t('deepBaselineNote'), style: deepMutedStyle),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, box) {
                    final columns = box.maxWidth > 650 ? 4 : 2;
                    final width = (box.maxWidth - (columns - 1) * 10) / columns;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final b in report.baselines)
                          SizedBox(
                            width: width,
                            child: Semantics(
                              selected: b.months == baseline.months,
                              child: OutlinedButton(
                                key: ValueKey('baseline-${b.months}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: deepInk,
                                  padding: const EdgeInsets.all(14),
                                  alignment: Alignment.centerLeft,
                                  backgroundColor: b.months == baseline.months
                                      ? deepTrack
                                      : Colors.white,
                                  side: BorderSide(
                                    color: b.months == baseline.months
                                        ? deepTeal
                                        : const Color(0xFFE0E7E5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: b.average == null
                                    ? null
                                    : () => setState(() => _months = b.months),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(period(b.months)),
                                    const SizedBox(height: 8),
                                    Text(
                                      b.average == null
                                          ? t('deepInsufficient')
                                          : money(b.average!),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  t(report.isDemo ? 'deepHistoryNote' : 'deepObservedHistory'),
                  style: deepMutedStyle,
                ),
                if (report.asOf != null)
                  Text(
                    t('deepPartialNote').replaceAll(
                      '{date}',
                      '${report.asOf!.year}.${report.asOf!.month}.${report.asOf!.day}',
                    ),
                    style: deepMutedStyle,
                  ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, box) {
                    final wide =
                        box.maxWidth >= 850 &&
                        MediaQuery.textScalerOf(context).scale(14) < 22;
                    if (!wide) {
                      return Column(
                        children: [
                          for (final card in cards)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: card,
                            ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              cards[0],
                              const SizedBox(height: 16),
                              cards[2],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              cards[1],
                              const SizedBox(height: 16),
                              cards[3],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecord(DeepAnalysisItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label(item),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  money(item.amount),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (item.date != null)
                  Text(
                    '${item.date!.year}/${item.date!.month}/${item.date!.day}',
                  ),
                const SizedBox(height: 16),
                if (widget.report.isDemo) Text(t('deepDemo')),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('deepClose')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
