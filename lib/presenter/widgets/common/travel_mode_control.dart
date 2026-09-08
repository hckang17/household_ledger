import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';
import 'package:household_ledger/presenter/widgets/common/travel_editor_sheet.dart';

const String _addTripAction = '__add_trip__';

/// 여행 모드를 켤 여행을 선택하는 스크롤 가능한 Bottom Sheet를 표시한다.
Future<void> showTravelSelectionSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final strings = ref.read(localizedStringsProvider);
  final travelState = await ref.read(travelProvider.future);
  if (!context.mounted) return;
  final availableTrips = travelState.trips
      .where((Trip trip) => !trip.isArchived)
      .toList(growable: false);

  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.72,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        strings['travelSelectTitle'] ?? '기록할 여행 선택',
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: availableTrips.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            strings['travelEmptyMessage'] ??
                                '저장된 여행이 없습니다. 새 여행을 추가해주세요.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: availableTrips.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final trip = availableTrips[index];
                          final selected = trip.id == travelState.activeTripId;
                          return ListTile(
                            leading: Icon(
                              Icons.flight_takeoff_rounded,
                              color: selected
                                  ? const Color(0xFF0D6EFD)
                                  : Colors.grey.shade600,
                            ),
                            title: Text(
                              trip.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_dateText(trip.startDate)} - ${_dateText(trip.endDate)}',
                            ),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF0D6EFD),
                                  )
                                : const Icon(Icons.circle_outlined),
                            onTap: () =>
                                Navigator.of(sheetContext).pop(trip.id),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(_addTripAction),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(strings['travelAddButton'] ?? '새 여행 추가'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;
  final String? selectedTripId;
  if (action == _addTripAction) {
    selectedTripId = await showTravelEditorSheet(context: context);
  } else {
    selectedTripId = action;
  }
  if (selectedTripId != null && context.mounted) {
    await ref.read(travelProvider.notifier).selectActiveTrip(selectedTripId);
  }
}

/// 홈과 소비기록 화면에서 공유하는 여행 모드 ON/OFF 컨트롤이다.
class TravelModeControl extends ConsumerWidget {
  const TravelModeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);
    final travelAsync = ref.watch(travelProvider);

    return travelAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, _) => const SizedBox.shrink(),
      data: (TravelState travelState) {
        final activeTrip = travelState.activeTrip;
        final isOn = activeTrip != null;
        return Material(
          color: isOn ? const Color(0xFFE7F1FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showTravelSelectionSheet(context: context, ref: ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.flight_takeoff_rounded,
                    color: isOn ? const Color(0xFF0D6EFD) : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          strings['travelModeTitle'] ?? '여행 모드',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          activeTrip?.name ??
                              (strings['travelModeOffDescription'] ??
                                  '여행을 선택하면 신규 지출에 자동 적용됩니다.'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isOn,
                    onChanged: (bool value) {
                      if (value) {
                        showTravelSelectionSheet(context: context, ref: ref);
                      } else {
                        ref.read(travelProvider.notifier).turnOffTravelMode();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _dateText(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}
