import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  /// 디버그 모드에서 레이아웃 경계선을 시각화한다. false로 설정하면 릴리즈 모드와 동일한 화면을 확인할 수 있다.
  // debugPaintSizeEnabled = true;

  // 앱 콘텐츠가 시스템 상태바·하단 내비게이션바 뒤로 침범하지 않도록
  // 두 오버레이를 모두 활성화한 manual 모드로 고정한다.
  // edge-to-edge 기본 동작을 막아 전체 화면에서 일관된 안전 영역을 보장한다.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: <SystemUiOverlay>[SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  await initializeDateFormatting();
  runApp(
    const AppRestartWidget(child: ProviderScope(child: HouseholdLedgerApp())),
  );
}

// ── App restart support ──────────────────────────────────────────────────────

/// 앱 전체를 키 교체로 완전히 재시작할 수 있는 래퍼 위젯이다.
///
/// [ProviderScope]를 포함한 전체 위젯 트리를 재생성하므로
/// 모든 Riverpod 프로바이더가 스토리지에서 새로 로드된다.
///
/// 사용법:
/// ```dart
/// AppRestartWidget.restartApp(context);
/// ```
class AppRestartWidget extends StatefulWidget {
  /// [AppRestartWidget]을 생성한다.
  const AppRestartWidget({super.key, required this.child});

  /// 래핑할 자식 위젯.
  final Widget child;

  /// 위젯 트리를 완전히 재생성하여 앱을 재시작한다.
  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_AppRestartWidgetState>()?.restartApp();
  }

  @override
  State<AppRestartWidget> createState() => _AppRestartWidgetState();
}

class _AppRestartWidgetState extends State<AppRestartWidget> {
  Key _key = UniqueKey();

  void restartApp() {
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
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
