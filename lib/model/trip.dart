/// 사용자가 관리하는 하나의 여행 정보를 표현한다.
class Trip {
  /// 여행 정보를 생성한다.
  const Trip({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.budget,
    this.note = '',
    this.archivedAt,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int? budget;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  /// 입력값을 정규화한 여행 정보를 생성한다.
  factory Trip.create({
    String? id,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    int? budget,
    String note = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    final now = DateTime.now();
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);
    return Trip(
      id: id ?? now.microsecondsSinceEpoch.toString(),
      name: name.trim(),
      startDate: normalizedStart,
      endDate: normalizedEnd,
      budget: budget != null && budget > 0 ? budget : null,
      note: note.trim(),
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      archivedAt: archivedAt,
    );
  }

  bool get isArchived => archivedAt != null;

  Trip copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? budget,
    bool clearBudget = false,
    String? note,
    DateTime? updatedAt,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
  }) {
    return Trip.create(
      id: id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: clearBudget ? null : (budget ?? this.budget),
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'budget': budget,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'archivedAt': archivedAt?.toIso8601String(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip.create(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      budget: json['budget'] as int?,
      note: json['note'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      archivedAt: DateTime.tryParse(json['archivedAt'] as String? ?? ''),
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
