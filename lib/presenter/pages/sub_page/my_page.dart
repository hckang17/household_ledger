// """ MVVM 계층: View / Sub Feature Page """
// """ 역할: 사용자 프로필과 앱의 개인화 설정을 수정 """

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/services/push_message/push_message_service.dart';
import 'package:intl/intl.dart';

/// 이메일, 닉네임, 생년월일과 앱 개인화 설정을 관리하는 화면이다.
class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _nameController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _budgetController;

  DateTime? _birthDate;
  late String _localeCode;
  late String _currencyUnit;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final ledger = ref.read(ledgerProvider).asData?.value;
    final profile = ledger?.userProfile;
    _birthDate = profile?.birthDate;
    _emailController = TextEditingController(text: profile?.email ?? '');
    _nameController = TextEditingController(text: profile?.name ?? '');
    _birthDateController = TextEditingController(
      text: _birthDate == null ? '' : _formatDate(_birthDate!),
    );
    _budgetController = TextEditingController(
      text: (ledger?.settings.monthlyBudget ?? 0).toString(),
    );
    _localeCode = ledger?.settings.localeCode ?? 'ko';
    _currencyUnit = _normalizeCurrencyUnit(
      ledger?.settings.currencyUnit ?? '₩',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  String _text(Map<String, String> strings, String key, String fallback) =>
      strings[key] ?? fallback;

  String _formatDate(DateTime value) => DateFormat('yyyy.MM.dd').format(value);

  String _normalizeCurrencyUnit(String value) => value == '¥' ? '¥' : '₩';

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

  Future<void> _pickBirthDate() async {
    final DateTime today = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(today.year - 30),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _birthDate = selected;
      _birthDateController.text = _formatDate(selected);
    });
  }

  int? _calculatedAge() {
    final DateTime? birth = _birthDate;
    if (birth == null) return null;
    final DateTime today = DateTime.now();
    var age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    return age;
  }

  Future<void> _save(Map<String, String> strings) async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;
    final DateTime? birthDate = _birthDate;
    if (birthDate == null) return;

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(ledgerProvider.notifier);
      final previousLocale = ref
          .read(ledgerProvider)
          .asData
          ?.value
          .settings
          .localeCode;

      await notifier.updateUserProfile(
        name: _nameController.text,
        email: _emailController.text,
        birthDate: birthDate,
      );
      await notifier.changeMonthlyBudget(
        int.parse(_budgetController.text.trim()),
      );
      await notifier.changeCurrencyUnit(_currencyUnit);
      if (previousLocale != _localeCode) {
        await notifier.changeLocale(_localeCode);
        final ledger = ref.read(ledgerProvider).asData?.value;
        if (ledger != null) {
          final localizedStrings = await ref
              .read(localizationServiceProvider)
              .loadStrings(_localeCode);
          await ref
              .read(pushMessageServiceProvider)
              .syncRecurringSchedules(
                settings: ledger.settings.pushNotifications,
                strings: localizedStrings,
                localeCode: _localeCode,
              );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(strings, 'settingsSavedMessage', '정상적으로 저장됐습니다!'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final int? age = _calculatedAge();

    return BootstrapPage(
      title: _text(strings, 'myPageTitle', '마이페이지'),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            BootstrapSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SectionTitle(
                    icon: Icons.person_outline_rounded,
                    title: _text(strings, 'myPageProfileSection', '프로필 정보'),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _text(strings, 'emailLabel', '이메일'),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return _text(
                          strings,
                          'myPageEmailRequired',
                          '이메일을 입력해주세요.',
                        );
                      }
                      if (!_isValidEmail(value)) {
                        return _text(
                          strings,
                          'emailFormatError',
                          '이메일 형식을 확인해주세요.',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _text(
                        strings,
                        'myPageNicknameLabel',
                        '이름(닉네임)',
                      ),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    validator: (String? value) =>
                        value == null || value.trim().isEmpty
                        ? _text(
                            strings,
                            'myPageNicknameRequired',
                            '이름(닉네임)을 입력해주세요.',
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _birthDateController,
                    readOnly: true,
                    onTap: _pickBirthDate,
                    decoration: InputDecoration(
                      labelText: _text(strings, 'myPageBirthDateLabel', '생년월일'),
                      prefixIcon: const Icon(Icons.cake_outlined),
                      suffixIcon: const Icon(Icons.calendar_month_outlined),
                      helperText: age == null
                          ? null
                          : _text(
                              strings,
                              'myPageCalculatedAge',
                              '만 {age}세',
                            ).replaceAll('{age}', '$age'),
                    ),
                    validator: (_) => _birthDate == null
                        ? _text(
                            strings,
                            'myPageBirthDateRequired',
                            '생년월일을 선택해주세요.',
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            BootstrapSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SectionTitle(
                    icon: Icons.tune_rounded,
                    title: _text(strings, 'myPageAppSettingsSection', '앱 설정'),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _budgetController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: _text(strings, 'budgetLabel', '월 예산'),
                      prefixIcon: const Icon(Icons.savings_outlined),
                      suffixText: _currencyUnit,
                    ),
                    validator: (String? value) {
                      final int? budget = int.tryParse(value?.trim() ?? '');
                      return budget == null
                          ? _text(
                              strings,
                              'myPageBudgetInvalid',
                              '올바른 예산을 입력해주세요.',
                            )
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _localeCode,
                    decoration: InputDecoration(
                      labelText: _text(strings, 'languageLabel', '언어'),
                      prefixIcon: const Icon(Icons.language_rounded),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(value: 'ko', child: Text('한국어')),
                      DropdownMenuItem<String>(value: 'jp', child: Text('日本語')),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => _localeCode = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _currencyUnit,
                    decoration: InputDecoration(
                      labelText: _text(strings, 'currencyLabel', '통화 선택'),
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: '₩',
                        child: Text(_text(strings, 'currencyWonLabel', '₩ 원')),
                      ),
                      DropdownMenuItem<String>(
                        value: '¥',
                        child: Text(_text(strings, 'currencyYenLabel', '¥ 엔')),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) setState(() => _currencyUnit = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            BootstrapActionButton(
              label: _isSaving
                  ? _text(strings, 'myPageSaving', '저장 중...')
                  : _text(strings, 'save', '저장'),
              icon: _isSaving
                  ? Icons.hourglass_top_rounded
                  : Icons.save_rounded,
              onPressed: _isSaving ? null : () => _save(strings),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F1FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 21, color: const Color(0xFF0D6EFD)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
