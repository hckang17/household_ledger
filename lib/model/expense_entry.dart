import 'package:intl/intl.dart';

/// 단일 지출 기록을 표현한다.
class ExpenseEntry {
  /// 지출 기록을 생성한다.
  const ExpenseEntry({
    required this.id,
    required this.spentAt,
    required this.categoryCode,
    required this.subcategoryCode,
    required this.paymentMethodCode,
    required this.description,
    required this.amount,
    required this.note,
  });

  /// 지출 고유 식별자를 보관한다.
  final String id;

  /// 지출 발생 시각을 분 단위로 보관한다.
  final DateTime spentAt;

  /// 대분류 코드를 보관한다.
  final String categoryCode;

  /// 소분류 코드를 보관한다.
  final String subcategoryCode;

  /// 결제수단 코드를 보관한다.
  final String paymentMethodCode;

  /// 지출 내용을 보관한다.
  final String description;

  /// 지출 금액을 보관한다.
  final int amount;

  /// 비고를 보관한다.
  final String note;

  /// 입력값을 정규화한 지출 기록을 생성한다.
  factory ExpenseEntry.create({
    String? id,
    required DateTime spentAt,
    required String categoryCode,
    String subcategoryCode = '_',
    String paymentMethodCode = '_s',
    required String description,
    required int amount,
    String note = '',
  }) {
    return ExpenseEntry(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      spentAt: normalizeDate(spentAt),
      categoryCode: categoryCode.trim().isEmpty ? 'F' : categoryCode.trim(),
      subcategoryCode: subcategoryCode.trim().isEmpty
          ? '_'
          : subcategoryCode.trim(),
      paymentMethodCode: paymentMethodCode.trim().isEmpty
          ? '_s'
          : paymentMethodCode.trim(),
      description: _limitLength(description),
      amount: amount,
      note: _limitLength(note),
    );
  }

  /// 날짜를 분 단위까지만 보존하도록 정규화한다.
  static DateTime normalizeDate(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
  }

  /// 문자열 길이를 최대 20자로 제한한다.
  static String _limitLength(String value) {
    final sanitized = value.trim();
    if (sanitized.length <= 20) {
      return sanitized;
    }

    return sanitized.substring(0, 20);
  }

  /// 화면용 날짜 문자열을 반환한다.
  String get formattedDate => DateFormat('yyyy-MM-dd HH:mm').format(spentAt);

  /// 현재 지출 기록의 수정본을 생성한다.
  ExpenseEntry copyWith({
    String? id,
    DateTime? spentAt,
    String? categoryCode,
    String? subcategoryCode,
    String? paymentMethodCode,
    String? description,
    int? amount,
    String? note,
  }) {
    return ExpenseEntry.create(
      id: id ?? this.id,
      spentAt: spentAt ?? this.spentAt,
      categoryCode: categoryCode ?? this.categoryCode,
      subcategoryCode: subcategoryCode ?? this.subcategoryCode,
      paymentMethodCode: paymentMethodCode ?? this.paymentMethodCode,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      note: note ?? this.note,
    );
  }

  /// 지출 기록을 JSON 구조로 변환한다.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'spentAt': spentAt.toIso8601String(),
      'categoryCode': categoryCode,
      'subcategoryCode': subcategoryCode,
      'paymentMethodCode': paymentMethodCode,
      'description': description,
      'amount': amount,
      'note': note,
    };
  }

  /// JSON 구조에서 지출 기록을 복원한다.
  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry.create(
      id: json['id'] as String?,
      spentAt: DateTime.parse(json['spentAt'] as String),
      categoryCode: json['categoryCode'] as String? ?? 'F',
      subcategoryCode: json['subcategoryCode'] as String? ?? '_',
      paymentMethodCode: json['paymentMethodCode'] as String? ?? '_s',
      description: json['description'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      note: json['note'] as String? ?? '',
    );
  }
}
