// """ MVVM 계층: View / Sub Feature Page """
// """ 역할: 사용자 정보·태그·데이터 관리·튜토리얼 설정 제공 """

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/controllers/tutorial_showcase_controller.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/widgets/common/ledger_dialogs.dart';
import 'package:household_ledger/presenter/widgets/settings_page/tag_management_section.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/services/mock_data_service.dart';
import 'package:household_ledger/services/tutorial_service.dart';
import 'package:showcaseview/showcaseview.dart';

/// 환경설정 화면이다.
class SettingsPage extends ConsumerStatefulWidget {
  /// 환경설정 화면을 생성한다.
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

/// 환경설정 화면의 폼 상태를 관리한다.
class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;

  final GlobalKey _tagSectionKey = GlobalKey();
  final GlobalKey _dataManageSectionKey = GlobalKey();
  bool _isMigratingDiningDescriptions = false;
  final TutorialShowcaseController _showcase = TutorialShowcaseController();

  void _maybeStartShowcase() {
    final state = ref.read(tutorialProvider);
    _showcase.startIfReady(
      enabled: state.isActive && state.phase == TutorialPhase.settings,
      keys: <GlobalKey>[_tagSectionKey, _dataManageSectionKey],
      isMounted: () => mounted,
    );
  }

  void _onShowcaseComplete(int? index, GlobalKey key) {
    if (key == _dataManageSectionKey) {
      ref.read(tutorialProvider.notifier).setPhase(TutorialPhase.exportData);
      Navigator.of(context).pushNamed(AppRouter.exportDataRoute);
    }
  }

