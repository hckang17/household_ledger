// """ MVVM 계층: View / Main Feature Page """
// """ 역할: 여행 정보와 연결 지출·요약을 한 화면에서 구성 """

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/widgets/common/expense_editor_sheet.dart';
import 'package:household_ledger/presenter/widgets/common/ledger_dialogs.dart';
import 'package:household_ledger/presenter/widgets/common/travel_editor_sheet.dart';
import 'package:household_ledger/presenter/widgets/travel_detail_page/travel_expense_list.dart';
import 'package:household_ledger/presenter/widgets/travel_detail_page/travel_summary_cards.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';
import 'package:household_ledger/provider/travel_summary_provider.dart';
import 'package:household_ledger/router/app_router.dart';

enum _TravelDetailAction { edit, toggleMode, toggleArchive }

/// 선택한 여행의 정보, 지출 목록, 핵심 요약을 표시한다.
class TravelDetailPage extends ConsumerWidget {
  const TravelDetailPage({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);
    final ledgerAsync = ref.watch(ledgerProvider);
    final travelAsync = ref.watch(travelProvider);
    final expensesAsync = ref.watch(travelExpensesProvider(tripId));
    final summaryAsync = ref.watch(travelSummaryProvider(tripId));

    final trip = travelAsync.asData?.value.trips
        .where((Trip trip) => trip.id == tripId)
        .firstOrNull;
    final ledger = ledgerAsync.asData?.value;

    if (trip == null || ledger == null) {
      final isLoading = travelAsync.isLoading || ledgerAsync.isLoading;
      return BootstrapPage(
        title: strings['travelDetailTitle'] ?? '여행 상세',
        showSideBar: false,
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : Text(strings['travelNotFoundMessage'] ?? '여행 정보를 찾을 수 없습니다.'),
        ),
      );
    }

    final categoryTags = ledger.tagsByType(MetadataTagType.category);
    final subcategoryTags = ledger.tagsByType(MetadataTagType.subcategory);
    final diningTags = ledger.tagsByType(MetadataTagType.diningOccasion);
    final paymentTags = ledger.tagsByType(MetadataTagType.paymentMethod);
    final currency = ledger.settings.currencyUnit;

    Future<void> editExpense(ExpenseEntry entry) =>
        showExpenseEditorSheet(context: context, ref: ref, entry: entry);

    Future<void> deleteExpense(ExpenseEntry entry) async {
      final confirmed = await showLedgerConfirmDialog(
        context: context,
        title: strings['confirmDelete'] ?? '삭제 확인',
        message:
            '${entry.description} : ${entry.amount.toCurrency()}$currency\n${strings['confirmDeleteQuestion'] ?? '삭제하시겠습니까?'}',
        confirmLabel: strings['delete'] ?? '삭제',
        cancelLabel: strings['cancel'] ?? '취소',
      );
      if (!confirmed) return;
      await ref.read(ledgerProvider.notifier).deleteExpense(entry.id);
      ref.invalidate(monthlyExpensesProvider);
      ref.invalidate(rangeExpensesProvider);
      ref.invalidate(travelExpensesProvider(tripId));
      ref.invalidate(travelExpenseTotalsProvider);
    }

    void showDetail(ExpenseEntry entry) {
      showExpenseDetailDialog(
        context: context,
        entry: entry,
        categoryTags: categoryTags,
        subcategoryTags: subcategoryTags,
        diningOccasionTags: diningTags,
        paymentTags: paymentTags,
        strings: strings,
        currency: currency,
      );
    }

    return BootstrapPage(
      title: trip.name,
      showSideBar: false,
      actions: <Widget>[
        PopupMenuButton<_TravelDetailAction>(
          tooltip: strings['moreActionsLabel'] ?? '더보기',
          onSelected: (_TravelDetailAction action) async {
            switch (action) {
              case _TravelDetailAction.edit:
                await showTravelEditorSheet(context: context, trip: trip);
              case _TravelDetailAction.toggleMode:
                if (trip.id == travelAsync.asData?.value.activeTripId) {
                  await ref.read(travelProvider.notifier).turnOffTravelMode();
                } else {
                  await ref
                      .read(travelProvider.notifier)
                      .selectActiveTrip(trip.id);
                }
              case _TravelDetailAction.toggleArchive:
                await ref
                    .read(travelProvider.notifier)
                    .setArchived(trip, !trip.isArchived);
            }
          },
          itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<_TravelDetailAction>>[
                PopupMenuItem<_TravelDetailAction>(
                  value: _TravelDetailAction.edit,
                  child: ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(strings['edit'] ?? '수정'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (!trip.isArchived)
                  PopupMenuItem<_TravelDetailAction>(
                    value: _TravelDetailAction.toggleMode,
                    child: ListTile(
                      leading: Icon(
                        trip.id == travelAsync.asData?.value.activeTripId
                            ? Icons.travel_explore_outlined
                            : Icons.flight_takeoff_rounded,
                      ),
                      title: Text(
                        trip.id == travelAsync.asData?.value.activeTripId
                            ? (strings['travelTurnOffModeButton'] ?? '여행 모드 끄기')
                            : (strings['travelUseModeButton'] ?? '여행 모드로 사용'),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem<_TravelDetailAction>(
                  value: _TravelDetailAction.toggleArchive,
                  child: ListTile(
                    leading: Icon(
                      trip.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    title: Text(
                      trip.isArchived
                          ? (strings['travelRestoreButton'] ?? '복원')
                          : (strings['travelArchiveButton'] ?? '보관'),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseEditorSheet(
          context: context,
          ref: ref,
          initialTripId: trip.id,
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(strings['travelExpenseAddButton'] ?? '여행 지출 추가'),
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(travelExpensesProvider(tripId));
          ref.invalidate(travelExpenseTotalsProvider);
          await ref.read(travelSummaryProvider(tripId).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: <Widget>[
            _TripHeader(trip: trip, strings: strings),
            const SizedBox(height: 12),
            summaryAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Center(
                child: Text(
                  strings['travelSummaryLoadError'] ?? '여행 요약을 불러오지 못했습니다.',
                ),
              ),
              data: (summary) => summary == null
                  ? const SizedBox.shrink()
                  : TravelSummaryCards(
                      summary: summary,
                      strings: strings,
                      currency: currency,
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).pushNamed(AppRouter.analysisRoute, arguments: trip.id),
              icon: const Icon(Icons.insights_outlined),
              label: Text(strings['travelOpenAnalysisButton'] ?? '자세히 분석'),
            ),
            const SizedBox(height: 10),
            Text(
              strings['travelExpenseListTitle'] ?? '여행 지출 내역',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            expensesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    strings['travelExpenseLoadError'] ?? '여행 지출을 불러오지 못했습니다.',
                  ),
                ),
              ),
              data: (expenses) => TravelExpenseList(
                trip: trip,
                expenses: expenses,
                categoryTags: categoryTags,
                currency: currency,
                strings: strings,
                onTap: showDetail,
                onEdit: editExpense,
                onDelete: deleteExpense,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip, required this.strings});

  final Trip trip;
  final Map<String, String> strings;

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.flight_takeoff_rounded,
                color: Color(0xFF0D6EFD),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_dateText(trip.startDate)} - ${_dateText(trip.endDate)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trip.isArchived)
                Chip(
                  label: Text(strings['travelArchivedLabel'] ?? '보관됨'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (trip.note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(trip.note),
          ],
        ],
      ),
    );
  }
}

String _dateText(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
