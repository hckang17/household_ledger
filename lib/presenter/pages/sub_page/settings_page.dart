import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/push_notification_settings.dart';
import 'package:household_ledger/presenter/widgets/settings_page/app_background_section.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/services/push_message/push_message_service.dart';

/// App appearance and push notification preferences.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _text(Map<String, String> strings, String key) => strings[key] ?? '';

  Future<void> _setPushNotificationsEnabled(
    bool enabled,
    Map<String, String> strings,
  ) async {
    final ledger = ref.read(ledgerProvider).asData?.value;
    if (ledger == null) return;

    final service = ref.read(pushMessageServiceProvider);
    await service.initialize(localeCode: ledger.settings.localeCode);
    if (enabled && !await service.requestPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(strings, 'pushPermissionDenied'))),
      );
      return;
    }

    final next = ledger.settings.pushNotifications.copyWith(enabled: enabled);
    await ref.read(ledgerProvider.notifier).changePushNotifications(next);
    if (enabled) {
      await service.syncRecurringSchedules(
        settings: next,
        strings: strings,
        localeCode: ledger.settings.localeCode,
      );
    } else {
      await service.cancelAllManagedNotifications();
    }
  }

  Future<void> _setPushCategory(
    PushNotificationCategory category,
    bool enabled,
    Map<String, String> strings,
  ) async {
    final ledger = ref.read(ledgerProvider).asData?.value;
    if (ledger == null) return;
    final next = ledger.settings.pushNotifications.setCategory(
      category,
      enabled,
    );
    await ref.read(ledgerProvider.notifier).changePushNotifications(next);
    await ref
        .read(pushMessageServiceProvider)
        .syncRecurringSchedules(
          settings: next,
          strings: strings,
          localeCode: ledger.settings.localeCode,
        );
  }

  Future<void> _setSalaryDay(int day, Map<String, String> strings) async {
    final ledger = ref.read(ledgerProvider).asData?.value;
    if (ledger == null) return;
    final next = ledger.settings.pushNotifications.copyWith(salaryDay: day);
    await ref.read(ledgerProvider.notifier).changePushNotifications(next);
    await ref
        .read(pushMessageServiceProvider)
        .syncRecurringSchedules(
          settings: next,
          strings: strings,
          localeCode: ledger.settings.localeCode,
        );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return BootstrapPage(
      title: _text(strings, 'settingsTitle'),
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            AppBackgroundSection(
              strings: strings,
              selectedPalette: ledger.settings.useGradientBackground
                  ? ledger.settings.travelGradientPalette
                  : null,
              onChanged: (palette) async {
                try {
                  await ref
                      .read(ledgerProvider.notifier)
                      .changeAppBackground(palette);
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(strings['appBackgroundSaveError'] ?? ''),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),

            _buildPushNotificationSection(
              context,
              strings,
              ledger.settings.pushNotifications,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPushNotificationSection(
    BuildContext context,
    Map<String, String> strings,
    PushNotificationSettings settings,
  ) {
    Widget categorySwitch({
      required PushNotificationCategory category,
      required String titleKey,
      required String descriptionKey,
    }) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(_text(strings, titleKey)),
        subtitle: Text(_text(strings, descriptionKey)),
        value: settings.isCategoryEnabled(category),
        onChanged: (bool value) => _setPushCategory(category, value, strings),
      );
    }

    return BootstrapSectionCard(
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _text(strings, 'pushSettingsTitle'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(_text(strings, 'pushMasterTitle')),
              subtitle: Text(_text(strings, 'pushMasterDescription')),
              value: settings.enabled,
              onChanged: (bool value) =>
                  _setPushNotificationsEnabled(value, strings),
            ),
            if (settings.enabled) ...<Widget>[
              const Divider(),
              categorySwitch(
                category: PushNotificationCategory.daily,
                titleKey: 'pushCategoryDaily',
                descriptionKey: 'pushCategoryDailyDescription',
              ),
              categorySwitch(
                category: PushNotificationCategory.fixedExpense,
                titleKey: 'pushCategoryFixedExpense',
                descriptionKey: 'pushCategoryFixedExpenseDescription',
              ),
              categorySwitch(
                category: PushNotificationCategory.salary,
                titleKey: 'pushCategorySalary',
                descriptionKey: 'pushCategorySalaryDescription',
              ),
              if (settings.isCategoryEnabled(PushNotificationCategory.salary))
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 4, bottom: 8),
                  child: DropdownButtonFormField<int>(
                    initialValue: settings.salaryDay,
                    decoration: InputDecoration(
                      labelText: _text(strings, 'pushSalaryDayLabel'),
                      isDense: true,
                    ),
                    items: List<DropdownMenuItem<int>>.generate(
                      28,
                      (int index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text(
                          _text(
                            strings,
                            'pushDayOfMonth',
                          ).replaceAll('{day}', '${index + 1}'),
                        ),
                      ),
                    ),
                    onChanged: (int? value) {
                      if (value != null) _setSalaryDay(value, strings);
                    },
                  ),
                ),
              categorySwitch(
                category: PushNotificationCategory.other,
                titleKey: 'pushCategoryOther',
                descriptionKey: 'pushCategoryOtherDescription',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
