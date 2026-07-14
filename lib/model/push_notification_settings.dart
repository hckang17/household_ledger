/// 앱에서 구분하는 알림 카테고리다.
enum PushNotificationCategory {
  daily('daily'),
  fixedExpense('fixedExpense'),
  salary('salary'),
  other('other');

  const PushNotificationCategory(this.code);

  final String code;

  static PushNotificationCategory? fromCode(String code) {
    for (final category in values) {
      if (category.code == code) return category;
    }
    return null;
  }
}

/// 전체 알림과 카테고리별 수신 여부를 보관한다.
class PushNotificationSettings {
  const PushNotificationSettings({
    this.enabled = false,
    this.salaryDay = 20,
    this.categoryValues = const <PushNotificationCategory, bool>{
      PushNotificationCategory.daily: true,
      PushNotificationCategory.fixedExpense: true,
      PushNotificationCategory.salary: true,
      PushNotificationCategory.other: true,
    },
  });

  final bool enabled;
  final int salaryDay;
  final Map<PushNotificationCategory, bool> categoryValues;

  bool isCategoryEnabled(PushNotificationCategory category) =>
      categoryValues[category] ?? true;

  PushNotificationSettings copyWith({
    bool? enabled,
    int? salaryDay,
    Map<PushNotificationCategory, bool>? categoryValues,
  }) {
    return PushNotificationSettings(
      enabled: enabled ?? this.enabled,
      salaryDay: (salaryDay ?? this.salaryDay).clamp(1, 28),
      categoryValues: Map<PushNotificationCategory, bool>.unmodifiable(
        categoryValues ?? this.categoryValues,
      ),
    );
  }

  PushNotificationSettings setCategory(
    PushNotificationCategory category,
    bool enabled,
  ) {
    return copyWith(
      categoryValues: <PushNotificationCategory, bool>{
        ...categoryValues,
        category: enabled,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'salaryDay': salaryDay,
      'categories': <String, bool>{
        for (final category in PushNotificationCategory.values)
          category.code: isCategoryEnabled(category),
      },
    };
  }

  factory PushNotificationSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PushNotificationSettings();
    final rawCategories = json['categories'] as Map<String, dynamic>?;
    final categories = <PushNotificationCategory, bool>{
      for (final category in PushNotificationCategory.values)
        category: rawCategories?[category.code] as bool? ?? true,
    };
    return PushNotificationSettings(
      enabled: json['enabled'] as bool? ?? false,
      salaryDay: (json['salaryDay'] as int? ?? 20).clamp(1, 28),
      categoryValues: Map<PushNotificationCategory, bool>.unmodifiable(
        categories,
      ),
    );
  }
}
