import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/push_notification_settings.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:household_ledger/presenter/pages/sub_page/ledger_metadata_page.dart';
import 'package:household_ledger/presenter/pages/sub_page/my_page.dart';
import 'package:household_ledger/presenter/pages/sub_page/settings_page.dart';
import 'package:household_ledger/presenter/widgets/common/side_bar.dart';
import 'package:household_ledger/presenter/widgets/ledger_metadata_page/tag_management_section.dart';
import 'package:household_ledger/presenter/widgets/settings_page/app_background_section.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/services/push_message/push_message_service.dart';

void main() {
  for (final locale in ['ko', 'jp']) {
    testWidgets(
      '$locale: quick menu separates settings and metadata; my page remains',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final strings = Map<String, String>.from(
          jsonDecode(
                File('assets/language_data/$locale.json').readAsStringSync(),
              )
              as Map,
        );
        final ledger = _Ledger();
        final container = ProviderContainer(
          overrides: [
            ledgerProvider.overrideWith(() => ledger),
            localizedStringsProvider.overrideWithValue(strings),
          ],
        );
        addTearDown(container.dispose);
        await container.read(ledgerProvider.future);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                appBar: AppBar(actions: const [SideBarButton()]),
                endDrawer: const RightSideBar(),
              ),
              onGenerateRoute: AppRouter().onGenerateRoute,
            ),
          ),
        );

        Future<void> openMenu() async {
          await tester.tap(find.byType(SideBarButton));
          await tester.pumpAndSettle();
        }

        await openMenu();
        expect(
          find.text(strings['sideBarNotificationSettings']!),
          findsNothing,
        );
        expect(find.text(strings['sideBarMetadataEdit']!), findsNothing);
        await tester.tap(find.text(strings['settingsTitle']!).last);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPage), findsOneWidget);
        expect(find.byType(AppBackgroundSection), findsOneWidget);
        expect(find.text(strings['pushSettingsTitle']!), findsOneWidget);
        expect(find.byType(TagManagementSection), findsNothing);
        expect(find.text(strings['nameLabel']!), findsNothing);
        expect(find.text(strings['dataManagementSectionTitle']!), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pageBack();
        await tester.pumpAndSettle();
        await openMenu();
        await tester.tap(find.text(strings['ledgerMetadataTitle']!));
        await tester.pumpAndSettle();
        expect(find.byType(LedgerMetadataPage), findsOneWidget);
        expect(find.byType(TagManagementSection), findsNWidgets(4));
        expect(find.byType(AppBackgroundSection), findsNothing);
        expect(find.text(strings['pushSettingsTitle']!), findsNothing);
        for (final key in [
          'nameLabel',
          'myPageBirthDateLabel',
          'languageLabel',
          'currencyLabel',
          'dataManagementSectionTitle',
        ]) {
          expect(find.text(strings[key]!), findsOneWidget);
        }
        await tester.enterText(find.byType(TextField).first, 'Updated name');
        final save = find.widgetWithText(FilledButton, strings['save']!);
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(ledger.savedName, 'Updated name');
        expect(ledger.savedBirthDate, DateTime(1990, 1, 1));
        final export = find.widgetWithText(
          FilledButton,
          strings['exportDataMenuLabel']!,
        );
        await tester.ensureVisible(export);
        expect(export.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pageBack();
        await tester.pumpAndSettle();
        await openMenu();
        await tester.tap(find.text(strings['sideBarMyPage']!));
        await tester.pumpAndSettle();
        expect(find.byType(MyPage), findsOneWidget);
        expect(find.text(strings['emailLabel']!), findsOneWidget);
        expect(find.text(strings['myPageNicknameLabel']!), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(strings['budgetLabel']!),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text(strings['budgetLabel']!), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'settings keeps background and notification callbacks connected',
    (tester) async {
      final ledger = _Ledger();
      final push = _PushService();
      final strings = Map<String, String>.from(
        jsonDecode(File('assets/language_data/ko.json').readAsStringSync())
            as Map,
      );
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWith(() => ledger),
          pushMessageServiceProvider.overrideWithValue(push),
          localizedStringsProvider.overrideWithValue(strings),
        ],
      );
      addTearDown(container.dispose);
      await container.read(ledgerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      tester
          .widget<AppBackgroundSection>(find.byType(AppBackgroundSection))
          .onChanged(TravelGradientPalette.values.last);
      await tester.pumpAndSettle();
      expect(ledger.palette, TravelGradientPalette.values.last);
      final master = find.widgetWithText(
        SwitchListTile,
        strings['pushMasterTitle']!,
      );
      await tester.ensureVisible(master);
      await tester.tap(master);
      await tester.pumpAndSettle();
      expect(ledger.notifications?.enabled, isTrue);
      expect(push.scheduled, isTrue);
      await tester.tap(master);
      await tester.pumpAndSettle();
      expect(ledger.notifications?.enabled, isFalse);
      expect(push.cancelled, isTrue);
    },
  );
}

class _Ledger extends LedgerNotifier {
  String? savedName;
  DateTime? savedBirthDate;
  TravelGradientPalette? palette;
  PushNotificationSettings? notifications;

  @override
  Future<LedgerState> build() async {
    final initial = LedgerState.initial();
    return initial.copyWith(
      userProfile: initial.userProfile.copyWith(
        name: 'Name',
        birthDate: DateTime(1990, 1, 1),
      ),
    );
  }

  @override
  Future<void> updateUserProfile({
    required String name,
    String? email,
    DateTime? birthDate,
    int? age,
  }) async {
    savedName = name;
    savedBirthDate = birthDate;
  }

  @override
  Future<void> changeAppBackground(TravelGradientPalette? value) async {
    palette = value;
  }

  @override
  Future<void> changePushNotifications(PushNotificationSettings value) async {
    notifications = value;
    state = AsyncData(state.requireValue.changePushNotifications(value));
  }
}

class _PushService extends PushMessageService {
  bool scheduled = false;
  bool cancelled = false;

  @override
  Future<void> initialize({required String localeCode}) async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> syncRecurringSchedules({
    required PushNotificationSettings settings,
    required Map<String, String> strings,
    required String localeCode,
  }) async {
    scheduled = true;
  }

  @override
  Future<void> cancelAllManagedNotifications() async {
    cancelled = true;
  }
}
