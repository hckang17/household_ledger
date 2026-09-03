import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';
import 'package:household_ledger/router/app_router.dart';

/// 저장된 여행 메타데이터를 조회하고 관리하는 화면이다.
class TravelManagementPage extends ConsumerWidget {
  const TravelManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);
    final travelAsync = ref.watch(travelProvider);
    return BootstrapPage(
      title: strings['travelManagementTitle'] ?? '여행정보 관리',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).pushNamed<String>(AppRouter.travelEditorRoute),
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
            itemCount: travelState.trips.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              final trip = travelState.trips[index];
              return _TripCard(
                trip: trip,
                isActive: trip.id == travelState.activeTripId,
                strings: strings,
                onEdit: () => Navigator.of(context).pushNamed<String>(
                  AppRouter.travelEditorRoute,
                  arguments: trip,
                ),
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

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.isActive,
    required this.strings,
    required this.onEdit,
    required this.onArchiveChanged,
  });

  final Trip trip;
  final bool isActive;
  final Map<String, String> strings;
  final VoidCallback onEdit;
  final ValueChanged<bool> onArchiveChanged;

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            backgroundColor: trip.isArchived
                ? Colors.grey.shade200
                : const Color(0xFFE7F1FF),
            child: Icon(
              Icons.flight_takeoff_rounded,
              color: trip.isArchived ? Colors.grey : const Color(0xFF0D6EFD),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        trip.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isActive)
                      Chip(
                        label: Text(strings['travelActiveLabel'] ?? '사용 중'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                Text(
                  '${_dateText(trip.startDate)} - ${_dateText(trip.endDate)}',
                ),
                if (trip.budget != null)
                  Text(
                    '${strings['travelBudgetLabel'] ?? '여행 예산'}: ${trip.budget}',
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(strings['edit'] ?? '수정'),
                    ),
                    TextButton.icon(
                      onPressed: () => onArchiveChanged(!trip.isArchived),
                      icon: Icon(
                        trip.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        size: 18,
                      ),
                      label: Text(
                        trip.isArchived
                            ? (strings['travelRestoreButton'] ?? '복원')
                            : (strings['travelArchiveButton'] ?? '보관'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _dateText(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
