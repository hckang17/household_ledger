import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';

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
  bool _isCategoryExpanded = false;
  bool _isSubcategoryExpanded = false;
  bool _isPaymentExpanded = false;

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
      case MetadataTagType.paymentMethod:
        return _text(strings, 'paymentMethodSectionTitle');
    }
  }

  bool _isSectionExpanded(MetadataTagType type) {
    switch (type) {
      case MetadataTagType.category:
        return _isCategoryExpanded;
      case MetadataTagType.subcategory:
        return _isSubcategoryExpanded;
      case MetadataTagType.paymentMethod:
        return _isPaymentExpanded;
    }
  }

  void _toggleSection(MetadataTagType type) {
    setState(() {
      switch (type) {
        case MetadataTagType.category:
          _isCategoryExpanded = !_isCategoryExpanded;
        case MetadataTagType.subcategory:
          _isSubcategoryExpanded = !_isSubcategoryExpanded;
        case MetadataTagType.paymentMethod:
          _isPaymentExpanded = !_isPaymentExpanded;
      }
    });
  }

  /// 태그 관리 섹션을 렌더링한다.
  Widget _buildTagSection({
    required BuildContext context,
    required String title,
    required List<MetadataTag> tags,
    required MetadataTagType type,
    required Map<String, String> strings,
  }) {
    final expanded = _isSectionExpanded(type);
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: () => _toggleSection(type),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _addTag(type),
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                onPressed: () => _toggleSection(type),
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ),
            ],
          ),
          if (expanded) const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: !expanded
                ? const SizedBox.shrink()
                : Column(
                    children: tags.map((MetadataTag tag) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F9FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${tag.code} : ${tag.label}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _text(strings, 'edit'),
                              onPressed: () => _editTag(tag),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _text(strings, 'delete'),
                              onPressed: tags.length > 1
                                  ? () => _deleteTag(tag)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
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
    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedCurrencyUnit = _normalizeCurrencyUnit(
      ledger.settings.currencyUnit,
    );

    return BootstrapPage(
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
                  // 월 예산 기능은 현재 사용하지 않아 UI/저장 경로를 비활성화한다.
                  // TextField(
                  //   controller: _budgetController,
                  //   keyboardType: TextInputType.number,
                  //   decoration: InputDecoration(
                  //     labelText: _text(strings, 'budgetLabel'),
                  //   ),
                  // ),
                  DropdownButtonFormField<String>(
                    initialValue: ledger.settings.localeCode,
                    decoration: InputDecoration(
                      labelText: _text(strings, 'languageLabel'),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'ko', child: Text('한국어')),
                      DropdownMenuItem<String>(value: 'jp', child: Text('日本語')),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }

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
                      if (value == null) {
                        return;
                      }

                      ref
                          .read(ledgerProvider.notifier)
                          .changeCurrencyUnit(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // 기존 예산 저장 버튼은 비활성화하고, 프로필 저장 버튼으로 대체한다.
                  BootstrapActionButton(
                    label: _text(strings, 'save'),
                    icon: Icons.save,
                    onPressed: () => _saveProfile(strings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            /// 태그 관리 섹션
            _buildTagSection(
              context: context,
              title: _sectionTitle(MetadataTagType.category, strings),
              tags: ledger.tagsByType(MetadataTagType.category),
              type: MetadataTagType.category,
              strings: strings,
            ),
            const SizedBox(height: 16),
            _buildTagSection(
              context: context,
              title: _sectionTitle(MetadataTagType.subcategory, strings),
              tags: ledger.tagsByType(MetadataTagType.subcategory),
              type: MetadataTagType.subcategory,
              strings: strings,
            ),
            const SizedBox(height: 16),
            _buildTagSection(
              context: context,
              title: _sectionTitle(MetadataTagType.paymentMethod, strings),
              tags: ledger.tagsByType(MetadataTagType.paymentMethod),
              type: MetadataTagType.paymentMethod,
              strings: strings,
            ),
            const SizedBox(height: 16),
            _buildDataManagementSection(context, strings),
          ],
        ),
      ),
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
        ],
      ),
    );
  }
}
