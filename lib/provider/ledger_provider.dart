import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/user_profile.dart';
import 'package:household_ledger/services/debugging_logger.dart';
import 'package:household_ledger/services/database/expense_database_service.dart';
import 'package:household_ledger/services/database/fixed_expense_database_service.dart';
import 'package:household_ledger/services/database/income_database_service.dart';
import 'package:household_ledger/services/local_storage_service.dart';
import 'package:household_ledger/services/localization_service.dart';

void _logLedgerProvider(String methodName, String action) {
  logger.d('[ledger_provider.dart] $methodName ( $action )');
}

String _defaultCurrencyUnitByLocale(String localeCode) {
  return localeCode == 'jp' ? '¥' : '₩';
}

/// 로컬 저장소 서비스를 주입한다.
final localStorageServiceProvider = Provider<LocalStorageService>((Ref ref) {
  _logLedgerProvider(
    'localStorageServiceProvider',
    'LocalStorageService 인스턴스 생성',
  );
  return LocalStorageService();
});

/// 지출내역 SQLite 서비스를 주입한다.
final expenseDatabaseServiceProvider = Provider<ExpenseDatabaseService>((
  Ref ref,
) {
  _logLedgerProvider(
    'expenseDatabaseServiceProvider',
    'ExpenseDatabaseService 인스턴스 생성',
  );
  return ExpenseDatabaseService();
});

/// 소득 SQLite 서비스를 주입한다.
final incomeDatabaseServiceProvider = Provider<IncomeDatabaseService>((
  Ref ref,
) {
  _logLedgerProvider(
    'incomeDatabaseServiceProvider',
    'IncomeDatabaseService 인스턴스 생성',
  );
  return IncomeDatabaseService();
});

/// 고정지출 SQLite 서비스를 주입한다.
final fixedExpenseDatabaseServiceProvider =
    Provider<FixedExpenseDatabaseService>((Ref ref) {
      _logLedgerProvider(
        'fixedExpenseDatabaseServiceProvider',
        'FixedExpenseDatabaseService 인스턴스 생성',
      );
      return FixedExpenseDatabaseService();
    });

/// 앱 전체 상태를 관리한다.
final ledgerProvider = AsyncNotifierProvider<LedgerNotifier, LedgerState>(
  LedgerNotifier.new,
);

DateTime _monthStart(DateTime month) {
  return DateTime(month.year, month.month, 1);
}

/// 기준일로부터 전월동기 기간 쿼리를 계산한다.
///
/// - 기준일이 해당 월의 마지막 날이면 전월 전체를 집계한다.
/// - 그 외에는 min(기준일, 전월의 마지막 날)까지 집계한다.
ExpenseRangeQuery computePrevSamePeriodQuery(DateTime referenceDate) {
  final int currentMonthLastDay = DateTime(
    referenceDate.year,
    referenceDate.month + 1,
    0,
  ).day;
  final bool isLastDay = referenceDate.day >= currentMonthLastDay;

  final int prevYear = referenceDate.month == 1
      ? referenceDate.year - 1
      : referenceDate.year;
  final int prevMonthNum = referenceDate.month == 1
      ? 12
      : referenceDate.month - 1;
  final int prevLastDay = DateTime(prevYear, prevMonthNum + 1, 0).day;

  final int prevEndDay = isLastDay
      ? prevLastDay
      : (referenceDate.day < prevLastDay ? referenceDate.day : prevLastDay);

  return ExpenseRangeQuery(
    start: DateTime(prevYear, prevMonthNum, 1),
    endInclusive: DateTime(prevYear, prevMonthNum, prevEndDay),
  );
}

/// 기간 조회 파라미터를 담는 값 객체다.
class ExpenseRangeQuery {
  const ExpenseRangeQuery({required this.start, required this.endInclusive});

  final DateTime start;
  final DateTime endInclusive;

  DateTime get endExclusive =>
      DateTime(endInclusive.year, endInclusive.month, endInclusive.day + 1);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ExpenseRangeQuery &&
        other.start == start &&
        other.endInclusive == endInclusive;
  }

  @override
  int get hashCode => Object.hash(start, endInclusive);
}

/// 선택 월의 지출내역을 DB에서 조회한다.
final monthlyExpensesProvider =
    FutureProvider.family<List<ExpenseEntry>, DateTime>((
      Ref ref,
      DateTime month,
    ) async {
      final service = ref.read(expenseDatabaseServiceProvider);
      return service.loadExpensesByMonth(_monthStart(month));
    });

