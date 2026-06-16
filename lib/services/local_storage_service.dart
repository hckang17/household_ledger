import 'dart:convert';

import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/services/debugging_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 저장소 입출력을 담당한다.
class LocalStorageService {
  /// 로컬 저장소 키를 정의한다.
  static const String storageKey = 'household_ledger_state';
  static const String _logPrefix = '[LocalStorageService]';

  void _log(String methodName, String action) {
    logger.d('[local_storage_service.dart] $methodName ( $action )');
  }

  /// 로컬 저장소에서 앱 상태를 불러온다.
  Future<LedgerState> loadState() async {
    _log('loadState', '앱 상태 로드 시작');
    logger.d('$_logPrefix loadState() started. key=$storageKey');
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(storageKey);
    if (rawValue == null || rawValue.isEmpty) {
      logger.d(
        '$_logPrefix loadState() no saved state found. returning LedgerState.initial().',
      );
      _log('loadState', '저장된 상태 없음 -> 초기 상태 반환');
      return LedgerState.initial();
    }

    final decoded = jsonDecode(rawValue) as Map<String, dynamic>;
    final loadedState = LedgerState.fromJson(decoded);
    logger.d(
      '$_logPrefix loadState() completed. onboardingCompleted=${loadedState.settings.onboardingCompleted}, '
      'monthlyBudget=${loadedState.settings.monthlyBudget}, '
      'fixedExpenses=${loadedState.fixedExpenses.length}, '
      'metadataTags=${loadedState.metadataTags.length}.',
    );
    _log('loadState', '앱 상태 로드 완료');
    return loadedState;
  }

  /// 로컬 저장소에 앱 상태를 저장한다.
  Future<void> saveState(LedgerState state) async {
    _log('saveState', '앱 상태 저장 시작');
    logger.d('$_logPrefix saveState() started. key=$storageKey');
    final preferences = await SharedPreferences.getInstance();
    final json = state.toJson();

    // 핵심 데이터(지출내역, 고정지출)는 DB에 저장하므로 앱 설정 저장본에서 제외한다.
    json.remove('expenses');
    json.remove('fixedExpenses');
    await preferences.setString(storageKey, jsonEncode(json));
    logger.d(
      '$_logPrefix saveState() completed. onboardingCompleted=${state.settings.onboardingCompleted}, '
      'monthlyBudget=${state.settings.monthlyBudget}, '
      'fixedExpenses=${state.fixedExpenses.length}, '
      'metadataTags=${state.metadataTags.length}.',
    );
    _log('saveState', '앱 상태 저장 완료');
  }
}
