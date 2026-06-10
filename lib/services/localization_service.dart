import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:household_ledger/services/debugging_logger.dart';

/// 언어 리소스 로딩을 담당한다.
class LocalizationService {
  static const String _logPrefix = '[LocalizationService]';

  void _log(String methodName, String action) {
    logger.d('[localization_service.dart] $methodName ( $action )');
  }

  /// 로딩 실패 시 사용할 기본 한국어 문자열을 제공한다.
  static const Map<String, String> fallbackStrings = <String, String>{
    'appTitle': '가계부',
    'onboardingTitle': '생활비 흐름을 한 화면에서 관리하세요',
    'onboardingSubtitle': '초기 설정을 마치면 소비 기록, 고정지출, 월별 분석을 바로 시작할 수 있습니다.',
    'startSetup': '초기 설정 시작',
    'continueApp': '앱 시작하기',
    'setupTitle': '초기 설정',
    'nameLabel': '이름',
    'ageLabel': '나이',
    'budgetLabel': '월 예산',
    'languageLabel': '언어',
    'currencyLabel': '통화 선택',
    'currencyWonLabel': '₩ 원',
    'currencyYenLabel': '¥ 엔',
    'save': '저장',
    'settingsSavedMessage': '정상적으로 저장됐습니다!',
    'cancel': '취소',
    'homeTitle': '메인 화면',
    'incomeManage': '수입 관리',
    'expenseManage': '지출 관리',
    'quickExpense': '지출 기록하기',
    'analysis': '지출 분석하기',
    'settings': '설정',
    'expenseTopTitle': '지출 관리',
    'fixedExpenseManage': '고정지출 관리',
    'expenseRecord': '소비내역 기록',
    'fixedExpenseTitle': '고정지출 관리',
    'expenseRecordTitle': '소비내역 기록',
    'totalSpent': '총 지출금액',
    'remainingBudget': '지출가능금액',
    'monthlyTotalSpentLabel': '{month}월 총 지출금액',
    'monthlyRemainingBudgetLabel': '{month}월 지출가능금액',
    'todayDateCompact': '오늘: {date}',
    'calendarFold': '달력 접기',
    'calendarUnfold': '달력 펼치기',
    'queryByDate': '조회하기',
    'viewMonthly': '월 전체 보기',
    'expenseRecordDaySectionLabel': '{month}월 {day}일',
    'currencyUnit': '원',
    'fixedExpenseTotal': '고정지출 합계',
    'addExpense': '지출 추가',
    'addFixedExpense': '고정지출 추가',
    'addIncome': '소득 추가',
    'edit': '수정',
    'delete': '삭제',
    'descriptionLabel': '내용',
    'amountLabel': '금액',
    'noteLabel': '비고',
    'categoryLabel': '소비구분',
    'subcategoryLabel': '소비 소구분',
    'paymentMethodLabel': '소비수단',
    'expenseCategorySectionTitle': '지출구분',
    'expenseSubcategorySectionTitle': '지출소구분',
    'paymentMethodSectionTitle': '지불수단',
    'selectReplacement': '대체 태그 선택',
    'confirmDelete': '삭제 확인',
    'confirmDeleteQuestion': '을(를) 정말 삭제하시겠습니까?',
    'codeDuplicationAlert': '이미 사용 중인 Code입니다. 다른 Code를 입력해주세요.',
    'settingsTitle': '환경설정',
    'metadataTitle': '태그 관리',
    'addTag': '태그 추가',
    'recordedItems': '기록된 항목',
    'analysisPeriodSelectionTitle': '달 선택 및 캘린더 기간 선택',
    'selectMonth': '달 선택',
    'selectDateRange': '캘린더 기간 선택',
    'rangeSummary': '기간 선택 요약',
    'clearSelection': '선택 초기화',
    'yearLabel': '연도',
    'monthLabel': '월',
    'apply': '적용',
    'noSelectedPeriod': '선택된 기간이 없습니다',
    'emptySelectedPeriodData': '선택된 기간내 소비 내역이 없습니다',
    'detailedSummary': '상세 요약',
    'mostUsedCategory': '제일 많이 쓰는 카테고리',
    'monthlySummary': '월별 요약',
    'incomeTotal': '월 소득 합계',
    'emptyData': '아직 입력된 데이터가 없습니다.',
    'incomePlaceholder': '수입 관리 기능은 다음 단계에서 확장할 수 있도록 자리만 준비했습니다.',
  };

  /// 선택한 로케일 파일을 읽어 문자열 맵으로 반환한다.
  Future<Map<String, String>> loadStrings(String localeCode) async {
    _log('loadStrings', '언어 문자열 로드 시작');
    logger.d('$_logPrefix loadStrings() started. localeCode=$localeCode');
    try {
      final content = await rootBundle.loadString(
        'assets/language_data/$localeCode.json',
      );
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final strings = decoded.map(
        (String key, dynamic value) =>
            MapEntry<String, String>(key, value.toString()),
      );
      logger.d(
        '$_logPrefix loadStrings() completed. localeCode=$localeCode, keys=${strings.length}.',
      );
      _log('loadStrings', '언어 문자열 로드 완료');
      return strings;
    } catch (error) {
      logger.e(
        '$_logPrefix loadStrings() failed. localeCode=$localeCode, error=$error. fallback used.',
      );
      _log('loadStrings', '로드 실패로 fallback 문자열 반환');
      return fallbackStrings;
    }
  }
}
