import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('생년월일을 기준으로 만 나이를 계산한다', () {
      final profile = UserProfile(
        name: 'tester',
        birthDate: DateTime(2000, 7, 20),
      );

      expect(profile.ageAt(DateTime(2026, 7, 19)), 25);
      expect(profile.ageAt(DateTime(2026, 7, 20)), 26);
    });

    test('기존 age 데이터는 생년월일 등록 전까지 유지한다', () {
      final profile = UserProfile.fromJson(<String, dynamic>{
        'name': 'legacy',
        'age': 31,
      });

      expect(profile.birthDate, isNull);
      expect(profile.age, 31);
    });

    test('이메일과 생년월일을 JSON으로 왕복한다', () {
      final original = UserProfile(
        name: 'tester',
        email: 'tester@example.com',
        birthDate: DateTime(1995, 3, 8),
      );

      final restored = UserProfile.fromJson(original.toJson());

      expect(restored.name, original.name);
      expect(restored.email, original.email);
      expect(restored.birthDate, original.birthDate);
    });
  });
}