/// 선택 기간의 지출내역을 DB에서 조회한다.
final rangeExpensesProvider =
    FutureProvider.family<List<ExpenseEntry>, ExpenseRangeQuery>((
      Ref ref,
      ExpenseRangeQuery query,
    ) async {
      final service = ref.read(expenseDatabaseServiceProvider);
      return service.loadExpensesByRange(
        start: query.start,
        endExclusive: query.endExclusive,
      );
    });

/// 선택 월의 소득내역을 DB에서 조회한다.
final monthlyIncomesProvider =
    FutureProvider.family<List<IncomeEntry>, DateTime>((
      Ref ref,
      DateTime month,
    ) async {
      final service = ref.read(incomeDatabaseServiceProvider);
      return service.loadIncomesByMonth(_monthStart(month));
    });

/// 선택 월의 고정지출 목록을 DB에서 조회한다.
final monthlyFixedExpensesProvider =
    FutureProvider.family<List<FixedExpense>, DateTime>((
      Ref ref,
      DateTime month,
    ) async {
      final service = ref.read(fixedExpenseDatabaseServiceProvider);
      return service.loadFixedExpensesByMonth(_monthStart(month));
    });

/// 앱 가계부 상태를 관리하는 노티파이어다.
class LedgerNotifier extends AsyncNotifier<LedgerState> {
  /// 앱 설정 저장소 서비스를 반환한다.
  LocalStorageService get _localStorageService {
    _logLedgerProvider('_localStorageService', 'LocalStorageService 조회');
    return ref.read(localStorageServiceProvider);
  }

  /// 지출내역 데이터베이스 서비스를 반환한다.
  ExpenseDatabaseService get _expenseDatabaseService {
    _logLedgerProvider('_expenseDatabaseService', 'ExpenseDatabaseService 조회');
    return ref.read(expenseDatabaseServiceProvider);
  }

  IncomeDatabaseService get _incomeDatabaseService {
    _logLedgerProvider('_incomeDatabaseService', 'IncomeDatabaseService 조회');
    return ref.read(incomeDatabaseServiceProvider);
  }

  FixedExpenseDatabaseService get _fixedExpenseDatabaseService {
    _logLedgerProvider(
      '_fixedExpenseDatabaseService',
      'FixedExpenseDatabaseService 조회',
    );
    return ref.read(fixedExpenseDatabaseServiceProvider);
  }

  @override
  Future<LedgerState> build() async {
    _logLedgerProvider('build', '앱 상태 초기 로드 시작');
    final loadedState = await _localStorageService.loadState();
    final systemTagStrings = await LocalizationService().loadStrings(
      loadedState.settings.localeCode,
    );
    final settingsState = loadedState.localizeSystemMetadataTags(
      systemTagStrings,
    );
    await _localStorageService.saveState(settingsState);
    final nowMonth = DateTime.now();
    final prevQuery = computePrevSamePeriodQuery(nowMonth);

    // 3개 쿼리를 병렬로 실행해 초기 로드 시간을 단축한다.
    _logLedgerProvider('build', 'DB 병렬 쿼리 시작');
    final rawResults = await Future.wait(<Future<dynamic>>[
      _expenseDatabaseService.loadExpensesByMonth(nowMonth),
      _fixedExpenseDatabaseService.loadAllFixedExpenses(),
      _expenseDatabaseService.loadExpensesByRange(
        start: prevQuery.start,
        endExclusive: prevQuery.endExclusive,
      ),
    ]);
    _logLedgerProvider('build', 'DB 병렬 쿼리 완료');

    var currentMonthExpenses = rawResults[0] as List<ExpenseEntry>;
    var allFixedExpenses = rawResults[1] as List<FixedExpense>;
    var prevPeriodExpenses = rawResults[2] as List<ExpenseEntry>;

    // 기존 shared_preferences에 남아 있는 구버전 지출내역이 있으면 SQLite로 1회 마이그레이션한다.
    if (currentMonthExpenses.isEmpty && settingsState.expenses.isNotEmpty) {
      _logLedgerProvider('build', '구버전 지출내역 SQLite 마이그레이션 수행');
      await _expenseDatabaseService.upsertExpenses(settingsState.expenses);
      currentMonthExpenses = await _expenseDatabaseService.loadExpensesByMonth(
        nowMonth,
      );
    }

    if (allFixedExpenses.isEmpty && settingsState.fixedExpenses.isNotEmpty) {
      _logLedgerProvider('build', '구버전 고정지출 SQLite 마이그레이션 수행');
      await _fixedExpenseDatabaseService.upsertFixedExpenses(
        settingsState.fixedExpenses,
      );
      allFixedExpenses = await _fixedExpenseDatabaseService
          .loadAllFixedExpenses();
    }

    // 기존 `점심/식당명` 형식은 식사 유형 코드와 설명으로 자동 분리한다.
    // 이미 diningOccasionCode가 있는 데이터는 건드리지 않으므로 반복 실행해도 안전하다.
    final migratedDiningCount = await _expenseDatabaseService
        .migrateLegacyDiningDescriptions();
    if (migratedDiningCount > 0) {
      _logLedgerProvider(
        'build',
        '기존 외식 기록 자동 마이그레이션 완료($migratedDiningCount건)',
      );
      currentMonthExpenses = await _expenseDatabaseService.loadExpensesByMonth(
        nowMonth,
      );
      prevPeriodExpenses = await _expenseDatabaseService.loadExpensesByRange(
        start: prevQuery.start,
        endExclusive: prevQuery.endExclusive,
      );
    }

    _logLedgerProvider('build', '초기 상태 반환(이번 달 지출내역 + 전월 동기 데이터 적용)');
    return settingsState.copyWith(
      expenses: currentMonthExpenses,
      fixedExpenses: allFixedExpenses,
      prevPeriodExpenses: prevPeriodExpenses,
    );
  }

