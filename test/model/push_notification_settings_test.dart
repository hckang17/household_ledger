import 'package:household_ledger/model/push_notification_settings.dart';
import 'package:test/test.dart';

void main() {
  group('PushNotificationSettings', () {
    test('기존 저장 데이터에는 안전한 기본값을 적용한다', () {
      final settings = PushNotificationSettings.fromJson(null);

      expect(settings.enabled, isFalse);
      expect(settings.salaryDay, 20);
      for (final category in PushNotificationCategory.values) {
        expect(settings.isCategoryEnabled(category), isTrue);
      }
    });

    test('전체 설정과 카테고리 설정을 JSON으로 왕복한다', () {
      final original = const PushNotificationSettings(
        enabled: true,
        salaryDay: 25,
      ).setCategory(PushNotificationCategory.daily, false);

      final restored = PushNotificationSettings.fromJson(original.toJson());

      expect(restored.enabled, isTrue);
      expect(restored.salaryDay, 25);
      expect(
        restored.isCategoryEnabled(PushNotificationCategory.daily),
        isFalse,
      );
      expect(
        restored.isCategoryEnabled(PushNotificationCategory.fixedExpense),
        isTrue,
      );
    });

    test('급여일은 모든 달에 존재하는 1일부터 28일 사이로 제한한다', () {
      expect(
        const PushNotificationSettings().copyWith(salaryDay: 0).salaryDay,
        1,
      );
      expect(
        const PushNotificationSettings().copyWith(salaryDay: 31).salaryDay,
        28,
      );
    });
  });
}
