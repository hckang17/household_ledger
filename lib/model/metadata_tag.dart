/// 메타데이터 태그의 종류를 정의한다.
enum MetadataTagType { category, subcategory, diningOccasion, paymentMethod }

/// 메타데이터 태그 종류를 직렬화 가능한 문자열로 변환한다.
extension MetadataTagTypeX on MetadataTagType {
  /// 태그 종류를 저장용 문자열로 반환한다.
  String get code {
    switch (this) {
      case MetadataTagType.category:
        return 'category';
      case MetadataTagType.subcategory:
        return 'subcategory';
      case MetadataTagType.diningOccasion:
        return 'diningOccasion';
      case MetadataTagType.paymentMethod:
        return 'paymentMethod';
    }
  }

  /// 태그 종류의 화면 표시명을 반환한다.
  String get label {
    switch (this) {
      case MetadataTagType.category:
        return 'Category';
      case MetadataTagType.subcategory:
        return 'Subcategory';
      case MetadataTagType.diningOccasion:
        return 'Dining Occasion';
      case MetadataTagType.paymentMethod:
        return 'Payment Method';
    }
  }

  /// 문자열을 태그 종류로 변환한다.
  static MetadataTagType fromCode(String value) {
    switch (value) {
      case 'category':
        return MetadataTagType.category;
      case 'subcategory':
        return MetadataTagType.subcategory;
      case 'diningOccasion':
        return MetadataTagType.diningOccasion;
      case 'paymentMethod':
        return MetadataTagType.paymentMethod;
      default:
        throw ArgumentError('Unknown tag type: $value');
    }
  }
}

/// [List<MetadataTag>]에서 코드로 라벨을 조회하는 편의 메서드를 제공한다.
extension MetadataTagListX on List<MetadataTag> {
  /// [code]에 해당하는 태그의 [label]을 반환한다. 없으면 [code]를 그대로 반환한다.
  String labelFor(String code) {
    try {
      return firstWhere((MetadataTag t) => t.code == code).label;
    } catch (_) {
      return code;
    }
  }
}

/// 사용자가 관리하는 태그 데이터를 표현한다.
class MetadataTag {
  /// 태그를 생성한다.
  const MetadataTag({
    required this.type,
    required this.code,
    required this.label,
  });

  /// 태그의 분류 종류를 보관한다.
  final MetadataTagType type;

  /// 태그의 실제 저장 코드를 보관한다.
  final String code;

  /// 태그의 화면 표시명을 보관한다.
  final String label;

  /// 현재 태그의 수정본을 생성한다.
  MetadataTag copyWith({MetadataTagType? type, String? code, String? label}) {
    return MetadataTag(
      type: type ?? this.type,
      code: code ?? this.code,
      label: label ?? this.label,
    );
  }

  /// 태그를 JSON 구조로 변환한다.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'type': type.code, 'code': code, 'label': label};
  }

  /// JSON 구조에서 태그를 복원한다.
  factory MetadataTag.fromJson(Map<String, dynamic> json) {
    return MetadataTag(
      type: MetadataTagTypeX.fromCode(json['type'] as String),
      code: json['code'] as String,
      label: json['label'] as String,
    );
  }
}
