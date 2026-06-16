/// 월 고정지출 항목을 표현한다.
class FixedExpense {
  /// 고정지출 항목을 생성한다.
  const FixedExpense({
    required this.id,
    required this.appliedAt,
    required this.categoryCode,
    required this.paymentMethodCode,
    required this.description,
    required this.amount,
    required this.note,
  });

  /// 고정지출 고유 식별자를 보관한다.
  final String id;

  /// 고정지출 적용 월을 보관한다.
  final DateTime appliedAt;

  /// 대분류 코드를 보관한다.
  final String categoryCode;

  /// 결제수단 코드를 보관한다.
  final String paymentMethodCode;

  /// 지출 내용을 보관한다.
  final String description;

  /// 지출 금액을 보관한다.
  final int amount;

  /// 비고를 보관한다.
  final String note;

  /// 입력값을 정규화한 고정지출을 생성한다.
  factory FixedExpense.create({
    String? id,
    DateTime? appliedAt,
    required String categoryCode,
    String paymentMethodCode = '_s',
    required String description,
    required int amount,
    String note = '',
  }) {
    final now = DateTime.now();
    final normalizedAppliedAt = DateTime(
      (appliedAt ?? now).year,
      (appliedAt ?? now).month,
      1,
    );
    return FixedExpense(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      appliedAt: normalizedAppliedAt,
      categoryCode: categoryCode.trim().isEmpty ? 'F' : categoryCode.trim(),
      paymentMethodCode: paymentMethodCode.trim().isEmpty
          ? '_s'
          : paymentMethodCode.trim(),
      description: description.trim().substring(
        0,
        description.trim().length > 20 ? 20 : description.trim().length,
      ),
      amount: amount,
      note: note.trim().substring(
        0,
        note.trim().length > 20 ? 20 : note.trim().length,
      ),
    );
  }

  /// 현재 고정지출의 수정본을 생성한다.
  FixedExpense copyWith({
    String? id,
    DateTime? appliedAt,
    String? categoryCode,
    String? paymentMethodCode,
    String? description,
    int? amount,
    String? note,
  }) {
    return FixedExpense.create(
      id: id ?? this.id,
      appliedAt: appliedAt ?? this.appliedAt,
      categoryCode: categoryCode ?? this.categoryCode,
      paymentMethodCode: paymentMethodCode ?? this.paymentMethodCode,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      note: note ?? this.note,
    );
  }

  /// 고정지출을 JSON 구조로 변환한다.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'appliedAt': appliedAt.toIso8601String(),
      'categoryCode': categoryCode,
      'paymentMethodCode': paymentMethodCode,
      'description': description,
      'amount': amount,
      'note': note,
    };
  }

  /// JSON 구조에서 고정지출을 복원한다.
  factory FixedExpense.fromJson(Map<String, dynamic> json) {
    return FixedExpense.create(
      id: json['id'] as String?,
      appliedAt:
          DateTime.tryParse(json['appliedAt'] as String? ?? '') ??
          DateTime.now(),
      categoryCode: json['categoryCode'] as String? ?? 'F',
      paymentMethodCode: json['paymentMethodCode'] as String? ?? '_s',
      description: json['description'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      note: json['note'] as String? ?? '',
    );
  }
}
