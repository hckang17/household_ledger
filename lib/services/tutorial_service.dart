import 'package:shared_preferences/shared_preferences.dart';

/// 튜토리얼 완료 상태와 버전을 SharedPreferences에 저장/조회한다.
class TutorialService {
  static const String completedKey = 'tutorial_completed';
  static const String versionKey = 'tutorial_version';

  /// 현재 앱 튜토리얼 버전. 앱 업데이트 시 값을 올리면 기존 사용자에게 다시 튜토리얼을 안내한다.
  static const int currentVersion = 1;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// 튜토리얼을 완료했고 버전이 현재와 같은 경우에만 true를 반환한다.
  Future<bool> isTutorialCompleted() async {
    final prefs = await _prefs;
    final completed = prefs.getBool(completedKey) ?? false;
    final version = prefs.getInt(versionKey) ?? 0;
    return completed && version >= currentVersion;
  }

  /// 튜토리얼 완료 상태를 저장한다. completed=true 시 버전도 함께 기록한다.
  Future<void> setCompleted({required bool completed}) async {
    final prefs = await _prefs;
    await prefs.setBool(completedKey, completed);
    if (completed) {
      await prefs.setInt(versionKey, currentVersion);
    }
  }

  /// 튜토리얼을 처음부터 다시 시작할 수 있도록 완료 플래그를 초기화한다.
  Future<void> resetTutorial() async {
    final prefs = await _prefs;
    await prefs.setBool(completedKey, false);
    await prefs.setInt(versionKey, 0);
  }

  /// CSV 가져오기 시 저장된 값을 복원한다.
  Future<void> restoreFromCsv({
    required bool completed,
    required int version,
  }) async {
    final prefs = await _prefs;
    await prefs.setBool(completedKey, completed);
    await prefs.setInt(versionKey, version);
  }

  /// CSV 내보내기 시 현재 값을 반환한다.
  Future<Map<String, String>> exportValues() async {
    final prefs = await _prefs;
    return {
      'tutorial_completed':
          (prefs.getBool(completedKey) ?? false).toString(),
      'tutorial_version': (prefs.getInt(versionKey) ?? 0).toString(),
    };
  }
}
