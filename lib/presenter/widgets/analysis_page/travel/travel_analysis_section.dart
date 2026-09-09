import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/features/travel/models/travel_summary.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/travel/travel_breakdown_card.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/travel/travel_daily_chart.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/widgets/common/expense_editor_sheet.dart';
import 'package:household_ledger/presenter/widgets/common/travel_editor_sheet.dart';
import 'package:household_ledger/provider/travel_provider.dart';
import 'package:household_ledger/provider/travel_summary_provider.dart';
import 'package:household_ledger/router/app_router.dart';

/// 여행 선택과 여행 전용 지출 분석 위젯을 구성한다.
class TravelAnalysisSection extends ConsumerStatefulWidget {
  const TravelAnalysisSection({
    required this.categoryTags,
    required this.paymentTags,
    required this.currency,
    required this.strings,
    super.key,
    this.initialTripId,
  });

  final List<MetadataTag> categoryTags;
  final List<MetadataTag> paymentTags;
  final String currency;
  final Map<String, String> strings;
  final String? initialTripId;

  @override
  ConsumerState<TravelAnalysisSection> createState() =>
      _TravelAnalysisSectionState();
}

class _TravelAnalysisSectionState extends ConsumerState<TravelAnalysisSection> {
  String? _selectedTripId;

  @override
  void initState() {
    super.initState();
    _selectedTripId = widget.initialTripId;
  }

