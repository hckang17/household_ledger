import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/travel_provider.dart';

/// 홈과 지출 기록 화면에서 여행 모드를 같은 색상·문구로 표시한다.
class ExpenseRecordAction extends ConsumerWidget {
  const ExpenseRecordAction({
    required this.strings,
    required this.onPressed,
    this.floating = false,
    super.key,
  });

  final Map<String, String> strings;
  final VoidCallback onPressed;
  final bool floating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final travelOn = ref.watch(
      travelProvider.select((value) => value.asData?.value.activeTrip != null),
    );
    final label = travelOn
        ? (strings['recordTravelExpense'] ?? '')
        : (strings['quickExpense'] ?? '');
    final background = travelOn
        ? const Color(0xFF16804A)
        : const Color(0xFFFFC107);
    final foreground = travelOn ? Colors.white : const Color(0xFF102A43);
    final icon = travelOn
        ? Icons.luggage_outlined
        : Icons.add_circle_outline_rounded;
    if (floating) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        label: Text(label),
        icon: Icon(icon),
        backgroundColor: background,
        foregroundColor: foreground,
      );
    }
    return BootstrapActionButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      backgroundColor: background,
      foregroundColor: foreground,
    );
  }
}
