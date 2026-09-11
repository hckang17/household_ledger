import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/app_settings.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/push_notification_settings.dart';
import 'package:household_ledger/model/travel_gradient_palette.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/services/imexporting_file/data_im_export_service.dart';

void main() {
  const email = 'move@example.com';
  const passkey = 'secret';
  final service = DataImExportService();
  final trip = Trip.create(
    id: 'trip-1',
    name: 'Tokyo, autumn',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 3),
    budget: 300000,
    note: 'line 1\nline 2',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 2),
  );
  final expense = ExpenseEntry.create(
    id: 'expense-1',
    spentAt: DateTime(2026, 10, 2, 12),
    categoryCode: 'F',
    subcategoryCode: 't',
    tripId: trip.id,
    description: 'lunch',
    amount: 1200,
    note: 'memo, with comma',
  );
  final state = LedgerState.initial().copyWith(
    settings: const AppSettings(
      localeCode: 'ko',
      currencyUnit: '₩',
      monthlyBudget: 500000,
      onboardingCompleted: true,
      travelGradientPalette: TravelGradientPalette.sunset,
      useGradientBackground: true,
      pushNotifications: PushNotificationSettings(enabled: true, salaryDay: 25),
    ),
  );

  test(
    'v3 round trip includes trips, trip links, and complete app settings',
    () async {
      final csv = service.buildCsvContent(
        expenses: [expense],
        fixedExpenses: const [],
        incomes: const [],
        trips: [trip],
        ledgerState: state,
        email: email,
        passkey: passkey,
        timestamp: '20260911_120000',
      );

      final result = await service.importFromCsv(
        csvContent: csv,
        email: email,
        passkey: passkey,
      );

      expect(result.success, isTrue);
      expect(result.trips.single.id, trip.id);
      expect(result.trips.single.note, 'line 1\nline 2');
      expect(result.expenses.single.tripId, trip.id);
      expect(result.ledgerState!.settings.useGradientBackground, isTrue);
      expect(
        result.ledgerState!.settings.travelGradientPalette,
        TravelGradientPalette.sunset,
      );
      expect(result.ledgerState!.settings.pushNotifications.enabled, isTrue);
      expect(result.ledgerState!.settings.pushNotifications.salaryDay, 25);
    },
  );

  test('v2 backup imports without travel data and clears trip links', () async {
    var csv = service.buildCsvContent(
      expenses: [expense],
      fixedExpenses: const [],
      incomes: const [],
      trips: [trip],
      ledgerState: state,
      email: email,
      passkey: passkey,
      timestamp: '20260911_120000',
    );
    csv = csv.replaceFirst('version,3.0', 'version,2.0');
    csv = csv.replaceFirst(',tripId,', ',');
    csv = csv.replaceFirst(',${trip.id},', ',');
    csv = csv.replaceFirst(RegExp(r'appSettingsJson.*\n'), '');
    csv = csv.replaceFirst(RegExp(r'useGradientBackground.*\n'), '');
    csv = csv.replaceFirst(RegExp(r'\[TRIPS\][\s\S]*?\n\n'), '');

    final result = await service.importFromCsv(
      csvContent: csv,
      email: email,
      passkey: passkey,
    );

    expect(result.success, isTrue);
    expect(result.trips, isEmpty);
    expect(result.expenses.single.tripId, isNull);
    expect(result.ledgerState!.settings.useGradientBackground, isTrue);
    expect(
      result.ledgerState!.settings.travelGradientPalette,
      TravelGradientPalette.sunset,
    );
  });

  test('v3 rejects an expense that references a missing trip', () async {
    final csv = service.buildCsvContent(
      expenses: [expense],
      fixedExpenses: const [],
      incomes: const [],
      trips: [trip],
      ledgerState: state,
      email: email,
      passkey: passkey,
      timestamp: '20260911_120000',
    );

    final withoutTrip = csv.replaceFirst(',trip-1,', ',missing-trip,');
    final result = await service.importFromCsv(
      csvContent: withoutTrip,
      email: email,
      passkey: passkey,
    );

    expect(result.success, isFalse);
    expect(result.errorKey, 'invalidFileFormatMessage');
  });
}
