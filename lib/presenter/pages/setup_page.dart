import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/router/app_router.dart';

/// 초기 설정 화면이다.
class SetupPage extends ConsumerStatefulWidget {
  /// 초기 설정 화면을 생성한다.
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

/// 초기 설정 화면의 폼 상태를 관리한다.
class _SetupPageState extends ConsumerState<SetupPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _budgetController;
  String _localeCode = 'ko';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _budgetController = TextEditingController();
  }

  /// 입력된 초기 설정을 저장한다.
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

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.homeRoute,
      (Route<dynamic> route) => false,
    );
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

    return BootstrapPage(
      title: strings['setupTitle'] ?? '',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: BootstrapSectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: strings['nameLabel']),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: strings['ageLabel']),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: strings['budgetLabel'],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _localeCode,
                  decoration: InputDecoration(
                    labelText: strings['languageLabel'],
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'ko', child: Text('KR')),
                    DropdownMenuItem<String>(value: 'jp', child: Text('JP')),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _localeCode = value;
                    });
                  },
                ),
                const SizedBox(height: 24),
                BootstrapActionButton(
                  label: strings['save'] ?? '',
                  icon: Icons.save_rounded,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                SizedBox(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
