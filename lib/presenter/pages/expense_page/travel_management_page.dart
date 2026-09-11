import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/widgets/common/travel_editor_sheet.dart';
import 'package:household_ledger/presenter/widgets/travel_management_page/travel_trip_card.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';
import 'package:household_ledger/provider/travel_summary_provider.dart';
import 'package:household_ledger/router/app_router.dart';

/// 저장된 여행 메타데이터를 조회하고 관리하는 화면이다.
class TravelManagementPage extends ConsumerWidget {
  const TravelManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);
    final travelAsync = ref.watch(travelProvider);
    final totalsAsync = ref.watch(travelExpenseTotalsProvider);
    final currency =
        ref.watch(ledgerProvider).asData?.value.settings.currencyUnit ?? '';
    return BootstrapPage(
      title: strings['travelManagementTitle'] ?? '여행정보 관리',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTravelEditorSheet(context: context),
        icon: const Icon(Icons.add_rounded),
        label: Text(strings['travelAddButton'] ?? '새 여행 추가'),
      ),
      child: travelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(strings['travelLoadError'] ?? '여행정보를 불러오지 못했습니다.'),
        ),
        data: (TravelState travelState) {
          if (travelState.trips.isEmpty) {
            return Center(
              child: Text(
                strings['travelEmptyMessage'] ?? '저장된 여행이 없습니다. 새 여행을 추가해주세요.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: travelState.trips.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (BuildContext context, int index) {
              final trip = travelState.trips[index];
              return TravelTripCard(
                key: ValueKey(trip.id),
                trip: trip,
                isActive: trip.id == travelState.activeTripId,
                totalExpense: totalsAsync.whenData(
                  (totals) => totals[trip.id] ?? 0,
                ),
                onRetry: () => ref.invalidate(travelExpenseTotalsProvider),
                currency: currency,
                strings: strings,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(AppRouter.travelDetailRoute, arguments: trip.id),
                onEdit: () =>
                    showTravelEditorSheet(context: context, trip: trip),
                onArchiveChanged: (bool archived) => ref
                    .read(travelProvider.notifier)
                    .setArchived(trip, archived),
              );
            },
          );
        },
      ),
    );
  }
}