  /// 현재 메모리 상태를 로컬 저장소에 저장한다.
  Future<void> persistCurrentState() async {
    _logLedgerProvider('persistCurrentState', '현재 상태 저장 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('persistCurrentState', '저장 스킵(current == null)');
      return;
    }

    await _localStorageService.saveState(current);
    _logLedgerProvider('persistCurrentState', '현재 상태 저장 완료');
  }

  /// 초기 설정을 완료한다.
  Future<void> completeSetup({
    required String name,
    required int age,
    required int monthlyBudget,
    required String localeCode,
  }) async {
    _logLedgerProvider('completeSetup', '초기 설정 완료 처리 시작');
    final current = state.asData?.value ?? LedgerState.initial();
    final setupState = current.completeSetup(
      profile: UserProfile(name: name.trim(), age: age),
      monthlyBudget: monthlyBudget,
      localeCode: localeCode,
      currencyUnit: _defaultCurrencyUnitByLocale(localeCode),
    );
    final strings = await LocalizationService().loadStrings(localeCode);
    final next = setupState.localizeSystemMetadataTags(strings);
    await _commit(next);
    _logLedgerProvider('completeSetup', '초기 설정 완료 처리 종료');
  }

  /// 앱 언어를 변경한다.
  Future<void> changeLocale(String localeCode) async {
    _logLedgerProvider('changeLocale', '앱 언어 변경 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('changeLocale', '언어 변경 스킵(current == null)');
      return;
    }

    final strings = await LocalizationService().loadStrings(localeCode);
    final next = current
        .changeLocale(localeCode)
        .localizeSystemMetadataTags(strings);
    await _commit(next);
    _logLedgerProvider('changeLocale', '앱 언어 변경 완료');
  }

  /// 통화 단위를 변경한다.
  Future<void> changeCurrencyUnit(String currencyUnit) async {
    _logLedgerProvider('changeCurrencyUnit', '통화 단위 변경 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('changeCurrencyUnit', '통화 단위 변경 스킵(current == null)');
      return;
    }

    await _commit(current.changeCurrencyUnit(currencyUnit));
    _logLedgerProvider('changeCurrencyUnit', '통화 단위 변경 완료');
  }

  /// 사용자 프로필 정보를 변경한다.
  Future<void> updateUserProfile({
    required String name,
    required int age,
  }) async {
    _logLedgerProvider('updateUserProfile', '사용자 프로필 변경 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('updateUserProfile', '프로필 변경 스킵(current == null)');
      return;
    }

    await _commit(current.updateUserProfile(name: name, age: age));
    _logLedgerProvider('updateUserProfile', '사용자 프로필 변경 완료');
  }

