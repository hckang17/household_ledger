import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/pages/analysis_page.dart';
import 'package:household_ledger/presenter/pages/export_data_page.dart';
import 'package:household_ledger/presenter/pages/expense_management_page.dart';
import 'package:household_ledger/presenter/pages/expense_record_page.dart';
import 'package:household_ledger/presenter/pages/fixed_expense_page.dart';
import 'package:household_ledger/presenter/pages/home_page.dart';
import 'package:household_ledger/presenter/pages/import_data_page.dart';
import 'package:household_ledger/presenter/pages/income_page.dart';
import 'package:household_ledger/presenter/pages/onboarding_page.dart';
import 'package:household_ledger/presenter/pages/settings_page.dart';
import 'package:household_ledger/presenter/pages/setup_page.dart';

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

  /// 이름 기반 라우팅을 생성한다.
  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case onboardingRoute:
        return _buildRoute(const OnboardingPage(), settings);
      case setupRoute:
        return _buildRoute(const SetupPage(), settings);
      case homeRoute:
        return _buildRoute(const HomePage(), settings);
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
        return _buildRoute(const ImportDataPage(), settings);
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
