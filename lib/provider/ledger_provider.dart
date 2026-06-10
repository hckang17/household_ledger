import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/user_profile.dart';
import 'package:household_ledger/services/debugging_logger.dart';
import 'package:household_ledger/services/expense_database_service.dart';
import 'package:household_ledger/services/income_database_service.dart';
import 'package:household_ledger/services/local_storage_service.dart';

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

/// 앱 전체 상태를 관리한다.
final ledgerProvider = AsyncNotifierProvider<LedgerNotifier, LedgerState>(
  LedgerNotifier.new,
);

DateTime _monthStart(DateTime month) {
  return DateTime(month.year, month.month, 1);
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

  @override
  Future<LedgerState> build() async {
    _logLedgerProvider('build', '앱 상태 초기 로드 시작');
    final settingsState = await _localStorageService.loadState();
    final nowMonth = DateTime.now();
    final currentMonthExpenses = await _expenseDatabaseService
        .loadExpensesByMonth(nowMonth);

    // 기존 shared_preferences에 남아 있는 구버전 지출내역이 있으면 SQLite로 1회 마이그레이션한다.
    if (currentMonthExpenses.isEmpty && settingsState.expenses.isNotEmpty) {
      _logLedgerProvider('build', '구버전 지출내역 SQLite 마이그레이션 수행');
      await _expenseDatabaseService.upsertExpenses(settingsState.expenses);
      final migratedMonthExpenses = await _expenseDatabaseService
          .loadExpensesByMonth(nowMonth);
      _logLedgerProvider('build', '초기 상태 반환(마이그레이션 데이터 포함)');
      return settingsState.copyWith(expenses: migratedMonthExpenses);
    }

    _logLedgerProvider('build', '초기 상태 반환(이번 달 지출내역 적용)');
    return settingsState.copyWith(expenses: currentMonthExpenses);
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
    final next = current.completeSetup(
      profile: UserProfile(name: name.trim(), age: age),
      monthlyBudget: monthlyBudget,
      localeCode: localeCode,
      currencyUnit: _defaultCurrencyUnitByLocale(localeCode),
    );
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

    await _commit(current.changeLocale(localeCode));
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
    await _commit(next);
    _logLedgerProvider('replaceAndDeleteTag', '메타데이터 태그 교체/삭제 완료');
  }

  /// 상태를 저장 포함 방식으로 교체한다.
  Future<void> _commit(LedgerState next) async {
    _logLedgerProvider('_commit', '상태 반영 및 저장 시작');
    state = AsyncData(next);
    await _localStorageService.saveState(next);
    _logLedgerProvider('_commit', '상태 반영 및 저장 완료');
  }
}
