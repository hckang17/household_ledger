import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/pages/expense_page/analysis_page.dart';
import 'package:household_ledger/presenter/pages/sub_page/data_managing_page.dart';
import 'package:household_ledger/presenter/pages/sub_page/export_data_page.dart';
import 'package:household_ledger/presenter/pages/sub_page/generating_report_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/expense_management_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/expense_record_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/fixed_expense_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/main_shell_page.dart';
import 'package:household_ledger/presenter/pages/sub_page/import_data_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/income_page.dart';
import 'package:household_ledger/presenter/pages/sub_page/loading_page.dart';
import 'package:household_ledger/presenter/pages/sub_page/onboarding_page.dart';
import 'package:household_ledger/presenter/pages/sub_page/settings_page.dart';
import 'package:household_ledger/presenter/pages/sub_page/setup_page.dart';

/// 앱 라우터를 주입한다.
final appRouterProvider = Provider<AppRouter>((Ref ref) {
  return AppRouter();
});

/// 앱 전체 라우팅을 담당한다.
class AppRouter {
  /// 온보딩 라우트 이름을 정의한다.
  static const String onboardingRoute = '/';

  /// 초기 설정 라우트 이름을 정의한다.
  static const String setupRoute = '/setup';

  /// 로딩 화면 라우트 이름을 정의한다.
  static const String loadingRoute = '/loading';

  /// 메인 라우트 이름을 정의한다.
  static const String homeRoute = '/home';

  /// 지출 관리 상위 라우트 이름을 정의한다.
  static const String expenseManagementRoute = '/expense-management';

  /// 고정지출 라우트 이름을 정의한다.
  static const String fixedExpenseRoute = '/fixed-expense';

  /// 소비 기록 라우트 이름을 정의한다.
  static const String expenseRecordRoute = '/expense-record';

  /// 설정 라우트 이름을 정의한다.
  static const String settingsRoute = '/settings';

  /// 수입 관리 라우트 이름을 정의한다.
  static const String incomeRoute = '/income';

  /// 분석 라우트 이름을 정의한다.
  static const String analysisRoute = '/analysis';

  /// 가계부 데이터 추출 라우트 이름을 정의한다.
  static const String exportDataRoute = '/export-data';

  /// 가계부 데이터 가져오기 라우트 이름을 정의한다.
  static const String importDataRoute = '/import-data';

  /// PDF 리포트 생성 라우트 이름을 정의한다.
  static const String generatingReportRoute = '/generating-report';

  /// 데이터 관리 라우트 이름을 정의한다.
  static const String dataManageRoute = '/data-manage';

  /// 제작자 표시 화면 라우트 이름을 정의한다.
  static const String copyrightsRoute = '/copyrights';

  /// 이름 기반 라우팅을 생성한다.
  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case onboardingRoute:
        return _buildRoute(const OnboardingPage(), settings);
      case setupRoute:
        return _buildRoute(const SetupPage(), settings);
      case loadingRoute:
        return _buildRoute(const LoadingPage(), settings);
      case homeRoute:
        return _buildRoute(const MainShellPage(), settings);
      case expenseManagementRoute:
        return _buildRoute(const ExpenseManagementPage(), settings);
      case fixedExpenseRoute:
        return _buildRoute(const FixedExpensePage(), settings);
      case expenseRecordRoute:
        return _buildRoute(const ExpenseRecordPage(), settings);
      case settingsRoute:
        return _buildRoute(const SettingsPage(), settings);
      case incomeRoute:
        return _buildRoute(const IncomePage(), settings);
      case analysisRoute:
        return _buildRoute(const AnalysisPage(), settings);
      case exportDataRoute:
        return _buildRoute(const ExportDataPage(), settings);
      case importDataRoute:
        final args = settings.arguments as Map<String, dynamic>?;
        final fromSetup = args?['fromSetup'] as bool? ?? false;
        return _buildRoute(ImportDataPage(fromSetup: fromSetup), settings);
      case generatingReportRoute:
        return _buildRoute(const GeneratingReportPage(), settings);
      case dataManageRoute:
        return _buildRoute(const DataManagingPage(), settings);
      default:
        return _buildRoute(const OnboardingPage(), settings);
    }
  }

  /// 공통 MaterialPageRoute를 생성한다.
  MaterialPageRoute<dynamic> _buildRoute(Widget child, RouteSettings settings) {
    return MaterialPageRoute<dynamic>(
      builder: (BuildContext context) => child,
      settings: settings,
    );
  }
}