  /// 월 예산을 변경한다.
  Future<void> changeMonthlyBudget(int budget) async {
    _logLedgerProvider('changeMonthlyBudget', '월 예산 변경 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('changeMonthlyBudget', '예산 변경 스킵(current == null)');
      return;
    }

    await _commit(current.changeMonthlyBudget(budget));
    _logLedgerProvider('changeMonthlyBudget', '월 예산 변경 완료');
  }

  /// 지출 기록을 추가한다.
  Future<void> addExpense(ExpenseEntry entry) async {
    _logLedgerProvider('addExpense', '소비내역 기록 추가 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('addExpense', '추가 스킵(current == null)');
      return;
    }

    await _expenseDatabaseService.upsertExpense(entry);
    await _commit(current.addExpense(entry));
    _logLedgerProvider('addExpense', '소비내역 기록 추가 완료');
  }

  /// 지출 기록을 수정한다.
  Future<void> updateExpense(ExpenseEntry entry) async {
    _logLedgerProvider('updateExpense', '소비내역 기록 수정 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('updateExpense', '수정 스킵(current == null)');
      return;
    }

    await _expenseDatabaseService.upsertExpense(entry);
    await _commit(current.updateExpense(entry));
    _logLedgerProvider('updateExpense', '소비내역 기록 수정 완료');
  }

  /// 지출 기록을 삭제한다.
  Future<void> deleteExpense(String id) async {
    _logLedgerProvider('deleteExpense', '소비내역 기록 삭제 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('deleteExpense', '삭제 스킵(current == null)');
      return;
    }

    await _expenseDatabaseService.deleteExpense(id);
    await _commit(current.deleteExpense(id));
    _logLedgerProvider('deleteExpense', '소비내역 기록 삭제 완료');
  }

  Future<int> countLegacyDiningDescriptions() {
    return _expenseDatabaseService.countLegacyDiningDescriptions();
  }

  Future<int> migrateLegacyDiningDescriptions() async {
    final count = await _expenseDatabaseService
        .migrateLegacyDiningDescriptions();
    if (count > 0) {
      ref.invalidateSelf();
    }
    return count;
  }

  /// 소득 기록을 추가한다.
  Future<void> addIncome(IncomeEntry entry) async {
    _logLedgerProvider('addIncome', '소득 기록 추가 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('addIncome', '추가 스킵(current == null)');
      return;
    }

    await _incomeDatabaseService.upsertIncome(entry);
    _logLedgerProvider('addIncome', '소득 기록 추가 완료');
  }

  /// 소득 기록을 수정한다.
  Future<void> updateIncome(IncomeEntry entry) async {
    _logLedgerProvider('updateIncome', '소득 기록 수정 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('updateIncome', '수정 스킵(current == null)');
      return;
    }

    await _incomeDatabaseService.upsertIncome(entry);
    _logLedgerProvider('updateIncome', '소득 기록 수정 완료');
  }

  /// 소득 기록을 삭제한다.
  Future<void> deleteIncome(int id) async {
    _logLedgerProvider('deleteIncome', '소득 기록 삭제 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('deleteIncome', '삭제 스킵(current == null)');
      return;
    }

    await _incomeDatabaseService.deleteIncome(id);
    _logLedgerProvider('deleteIncome', '소득 기록 삭제 완료');
  }

  /// 고정지출을 추가한다.
  Future<void> addFixedExpense(FixedExpense item) async {
    _logLedgerProvider('addFixedExpense', '고정지출 기록 추가 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('addFixedExpense', '추가 스킵(current == null)');
      return;
    }

    await _fixedExpenseDatabaseService.upsertFixedExpense(item);
    await _commit(current.addFixedExpense(item));
    _logLedgerProvider('addFixedExpense', '고정지출 기록 추가 완료');
  }

  /// 고정지출을 수정한다.
  Future<void> updateFixedExpense(FixedExpense item) async {
    _logLedgerProvider('updateFixedExpense', '고정지출 기록 수정 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('updateFixedExpense', '수정 스킵(current == null)');
      return;
    }

    await _fixedExpenseDatabaseService.upsertFixedExpense(item);
    await _commit(current.updateFixedExpense(item));
    _logLedgerProvider('updateFixedExpense', '고정지출 기록 수정 완료');
  }