  @override
  void didUpdateWidget(covariant TravelAnalysisSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTripId != widget.initialTripId &&
        widget.initialTripId != null) {
      _selectedTripId = widget.initialTripId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final travelAsync = ref.watch(travelProvider);
    return travelAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Center(
        child: Text(widget.strings['travelLoadError'] ?? '여행 정보를 불러오지 못했습니다.'),
      ),
      data: (TravelState state) {
        if (state.trips.isEmpty) return _buildEmptyState(context);

        final selectedId = _effectiveTripId(state);
        final trip = state.trips.firstWhere(
          (Trip trip) => trip.id == selectedId,
        );
        final summaryAsync = ref.watch(travelSummaryProvider(selectedId));

        return Column(
          children: <Widget>[
            _TripSelectorCard(
              trips: state.trips,
              selectedTripId: selectedId,
              strings: widget.strings,
              onChanged: (String value) {
                setState(() => _selectedTripId = value);
              },
              onOpenDetail: () => Navigator.of(
                context,
              ).pushNamed(AppRouter.travelDetailRoute, arguments: selectedId),
            ),
            const SizedBox(height: 14),
            summaryAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Center(
                child: Text(
                  widget.strings['travelSummaryLoadError'] ??
                      '여행 요약을 불러오지 못했습니다.',
                ),
              ),
              data: (TravelSummary? summary) {
                if (summary == null) return const SizedBox.shrink();
                return _buildAnalysis(context, trip, summary);
              },
            ),
          ],
        );
      },
    );
  }

  String _effectiveTripId(TravelState state) {
    if (state.trips.any((Trip trip) => trip.id == _selectedTripId)) {
      return _selectedTripId!;
    }
    if (state.trips.any((Trip trip) => trip.id == state.activeTripId)) {
      return state.activeTripId!;
    }
    return state.trips.first.id;
  }

  Widget _buildEmptyState(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.luggage_outlined,
            size: 44,
            color: Color(0xFF6C757D),
          ),
          const SizedBox(height: 12),
          Text(
            widget.strings['travelAnalysisEmptyMessage'] ??
                '분석할 여행이 없습니다. 먼저 여행을 만들어주세요.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(AppRouter.travelManagementRoute),
            icon: const Icon(Icons.add_rounded),
            label: Text(widget.strings['travelAddButton'] ?? '여행 추가'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysis(
    BuildContext context,
    Trip trip,
    TravelSummary summary,
  ) {
    return Column(
      children: <Widget>[
        _TravelAnalysisOverview(
          summary: summary,
          strings: widget.strings,
          currency: widget.currency,
          onEditBudget: () =>
              showTravelEditorSheet(context: context, trip: trip),
        ),
        if (summary.expenseCount == 0) ...<Widget>[
          const SizedBox(height: 12),
          BootstrapSectionCard(
            child: Column(
              children: <Widget>[
                Text(
                  widget.strings['travelExpenseEmptyMessage'] ??
                      '이 여행에 연결된 지출이 없습니다.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => showExpenseEditorSheet(
                    context: context,
                    ref: ref,
                    initialTripId: trip.id,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    widget.strings['travelExpenseAddButton'] ?? '여행 지출 추가',
                  ),
                ),
              ],
            ),
          ),
        ] else ...<Widget>[
          const SizedBox(height: 12),
          TravelBreakdownCard(
            title: widget.strings['travelCategoryBreakdownTitle'] ?? '카테고리별 지출',
            items: summary.categoryBreakdown,
            tags: widget.categoryTags,
            currency: widget.currency,
          ),
          const SizedBox(height: 12),
          TravelDailyChart(
            items: summary.dailyAmounts,
            currency: widget.currency,
            strings: widget.strings,
          ),
          const SizedBox(height: 12),
          _TravelTimingCard(
            summary: summary,
            strings: widget.strings,
            currency: widget.currency,
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text(
              widget.strings['travelPaymentBreakdownTitle'] ?? '결제수단별 지출',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            children: <Widget>[
              TravelBreakdownCard(
                title:
                    widget.strings['travelPaymentBreakdownTitle'] ?? '결제수단별 지출',
                items: summary.paymentMethodBreakdown,
                tags: widget.paymentTags,
                currency: widget.currency,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TripSelectorCard extends StatelessWidget {
  const _TripSelectorCard({
    required this.trips,
    required this.selectedTripId,
    required this.strings,
    required this.onChanged,
    required this.onOpenDetail,
  });

  final List<Trip> trips;
  final String selectedTripId;
  final Map<String, String> strings;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings['travelAnalysisSelectLabel'] ?? '분석할 여행',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedTripId,
            isExpanded: true,
            items: trips
                .map(
                  (Trip trip) => DropdownMenuItem<String>(
                    value: trip.id,
                    child: Text(
                      '${trip.name} · ${_shortDate(trip.startDate)}~${_shortDate(trip.endDate)}${trip.isArchived ? ' (${strings['travelArchivedLabel'] ?? '보관됨'})' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              if (value != null) onChanged(value);
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onOpenDetail,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(strings['travelOpenDetailButton'] ?? '여행 상세 보기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelAnalysisOverview extends StatelessWidget {
  const _TravelAnalysisOverview({
    required this.summary,
    required this.strings,
    required this.currency,
    required this.onEditBudget,
  });

  final TravelSummary summary;
  final Map<String, String> strings;
  final String currency;
  final VoidCallback onEditBudget;

  String _money(int amount) => '${amount.toCurrency()}$currency';

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings['travelBudgetAnalysisTitle'] ?? '예산과 핵심 지표',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Text(
            _money(summary.totalExpense),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFFDC3545),
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(strings['travelTotalExpenseLabel'] ?? '총 여행 지출'),
          const SizedBox(height: 14),
          if (summary.budget == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onEditBudget,
                icon: const Icon(Icons.add_card_outlined),
                label: Text(strings['travelSetBudgetButton'] ?? '여행 예산 설정'),
              ),
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${strings['travelBudgetLabel'] ?? '여행 예산'} ${_money(summary.budget!)}',
                  ),
                ),
                Text(
                  '${summary.budgetUsagePercent!.toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(
              minHeight: 9,
              value: (summary.budgetUsagePercent! / 100).clamp(0.0, 1.0),
              color: summary.budgetUsagePercent! > 100
                  ? const Color(0xFFDC3545)
                  : const Color(0xFF198754),
              backgroundColor: const Color(0xFFE9ECEF),
            ),
            const SizedBox(height: 7),
            Text(
              summary.remainingBudget! < 0
                  ? '${strings['travelOverBudgetLabel'] ?? '예산 초과'} ${_money(-summary.remainingBudget!)}'
                  : '${strings['travelRemainingBudgetLabel'] ?? '남은 예산'} ${_money(summary.remainingBudget!)}',
              style: TextStyle(
                color: summary.remainingBudget! < 0
                    ? const Color(0xFFDC3545)
                    : const Color(0xFF198754),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const Divider(height: 28),
          Wrap(
            spacing: 20,
            runSpacing: 14,
            children: <Widget>[
              _OverviewMetric(
                label: strings['travelDailyAverageLabel'] ?? '하루 평균',
                value: _money(summary.averagePerTripDay),
              ),
              _OverviewMetric(
                label: strings['travelExpenseCountLabel'] ?? '지출 건수',
                value:
                    '${summary.expenseCount}${strings['travelExpenseCountUnit'] ?? '건'}',
              ),
              _OverviewMetric(
                label: strings['travelTransportExpenseLabel'] ?? '교통비',
                value: _money(summary.transportExpense),
              ),
              _OverviewMetric(
                label: strings['travelAccommodationExpenseLabel'] ?? '숙박비',
                value: _money(summary.accommodationExpense),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            strings['travelDailyAverageDescription'] ??
                '하루 평균에는 여행 전후 결제도 포함됩니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 135,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TravelTimingCard extends StatelessWidget {
  const _TravelTimingCard({
    required this.summary,
    required this.strings,
    required this.currency,
  });

  final TravelSummary summary;
  final Map<String, String> strings;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final values = <MapEntry<String, int>>[
      MapEntry(
        strings['travelBeforeLabel'] ?? '여행 전',
        summary.beforeTripExpense,
      ),
      MapEntry(
        strings['travelDuringLabel'] ?? '여행 중',
        summary.duringTripExpense,
      ),
      MapEntry(strings['travelAfterLabel'] ?? '여행 후', summary.afterTripExpense),
    ];
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings['travelTimingAnalysisTitle'] ?? '결제 시점별 지출',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          for (final value in values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(value.key)),
                  Text(
                    '${value.value.toCurrency()}$currency',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _shortDate(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
