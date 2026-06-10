/// 단일 소득 기록을 표현한다.
class IncomeEntry {
  const IncomeEntry({
    required this.id,
    required this.earnedAt,
    required this.amount,
    required this.description,
  });

  /// DB 자동 증가 식별자다. 신규 입력 시 null일 수 있다.
  final int? id;

  /// 소득이 발생한 시각이다.
  final DateTime earnedAt;

  /// 소득 금액이다.
  final int amount;

  /// 소득 내용을 보관한다(최대 40자).
  final String description;

  factory IncomeEntry.create({
    int? id,
    required DateTime earnedAt,
    required int amount,
    required String description,
  }) {
    return IncomeEntry(
      id: id,
      earnedAt: _normalizeDate(earnedAt),
      amount: amount,
      description: _limitLength(description, 40),
    );
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
  }

  static String _limitLength(String value, int maxLength) {
    final sanitized = value.trim();
    if (sanitized.length <= maxLength) {
      return sanitized;
    }
    return sanitized.substring(0, maxLength);
  }

  IncomeEntry copyWith({
    int? id,
    DateTime? earnedAt,
    int? amount,
    String? description,
  }) {
    return IncomeEntry.create(
      id: id ?? this.id,
      earnedAt: earnedAt ?? this.earnedAt,
      amount: amount ?? this.amount,
      description: description ?? this.description,
    );
  }
}
