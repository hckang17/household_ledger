import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';
import 'package:household_ledger/presenter/widgets/common/ledger_dialogs.dart';

/// 삭제 확인과 중복 제출 방지를 담당하는 여행 관리 전용 버튼.
class TravelDeleteButton extends ConsumerStatefulWidget {
  const TravelDeleteButton({required this.trip, super.key});

  final Trip trip;

  @override
  ConsumerState<TravelDeleteButton> createState() => _TravelDeleteButtonState();
}

class _TravelDeleteButtonState extends ConsumerState<TravelDeleteButton> {
  bool _busy = false;

  Future<void> _delete() async {
    setState(() => _busy = true);
    final strings = ref.read(localizedStringsProvider);
    try {
      final confirmed = await showLedgerConfirmDialog(
        context: context,
        title: strings['travelDeleteTitle']!,
        message: strings['travelDeleteWarning']!.replaceAll(
          '{name}',
          widget.trip.name,
        ),
        cancelLabel: strings['travelDeleteNo']!,
        confirmLabel: strings['travelDeleteYes']!,
        isDestructive: true,
      );
      if (confirmed != true || !mounted) return;
      await ref.read(travelProvider.notifier).deleteTrip(widget.trip.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings['travelDeleteError']!)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    // 언어팩 로딩 중의 최소 fallback 맵에는 여행 문구가 아직 없다.
    if (!strings.containsKey('travelDeleteTitle')) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: _busy ? null : _delete,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      icon: const Icon(Icons.delete_outline, size: 18),
      label: Text(strings['travelDeleteTitle']!),
    );
  }
}
