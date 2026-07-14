// """ MVVM 계층: View / App Flow Page """
// """ 역할: 최초 실행 안내와 초기 설정 진입 흐름 제공 """

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/services/tutorial_service.dart';

/// 앱 시작 시 보여줄 온보딩 화면이다.
class OnboardingPage extends ConsumerWidget {
  /// 온보딩 화면을 생성한다.
  const OnboardingPage({super.key});

  Future<void> _openNextPage(
    BuildContext context,
    WidgetRef ref,
    bool initialized,
  ) async {
    if (initialized) {
      // 초기 설정이 완료된 경우: 튜토리얼 완료 여부를 확인한다.
      final completed = await TutorialService().isTutorialCompleted();
      if (!context.mounted) return;
      if (!completed) {
        // 튜토리얼 미완료 → 홈으로 가되 튜토리얼 홈 단계 시작
        ref.read(tutorialProvider.notifier).setPhase(TutorialPhase.home);
      }
      Navigator.of(context).pushReplacementNamed(AppRouter.loadingRoute);
    } else {
      // 초기 설정 미완료 → 설정 화면으로 이동하면서 튜토리얼 시작
      ref.read(tutorialProvider.notifier).startTutorial();
      Navigator.of(context).pushReplacementNamed(AppRouter.setupRoute);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerState = ref.watch(ledgerProvider);
    final strings = ref.watch(localizedStringsProvider);

    return ledgerState.when(
      data: (state) {
        return BootstrapPage(
          title: "    ${strings['appTitle'] ?? ''}",
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: BootstrapSectionCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings['onboardingTitle'] ?? '',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF102A43),
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings['onboardingSubtitle'] ?? '',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF486581),
                      ),
                    ),
                    const SizedBox(height: 32),
                    BootstrapActionButton(
                      label: state.isInitialized
                          ? (strings['continueApp'] ?? '')
                          : (strings['startSetup'] ?? ''),
                      icon: Icons.play_circle_fill_rounded,
                      onPressed: () =>
                          _openNextPage(context, ref, state.isInitialized),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      error: (Object error, StackTrace stackTrace) =>
          Scaffold(body: Center(child: Text(error.toString()))),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}
