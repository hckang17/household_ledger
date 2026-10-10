import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/main_shell_page/bottom_navigation_bar.dart';
import 'package:household_ledger/presenter/widgets/main_shell_page/ledger_banner_ad.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';

/// 현재 탭의 광고와 내비게이션을 본문 밖에 배치해 입력 버튼과 겹치지 않게 한다.
class MainShellBottomBar extends ConsumerWidget {
  const MainShellBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);
    final isTutorial = ref.watch(tutorialProvider.select((s) => s.isActive));
    final showBanner =
        !isTutorial &&
        MediaQuery.viewInsetsOf(context).bottom == 0 &&
        strings.containsKey('adPrivacyOptions');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBanner) LedgerBannerAd(strings: strings),
        const LedgerBottomNavBar(),
      ],
    );
  }
}