  /// 고정지출을 삭제한다.
  Future<void> deleteFixedExpense(String id) async {
    _logLedgerProvider('deleteFixedExpense', '고정지출 기록 삭제 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('deleteFixedExpense', '삭제 스킵(current == null)');
      return;
    }

    await _fixedExpenseDatabaseService.deleteFixedExpense(id);
    await _commit(current.deleteFixedExpense(id));
    _logLedgerProvider('deleteFixedExpense', '고정지출 기록 삭제 완료');
  }

  /// 메타데이터 태그를 추가한다.
  Future<void> addMetadataTag(MetadataTag tag) async {
    _logLedgerProvider('addMetadataTag', '메타데이터 태그 추가 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('addMetadataTag', '추가 스킵(current == null)');
      return;
    }

    await _commit(current.addMetadataTag(tag));
    _logLedgerProvider('addMetadataTag', '메타데이터 태그 추가 완료');
  }

  /// 메타데이터 태그를 교체 후 삭제한다.
  Future<void> replaceAndDeleteTag({
    required MetadataTagType type,
    required String targetCode,
    required String replacementCode,
  }) async {
    _logLedgerProvider('replaceAndDeleteTag', '메타데이터 태그 교체/삭제 시작');
    final current = state.asData?.value;
    if (current == null) {
      _logLedgerProvider('replaceAndDeleteTag', '교체/삭제 스킵(current == null)');
      return;
    }
    if (systemMetadataTagLocalizationKeys[type]?.containsKey(targetCode) ??
        false) {
      _logLedgerProvider('replaceAndDeleteTag', '시스템 기본 태그 삭제 스킵');
      return;
    }

    final next = current.replaceAndDeleteTag(
      type: type,
      targetCode: targetCode,
      replacementCode: replacementCode,
    );

    // 태그 코드 치환은 명시적 SQL UPDATE로 DB에도 반영한다.
    await _expenseDatabaseService.replaceExpenseTagCode(
      type: type,
      fromCode: targetCode,
      toCode: replacementCode,
    );
    await _fixedExpenseDatabaseService.replaceFixedExpenseTagCode(
      type: type,
      fromCode: targetCode,
      toCode: replacementCode,
    );
    await _commit(next);
    _logLedgerProvider('replaceAndDeleteTag', '메타데이터 태그 교체/삭제 완료');
  }

  /// 가져오기 데이터로 전체 DB를 교체하고 앱 상태를 새로 구성한다.
  Future<void> importAllData({
    required List<ExpenseEntry> expenses,
    required List<FixedExpense> fixedExpenses,
    required List<IncomeEntry> incomes,
    required LedgerState importedState,
  }) async {
    _logLedgerProvider('importAllData', '데이터 전체 가져오기 시작');

    await _expenseDatabaseService.deleteAllExpenses();
    await _fixedExpenseDatabaseService.deleteAllFixedExpenses();
    await _incomeDatabaseService.deleteAllIncomes();

    await _expenseDatabaseService.upsertExpenses(expenses);
    final migratedDiningCount = await _expenseDatabaseService
        .migrateLegacyDiningDescriptions();
    _logLedgerProvider(
      'importAllData',
      '가져온 외식 기록 자동 마이그레이션 완료($migratedDiningCount건)',
    );
    await _fixedExpenseDatabaseService.upsertFixedExpenses(fixedExpenses);
    await _incomeDatabaseService.upsertIncomes(incomes);

    final nowMonth = DateTime.now();
    final currentMonthExpenses = await _expenseDatabaseService
        .loadExpensesByMonth(nowMonth);

    final prevQuery = computePrevSamePeriodQuery(nowMonth);
    final prevPeriodExpenses = await _expenseDatabaseService
        .loadExpensesByRange(
          start: prevQuery.start,
          endExclusive: prevQuery.endExclusive,
        );
    final strings = await LocalizationService().loadStrings(
      importedState.settings.localeCode,
    );
    final next = importedState
        .copyWith(
          expenses: currentMonthExpenses,
          fixedExpenses: fixedExpenses,
          prevPeriodExpenses: prevPeriodExpenses,
        )
        .localizeSystemMetadataTags(strings);
    await _commit(next);
    _logLedgerProvider('importAllData', '데이터 전체 가져오기 완료');
  }

  /// 상태를 저장 포함 방식으로 교체한다.
  Future<void> _commit(LedgerState next) async {
    _logLedgerProvider('_commit', '상태 반영 및 저장 시작');
    state = AsyncData(next);
    await _localStorageService.saveState(next);
    _logLedgerProvider('_commit', '상태 반영 및 저장 완료');
  }
}
