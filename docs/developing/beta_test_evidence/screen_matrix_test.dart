// Beta audit harness: production pages with isolated SQLite fixtures.
// Run: flutter test docs/developing/beta_test_evidence/screen_matrix_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/model/user_profile.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/services/database/expense_database_service.dart';
import 'package:household_ledger/services/database/fixed_expense_database_service.dart';
import 'package:household_ledger/services/database/income_database_service.dart';
import 'package:household_ledger/services/database/travel_database_service.dart';
import 'package:logger/logger.dart';
import 'package:household_ledger/services/local_storage_service.dart';
import 'package:household_ledger/services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';

const evidence = 'docs/developing/beta_test_evidence';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final results = <Map<String, Object?>>[];
  final expenseDb = ExpenseDatabaseService();
  final fixedDb = FixedExpenseDatabaseService();
  final incomeDb = IncomeDatabaseService();
  final travelDb = TravelDatabaseService();
  final now = DateTime.now();
  setUpAll(() async {
    Logger.level = Level.off;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('ledger_beta_matrix_');
    await databaseFactory.setDatabasesPath(dir.path);
    await initializeDateFormatting();
    await expenseDb.upsertExpenses([
      for (var i = 0; i < 40; i++) ExpenseEntry.create(
        id: 'beta-$i', spentAt: DateTime(now.year, now.month - i ~/ 20, i % 20 + 1, 12),
        categoryCode: ['F', 'T', 'A', 'L'][i % 4],
        subcategoryCode: i % 2 == 0 ? 't' : '_',
        tripId: i % 2 == 0 ? 'beta-trip' : null,
        diningOccasionCode: i % 4 == 0 ? 'lunch' : null,
        description: 'ベータテスト長い名前の支出項目です',
        amount: (i + 1) * 123456, note: '테스트 메모',
      ),
    ]);
    await fixedDb.upsertFixedExpenses([
      FixedExpense.create(id: 'fixed', appliedAt: now, categoryCode: 'L', description: '家賃と保険料の長い項目名', amount: 800000),
    ]);
    await incomeDb.upsertIncome(IncomeEntry.create(earnedAt: now, amount: 3500000, description: 'Beta salary'));
    await travelDb.upsertTrip(Trip.create(id: 'beta-trip', name: '가을 여행 東京・京都の長い旅行名', startDate: DateTime(now.year, now.month, 1), endDate: DateTime(now.year, now.month, 15), budget: 1000000));
  });
  tearDownAll(() async {
    await File('$evidence/screen_matrix.json').writeAsString(const JsonEncoder.withIndent('  ').convert(results));
  });
  const configurations = [
    ('small', Size(320, 568), 1.0, 'ko'),
    ('phone', Size(393, 852), 1.0, 'ko'),
    ('tablet', Size(800, 1280), 1.0, 'ko'),
    ('landscape', Size(640, 360), 1.0, 'ko'),
    ('largefont', Size(360, 640), 1.8, 'ko'),
    ('japanese', Size(320, 568), 1.3, 'jp'),
  ];
  const routes = ['/', '/setup', '/home', '/income', '/expense-record', '/fixed-expense', '/analysis', '/travel-management', '/travel-detail', '/data-manage', '/settings', '/my-page', '/export-data', '/import-data', '/generating-report', '/copyrights'];
  for (final config in configurations) {
    for (final route in routes) {
      testWidgets('${config.$1} $route', (tester) async {
        tester.view.physicalSize = config.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({'tutorial_completed': true, 'tutorial_version': 1});
        final strings = (await tester.runAsync(() => LocalizationService().loadStrings(config.$4)))!;
        final state = LedgerState.initial().copyWith(
          settings: LedgerState.initial().settings.copyWith(localeCode: config.$4, onboardingCompleted: true, monthlyBudget: 4000000),
          userProfile: UserProfile(name: '베타테스터', email: 'beta@example.com', birthDate: DateTime(1990, 1, 1)),
        );
        final container = ProviderContainer(overrides: [
          expenseDatabaseServiceProvider.overrideWithValue(expenseDb),
          fixedExpenseDatabaseServiceProvider.overrideWithValue(fixedDb),
          incomeDatabaseServiceProvider.overrideWithValue(incomeDb),
          travelDatabaseServiceProvider.overrideWithValue(travelDb),
          localizedStringsProvider.overrideWithValue({...strings, 'currencyUnit': '₩'}),
        ]);
        await tester.runAsync(() async {
          await LocalStorageService().saveState(state);
          await container.read(ledgerProvider.future);
          await container.read(travelProvider.future);
        });
        final errors = <String>[];
        final oldError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details.toString());
        final boundary = GlobalKey();
        await tester.pumpWidget(UncontrolledProviderScope(container: container, child: RepaintBoundary(key: boundary, child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(config.$4 == 'jp' ? 'ja' : 'ko'),
          supportedLocales: const [Locale('ko'), Locale('ja')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: ThemeData(useMaterial3: true, platform: TargetPlatform.android, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D6EFD))),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(config.$3)), child: child!),
          onGenerateInitialRoutes: (_) => [AppRouter().onGenerateRoute(RouteSettings(name: route, arguments: route == '/travel-detail' ? 'beta-trip' : null))],
          onGenerateRoute: AppRouter().onGenerateRoute,
        ))));
        for (var n = 0; n < 10; n++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
          await tester.pump(const Duration(milliseconds: 350));
        }
        final slug = route == '/' ? 'onboarding' : route.substring(1);
        final screen = '${config.$1}_$slug.png';
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$evidence/$screen').writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        results.add({'config': config.$1, 'width': config.$2.width, 'height': config.$2.height, 'textScale': config.$3, 'locale': config.$4, 'route': route, 'errors': errors.toSet().toList(), 'screenshot': screen});
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
        FlutterError.onError = oldError;
        container.dispose();
      });
    }
  }
}