  Future<void> _handleBackDuringTutorial() async {
    _showcase.dismiss();
    final strings = ref.read(localizedStringsProvider);
    final confirmed = await showTutorialExitConfirmation(
      context: context,
      strings: strings,
    );
    if (confirmed && mounted) {
      await ref.read(mockDataServiceProvider).cleanupMockData(ref);
      await ref.read(tutorialProvider.notifier).exitTutorial();
    } else if (mounted) {
      _showcase.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeStartShowcase();
      });
    }
  }

  String _text(Map<String, String> strings, String tag) {
    return strings[tag] ??
        '${strings['failedReadingData'] ?? 'ErrorCode: 4401'}+$tag';
  }

  String _normalizeCurrencyUnit(String value) {
    if (value == '￥') {
      return '¥';
    }
    if (value == '원') {
      return '₩';
    }
    if (value == '¥' || value == '₩') {
      return value;
    }
    return '₩';
  }

  @override
  void initState() {
    super.initState();
    final ledger = ref.read(ledgerProvider).asData?.value;
    _nameController = TextEditingController(
      text: ledger?.userProfile.name ?? '',
    );
    _ageController = TextEditingController(
      text: (ledger?.userProfile.age ?? 0) > 0
          ? (ledger?.userProfile.age ?? 0).toString()
          : '',
    );
  }

  /// 이름/나이를 저장한다.
  Future<void> _saveProfile(Map<String, String> strings) async {
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    await ref
        .read(ledgerProvider.notifier)
        .updateUserProfile(name: _nameController.text, age: age);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_text(strings, 'settingsSavedMessage'))),
    );
  }

  Future<void> _migrateLegacyDiningDescriptions(
    Map<String, String> strings,
  ) async {
    if (_isMigratingDiningDescriptions) return;
    final notifier = ref.read(ledgerProvider.notifier);
    final count = await notifier.countLegacyDiningDescriptions();
    if (!mounted) return;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(strings, 'diningMigrationNoData'))),
      );
      return;
    }

    final confirmed = await showLedgerConfirmDialog(
      context: context,
      title: _text(strings, 'diningMigrationTitle'),
      message: _text(
        strings,
        'diningMigrationConfirm',
      ).replaceAll('{count}', '$count'),
      confirmLabel: _text(strings, 'diningMigrationAction'),
      cancelLabel: _text(strings, 'cancel'),
    );
    if (!confirmed || !mounted) return;

    setState(() => _isMigratingDiningDescriptions = true);
    final migratedCount = await notifier.migrateLegacyDiningDescriptions();
    ref.invalidate(monthlyExpensesProvider);
    ref.invalidate(rangeExpensesProvider);
    if (!mounted) return;
    setState(() => _isMigratingDiningDescriptions = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _text(
            strings,
            'diningMigrationComplete',
          ).replaceAll('{count}', '$migratedCount'),
        ),
      ),
    );
  }

  void _showCodeDuplicationAlert(Map<String, String> strings) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_text(strings, 'codeDuplicationAlert'))),
    );
  }

  bool _hasDuplicateCode({
    required List<MetadataTag> tags,
    required String code,
    String? ignoreCode,
  }) {
    return tags.any(
      (MetadataTag item) =>
          item.code == code && (ignoreCode == null || item.code != ignoreCode),
    );
  }

  /// 새 태그를 추가한다.
  Future<void> _addTag(MetadataTagType type) async {
    final strings = ref.read(localizedStringsProvider);
    final ledger = ref.read(ledgerProvider).asData?.value;
    if (ledger == null) {
      return;
    }

    final tag = await showTagEditorDialog(
      context: context,
      type: type,
      title: _text(strings, 'addTag'),
      saveLabel: _text(strings, 'save'),
      cancelLabel: _text(strings, 'cancel'),
    );
    if (!mounted) {
      return;
    }

    if (tag == null) {
      return;
    }

    final sameTypeTags = ledger.tagsByType(type);
    if (_hasDuplicateCode(tags: sameTypeTags, code: tag.code)) {
      _showCodeDuplicationAlert(strings);
      return;
    }

    await ref.read(ledgerProvider.notifier).addMetadataTag(tag);
    ref.invalidate(ledgerProvider);
  }

  /// 태그를 수정한다.
  Future<void> _editTag(MetadataTag target) async {
    if (target.isSystemDefault) return;
    final strings = ref.read(localizedStringsProvider);
    final ledger = ref.read(ledgerProvider).asData?.value;
    if (ledger == null) {
      return;
    }

    final edited = await showTagEditorDialog(
      context: context,
      type: target.type,
      title: _text(strings, 'edit'),
      saveLabel: _text(strings, 'save'),
      cancelLabel: _text(strings, 'cancel'),
      initialCode: target.code,
      initialLabel: target.label,
    );

    if (!mounted) {
      return;
    }

    if (edited == null) {
      return;
    }

    final sameTypeTags = ledger.tagsByType(target.type);
    if (_hasDuplicateCode(
      tags: sameTypeTags,
      code: edited.code,
      ignoreCode: target.code,
    )) {
      _showCodeDuplicationAlert(strings);
      return;
    }

    if (edited.code == target.code) {
      await ref.read(ledgerProvider.notifier).addMetadataTag(edited);
      ref.invalidate(ledgerProvider);
      return;
    }

    // 새 코드를 먼저 생성한 뒤, 기존 코드를 참조 데이터에서 치환/삭제한다.
    await ref.read(ledgerProvider.notifier).addMetadataTag(edited);
    await ref
        .read(ledgerProvider.notifier)
        .replaceAndDeleteTag(
          type: target.type,
          targetCode: target.code,
          replacementCode: edited.code,
        );
    ref.invalidate(ledgerProvider);
  }

  /// 태그를 다른 코드로 대체한 뒤 삭제한다.
  Future<void> _deleteTag(MetadataTag tag) async {
    if (tag.isSystemDefault) return;
    final strings = ref.read(localizedStringsProvider);
    final ledger = ref.read(ledgerProvider).asData?.value;
    if (ledger == null) {
      return;
    }

    final candidates = ledger
        .tagsByType(tag.type)
        .where((MetadataTag item) => item.code != tag.code)
        .toList();

    final replacementCode = await showReplacementTagDialog(
      context: context,
      title: _text(strings, 'selectReplacement'),
      saveLabel: _text(strings, 'save'),
      cancelLabel: _text(strings, 'cancel'),
      candidates: candidates,
    );

    if (replacementCode == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final confirmed = await showLedgerConfirmDialog(
      context: context,
      title: _text(strings, 'confirmDelete'),
      message: '${tag.code} · ${tag.label}',
      confirmLabel: _text(strings, 'delete'),
      cancelLabel: _text(strings, 'cancel'),
    );

    if (!confirmed) {
      return;
    }

    if (!mounted) {
      return;
    }

    await ref
        .read(ledgerProvider.notifier)
        .replaceAndDeleteTag(
          type: tag.type,
          targetCode: tag.code,
          replacementCode: replacementCode,
        );
    ref.invalidate(ledgerProvider);
  }

  String _sectionTitle(MetadataTagType type, Map<String, String> strings) {
    switch (type) {
      case MetadataTagType.category:
        return _text(strings, 'expenseCategorySectionTitle');
      case MetadataTagType.subcategory:
        return _text(strings, 'expenseSubcategorySectionTitle');
      case MetadataTagType.diningOccasion:
        return _text(strings, 'diningOccasionSectionTitle');
      case MetadataTagType.paymentMethod:
        return _text(strings, 'paymentMethodSectionTitle');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    final isTutorial = ref.watch(
      tutorialProvider.select(
        (s) => s.isActive && s.phase == TutorialPhase.settings,
      ),
    );

    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedCurrencyUnit = _normalizeCurrencyUnit(
      ledger.settings.currencyUnit,
    );

    Widget buildInner(BuildContext showcaseCtx) {
      _showcase.bind(showcaseCtx);
      _maybeStartShowcase();

      final page = BootstrapPage(
        title: _text(strings, 'settingsTitle'),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              BootstrapSectionCard(
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: _text(strings, 'nameLabel'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _text(strings, 'ageLabel'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: ledger.settings.localeCode,
                      decoration: InputDecoration(
                        labelText: _text(strings, 'languageLabel'),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'ko',
                          child: Text('한국어'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'jp',
                          child: Text('日本語'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) return;
                        ref.read(ledgerProvider.notifier).changeLocale(value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCurrencyUnit,
                      decoration: InputDecoration(
                        labelText: _text(strings, 'currencyLabel'),
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '₩',
                          child: Text(_text(strings, 'currencyWonLabel')),
                        ),
                        DropdownMenuItem<String>(
                          value: '¥',
                          child: Text(_text(strings, 'currencyYenLabel')),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) return;
                        ref
                            .read(ledgerProvider.notifier)
                            .changeCurrencyUnit(value);
                      },
                    ),
                    const SizedBox(height: 16),
                    BootstrapActionButton(
                      label: _text(strings, 'save'),
                      icon: Icons.save,
                      onPressed: () => _saveProfile(strings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Showcase(
                key: _tagSectionKey,
                title: strings['tutSettingsTagTitle'] ?? '태그 관리',
                description:
                    strings['tutSettingsTagDesc'] ??
                    '소비구분, 소비세부, 소비수단 태그를 추가·수정·삭제할 수 있어요.\n나만의 태그로 지출 분류를 맞춤 설정해보세요!',
                tooltipPosition: TooltipPosition.bottom,
                child: Column(
                  children: <Widget>[
                    TagManagementSection(
                      title: _sectionTitle(MetadataTagType.category, strings),
                      tags: ledger.tagsByType(MetadataTagType.category),
                      strings: strings,
                      onAdd: () => _addTag(MetadataTagType.category),
                      onEdit: _editTag,
                      onDelete: _deleteTag,
                    ),
                    const SizedBox(height: 16),
                    TagManagementSection(
                      title: _sectionTitle(
                        MetadataTagType.subcategory,
                        strings,
                      ),
                      tags: ledger.tagsByType(MetadataTagType.subcategory),
                      strings: strings,
                      onAdd: () => _addTag(MetadataTagType.subcategory),
                      onEdit: _editTag,
                      onDelete: _deleteTag,
                    ),
                    const SizedBox(height: 16),
                    TagManagementSection(
                      title: _sectionTitle(
                        MetadataTagType.paymentMethod,
                        strings,
                      ),
                      tags: ledger.tagsByType(MetadataTagType.paymentMethod),
                      strings: strings,
                      onAdd: () => _addTag(MetadataTagType.paymentMethod),
                      onEdit: _editTag,
                      onDelete: _deleteTag,
                    ),
                    const SizedBox(height: 16),
                    TagManagementSection(
                      title: _sectionTitle(
                        MetadataTagType.diningOccasion,
                        strings,
                      ),
                      tags: ledger.tagsByType(MetadataTagType.diningOccasion),
                      strings: strings,
                      onAdd: () => _addTag(MetadataTagType.diningOccasion),
                      onEdit: _editTag,
                      onDelete: _deleteTag,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Showcase(
                key: _dataManageSectionKey,
                title: strings['tutSettingsDataManageTitle'] ?? '데이터 관리',
                description:
                    strings['tutSettingsDataManageDesc'] ??
                    '데이터를 CSV 파일로 내보내거나 가져올 수 있어요.\n다음 단계에서 데이터 내보내기 화면을 살펴볼게요!',
                tooltipPosition: TooltipPosition.top,
                child: _buildDataManagementSection(context, strings),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.copyrightsRoute),
                child: Text(_text(strings, 'creatorCreditsButton')),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (isTutorial) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBackDuringTutorial();
          },
          child: page,
        );
      }
      return page;
    }

    return ShowCaseWidget(
      onComplete: _onShowcaseComplete,
      enableAutoScroll: true,
      builder: buildInner,
    );
  }

  Widget _buildDataManagementSection(
    BuildContext context,
    Map<String, String> strings,
  ) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _text(strings, 'dataManagementSectionTitle'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          BootstrapActionButton(
            label: _text(strings, 'exportDataMenuLabel'),
            icon: Icons.upload_file_outlined,
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.exportDataRoute);
            },
          ),
          const SizedBox(height: 12),
          BootstrapActionButton(
            label: _text(strings, 'importDataMenuLabel'),
            icon: Icons.download_outlined,
            backgroundColor: const Color(0xFF198754),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRouter.importDataRoute);
            },
          ),
          const SizedBox(height: 12),
          BootstrapActionButton(
            label: _isMigratingDiningDescriptions
                ? _text(strings, 'diningMigrationRunning')
                : _text(strings, 'diningMigrationAction'),
            icon: Icons.auto_fix_high_rounded,
            backgroundColor: const Color(0xFF0D6EFD),
            onPressed: () => _migrateLegacyDiningDescriptions(strings),
          ),
          const SizedBox(height: 12),
          BootstrapActionButton(
            label: _text(strings, 'tutorialAgainButtonTitle'),
            icon: Icons.replay_outlined,
            backgroundColor: const Color(0xFF6C757D),
            onPressed: () async {
              final nav = Navigator.of(context);
              await TutorialService().resetTutorial();
              ref.read(tutorialProvider.notifier).startTutorial();
              nav.pushNamed(AppRouter.setupRoute);
            },
          ),
        ],
      ),
    );
  }
}
