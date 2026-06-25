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
    'homeCompPrevPeriodTitle': '지난달 동기 대비',
    'homeCompMorePercent': '{percent}% 더 사용하셨네요!',
    'homeCompLessPercent': '{percent}% 덜 사용하셨네요!',
    'homeCompMoreAmountMsg': '지난달 보다 {amount} 더 사용하셨어요.',
    'homeCompMoreCategoryMsg': '지난달 보다 {category}에서 {amount} 더 지출이 많아요.',
    'homeCompLessCategoryAmountMsg': '지난달 보다 {category}에서 {amount} 지출이 줄었어요.',
    'homeCompMoreAdviceMsg': '이번달은 {category}의 소비를 줄여볼까요?',
    'homeCompMoreAdviceMsg2': '{category} 지출이 늘었어요. 조금씩 아껴봐요!',
    'homeCompMoreAdviceMsg3': '{category}에서 아끼면 더 여유로워질 수 있어요!',
    'homeCompLessAmountMsg': '지난달 보다 {amount} 덜 사용하고 있어요!! 이대로 관리해볼까요?',
    'homeCompLessCategoryMsg': '지난달 보다 {category}의 지출이 적은것 같아요.',
    'analysisPrevMonthDiff': '전월동기 대비',
    'analysisPrevRangeDiff': '1개월전 동기 대비',
    'analysisNoCurrMonthData': '이번 달 소비 데이터가 없습니다.',
    'analysisNoPrevPeriodData': '전월동기 비교 데이터가 없습니다.',
    'analysisCompPeriodHint': '{start} ~ {end} 기간과 비교한 결과도 표시됩니다.',
    'analysisDailyCurrMonth': '이번달',
    'analysisDailyPrevMonth': '전월',
    'reportIncludePrevComparison': '전월동기대비 소비데이터 포함',
    'reportIncludePrevCategoryAnalysis': '전월동기대비 카테고리별 분석결과 포함',
    'pdfSectionPrevComparison': '전월동기 소비 비교',
    'pdfSectionPrevCategoryAnalysis': '카테고리별 전월동기 비교',
    'pdfCurrentPeriod': '이번 달',
    'pdfPrevPeriod': '전월동기',
    'pdfDiffLabel': '차이',
    'pdfSectionCategoryChart': '소비구분 분석 차트',
    'pdfSectionDailyChart': '일별 지출 추이 차트',
    'pdfChartCountUnit': '건',
    'reportTitleLabel': 'PDF 타이틀 지정',
    'reportTitleHint': '기본값: Household Ledger',
    'tooltipTotalSpentFixed': '고정지출',
    'tooltipTotalSpentSuffix': '을 제외한, 이번달 소비금액의 총 합입니다.',
    'tooltipRemainingPrefix': '이번달 총 소득에서 ',
    'tooltipRemainingFixed': '고정금액',
    'tooltipRemainingMid': '과 ',
    'tooltipRemainingTotal': '총 지출금액',
    'tooltipRemainingSuffix': '을 제외한 금액입니다.',
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
