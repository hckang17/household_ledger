// """ MVVM 계층: Shared View Style """
// """ 역할: 앱 공통 Bootstrap 스타일 Dialog 구성요소 제공 """

import 'package:flutter/material.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';

class BootstrapDialog extends StatelessWidget {
  const BootstrapDialog({
    required this.title,
    required this.content,
    this.actions,
    super.key,
    this.icon,
    this.iconColor = const Color(0xFF0D6EFD),
  });

  final String title;
  final Widget content;
  final List<Widget>? actions;
  final IconData? icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    // The keyboard can leave less than 100 logical pixels on a landscape phone.
    // Only adapt spacing here; Dialog/SafeArea still own the actual inset handling.
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).vertical -
        MediaQuery.paddingOf(context).vertical;
    final shortViewport = availableHeight < 240;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: shortViewport ? 8 : 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: BootstrapSectionCard(
          padding: shortViewport
              ? const EdgeInsets.symmetric(horizontal: 22, vertical: 8)
              : const EdgeInsets.fromLTRB(22, 22, 22, 18),
          // Dialog already applies viewInsets. Scroll the entire form, including
          // actions, so even a very short keyboard viewport remains operable.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, size: 24, color: iconColor),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFF172B4D),
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF52606D),
                    height: 1.55,
                  ),
                  child: content,
                ),
                if (actions != null) ...<Widget>[
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.end,
                    runAlignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
