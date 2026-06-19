import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';

/// 앱 시작 시 보여줄 온보딩 화면이다.
class OnboardingPage extends ConsumerWidget {
  /// 온보딩 화면을 생성한다.
  const OnboardingPage({super.key});

  /// 초기화 여부에 따라 다음 화면으로 이동한다.
  void _openNextPage(BuildContext context, bool initialized) {
    Navigator.of(context).pushReplacementNamed(
      initialized ? AppRouter.homeRoute : AppRouter.setupRoute,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerState = ref.watch(ledgerProvider);
    final strings = ref.watch(localizedStringsProvider);

    // ledger데이터를 모두 읽어온 경우에만 온보딩 화면을 보여준다. 초기 설정이 완료된 경우에는 바로 홈으로 이동한다.
    return ledgerState.when(
      data: (state) {
        return BootstrapPage(
          /// 타이틀에 좌측 여백을 추가하여 앱 아이콘과의 간격을 확보한다.
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
                          _openNextPage(context, state.isInitialized),
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
