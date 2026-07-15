// """ MVVM 계층: View / App Flow Page """
// """ 역할: 사용자 프로필과 초기 예산을 설정하는 최초 구성 화면 """

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/controllers/tutorial_showcase_controller.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/services/mock_data_service.dart';
import 'package:showcaseview/showcaseview.dart';

/// 초기 설정 화면이다.
class SetupPage extends ConsumerStatefulWidget {
  /// 초기 설정 화면을 생성한다.
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _budgetController;
  late final String _localeCode;

  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _ageKey = GlobalKey();
  final GlobalKey _budgetKey = GlobalKey();
  final GlobalKey _importKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();

  final TutorialShowcaseController _showcase = TutorialShowcaseController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _budgetController = TextEditingController();
    final deviceLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _localeCode = deviceLang == 'ja' ? 'jp' : 'ko';
  }

  void _maybeStartShowcase() {
    final phase = ref.read(tutorialProvider).phase;
    _showcase.startIfReady(
      enabled: phase == TutorialPhase.setup,
      keys: <GlobalKey>[_nameKey, _ageKey, _budgetKey, _importKey, _saveKey],
      isMounted: () => mounted,
    );
  }

  Future<void> _submit() async {
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final budget = int.tryParse(_budgetController.text.trim()) ?? 0;
    await ref
        .read(ledgerProvider.notifier)
        .completeSetup(
          name: _nameController.text,
          age: age,
          monthlyBudget: budget,
          localeCode: _localeCode,
        );

    if (!mounted) return;

    final tutorial = ref.read(tutorialProvider);
    if (tutorial.isActive) {
      await ref.read(mockDataServiceProvider).insertMockData(ref);
      ref.read(tutorialProvider.notifier).setPhase(TutorialPhase.home);
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.homeRoute,
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _handleBackDuringTutorial() async {
    _showcase.dismiss();
    final strings = ref.read(localizedStringsProvider);
    final confirmed = await showTutorialExitConfirmation(
      context: context,
      strings: strings,
    );
    if (confirmed && mounted) {
      await ref.read(tutorialProvider.notifier).exitTutorial();
    } else if (mounted) {
      _showcase.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeStartShowcase();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final isTutorial = ref.watch(
      tutorialProvider.select(
        (s) => s.isActive && s.phase == TutorialPhase.setup,
      ),
    );

    Widget buildInner(BuildContext showcaseCtx) {
      _showcase.bind(showcaseCtx);
      _maybeStartShowcase();

      final inner = BootstrapPage(
        title: strings['setupTitle'] ?? '',
        showSideBar: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: BootstrapSectionCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Showcase(
                    key: _nameKey,
                    title: strings['tutSetupNameTitle'] ?? '이름 입력',
                    description:
                        strings['tutSetupNameDesc'] ??
                        '앱에서 사용할 이름을 입력해주세요. 홈 화면 인사말에 표시됩니다.',
                    tooltipPosition: TooltipPosition.bottom,
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: strings['nameLabel'],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Showcase(
                    key: _ageKey,
                    title: strings['tutSetupAgeTitle'] ?? '나이 입력',
                    description:
                        strings['tutSetupAgeDesc'] ?? '현재 나이를 숫자로 입력해주세요.',
                    tooltipPosition: TooltipPosition.bottom,
                    child: TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: strings['ageLabel'],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Showcase(
                    key: _budgetKey,
                    title: strings['tutSetupBudgetTitle'] ?? '월 예산 설정',
                    description:
                        strings['tutSetupBudgetDesc'] ??
                        '이번달 지출 목표 금액을 입력하세요.\n홈 화면의 지출가능금액 계산에 사용됩니다.',
                    tooltipPosition: TooltipPosition.bottom,
                    child: TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: strings['budgetLabel'],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Showcase(
                    key: _saveKey,
                    title: strings['tutSetupSaveTitle'] ?? '설정 저장',
                    description:
                        strings['tutSetupSaveDesc'] ??
                        '입력을 마쳤다면 저장 버튼을 눌러 앱을 시작하세요!',
                    tooltipPosition: TooltipPosition.top,
                    child: BootstrapActionButton(
                      label: strings['save'] ?? '',
                      icon: Icons.save_rounded,
                      onPressed: _submit,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Showcase(
                    key: _importKey,
                    title: strings['tutSetupImportTitle'] ?? '데이터 가져오기',
                    description:
                        strings['tutSetupImportDesc'] ??
                        '이전에 내보낸 CSV 파일이 있다면,\n이 버튼으로 기존 데이터를 복원할 수 있어요.',
                    tooltipPosition: TooltipPosition.top,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pushNamed(
                          AppRouter.importDataRoute,
                          arguments: <String, dynamic>{'fromSetup': true},
                        ),
                        icon: const Icon(Icons.download_outlined),
                        label: Text(strings['importDataMenuLabel'] ?? ''),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (isTutorial) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBackDuringTutorial();
          },
          child: inner,
        );
      }
      return inner;
    }

    return ShowCaseWidget(
      onFinish: () {},
      enableAutoScroll: true,
      builder: buildInner,
    );
  }
}
