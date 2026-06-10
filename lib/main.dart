import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:intl/date_symbol_data_local.dart';

Locale _flutterLocaleFromCode(String localeCode) {
  switch (localeCode) {
    case 'jp':
      return const Locale('ja');
    case 'ko':
    default:
      return const Locale('ko');
  }
}

/// 앱의 시작점을 구성한다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(const ProviderScope(child: HouseholdLedgerApp()));
}

/// 앱 생명주기와 루트 테마를 담당한다.
class HouseholdLedgerApp extends ConsumerStatefulWidget {
  /// 루트 앱 위젯을 생성한다.
  const HouseholdLedgerApp({super.key});

  @override
  ConsumerState<HouseholdLedgerApp> createState() => _HouseholdLedgerAppState();
}

/// 루트 앱 위젯의 생명주기 상태를 관리한다.
class _HouseholdLedgerAppState extends ConsumerState<HouseholdLedgerApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: _persistState,
      onDetach: _persistState,
      onHide: _persistState,
    );
  }

  /// 앱이 백그라운드로 이동할 때 현재 상태를 저장한다.
  void _persistState() {
    ref.read(ledgerProvider.notifier).persistCurrentState();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final router = ref.watch(appRouterProvider);
    final localeCode = ref.watch(
      ledgerProvider.select(
        (AsyncValue state) => state.asData?.value.settings.localeCode ?? 'ko',
      ),
    );

    return MaterialApp(
      title: strings['appTitle'] ?? 'Household Ledger',
      debugShowCheckedModeBanner: false,
      locale: _flutterLocaleFromCode(localeCode),
      supportedLocales: const <Locale>[Locale('ko'), Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D6EFD),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF102A43),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      onGenerateRoute: router.onGenerateRoute,
      initialRoute: AppRouter.onboardingRoute,
    );
  }
}
