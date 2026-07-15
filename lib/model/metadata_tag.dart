/// 메타데이터 태그의 종류를 정의한다.
enum MetadataTagType { category, subcategory, diningOccasion, paymentMethod }

/// 앱이 항상 제공하며 사용자가 수정하거나 삭제할 수 없는 태그의 언어팩 키다.
const Map<MetadataTagType, Map<String, String>>
systemMetadataTagLocalizationKeys = <MetadataTagType, Map<String, String>>{
  MetadataTagType.category: <String, String>{
    'C': 'systemTagCategoryCafe',
    'D': 'systemTagCategoryDailyGoodsClothing',
    'E': 'systemTagCategoryOther',
    'F': 'systemTagCategoryDining',
    'G': 'systemTagCategoryGroceries',
    'H': 'systemTagCategoryHealingHobby',
    'L': 'systemTagCategoryLiving',
    'S': 'systemTagCategorySports',
    'T': 'systemTagCategoryTransport',
    'X': 'systemTagCategoryCeremonialExpenses',
  },
  MetadataTagType.subcategory: <String, String>{
    '_': 'systemTagSubcategoryUsual',
    't': 'systemTagSubcategoryTravel',
  },
  MetadataTagType.diningOccasion: <String, String>{
    'breakfast': 'systemTagDiningBreakfast',
    'brunch': 'systemTagDiningBrunch',
    'lunch': 'systemTagDiningLunch',
    'snack': 'systemTagDiningSnack',
    'dinner': 'systemTagDiningDinner',
    'lateNight': 'systemTagDiningLateNight',
    'company': 'systemTagDiningCompany',
  },
  MetadataTagType.paymentMethod: <String, String>{
    '_c': 'systemTagPaymentCash',
    '_s': 'systemTagPaymentCreditCard',
  },
};

/// 지원 언어 전체에서 시스템 태그가 예약한 화면 표시명이다.
///
/// 현재 선택된 언어와 관계없이 같은 태그 종류에 아래 이름을 사용자 태그로
/// 등록할 수 없다. 언어팩을 추가할 때 해당 번역명도 함께 추가해야 한다.
const Map<MetadataTagType, Set<String>> systemMetadataTagReservedLabels =
    <MetadataTagType, Set<String>>{
      MetadataTagType.category: <String>{
        '카페',
        'カフェ',
        '일용품&의류',
        '日用品＆衣料',
        '기타',
        'その他',
        '외식비',
        '外食費',
        '식료품',
        '食料品',
        '힐링&취미',
        'ヒーリング＆趣味',
        '생활비',
        '生活費',
        '스포츠',
        'スポーツ',
        '교통비',
        '交通費',
        '경조사비',
        '慶弔費',
      },
      MetadataTagType.subcategory: <String>{'평상시', '普段', '여행', '旅行'},
      MetadataTagType.diningOccasion: <String>{
        '아침',
        '朝食',
        '브런치',
        'ブランチ',
        '점심',
        '昼食',
        '간식',
        '間食',
        '저녁',
        '夕食',
        '야식',
        '夜食',
        '회식',
        '会食',
      },
      MetadataTagType.paymentMethod: <String>{'현금', '現金', '신용카드', 'クレジットカード'},
    };

/// 사용자 태그에 내부 저장용 2문자 코드를 할당한다.
///
/// 시스템 기본 카테고리의 1문자 코드와 겹치지 않도록 영문 대문자와 숫자로
/// 구성된 2문자 코드를 태그 종류별로 탐색한다. 기존 사용자 데이터의 임의
/// 코드는 그대로 허용하되, 새 사용자 태그에는 이 생성 규칙을 적용한다.
abstract final class MetadataTagCodeGenerator {
  static const String _characters = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// 같은 태그 종류에서 현재 사용하지 않는 다음 사용자 코드를 반환한다.
  ///
  /// 가능한 2문자 코드가 모두 사용 중이면 `null`을 반환한다.
  static String? nextUserCode({
    required MetadataTagType type,
    required Iterable<MetadataTag> tags,
  }) {
    final usedCodes = tags
        .where((MetadataTag tag) => tag.type == type)
        .map((MetadataTag tag) => tag.code)
        .toSet();

    for (var first = 0; first < _characters.length; first++) {
      for (var second = 0; second < _characters.length; second++) {
        final code = '${_characters[first]}${_characters[second]}';
        if (!usedCodes.contains(code)) {
          return code;
        }
      }
    }
    return null;
  }
}

/// 사용자 태그 이름의 입력 검증 결과다.
enum MetadataTagLabelValidation { valid, empty, duplicate }

/// 사용자 태그 이름에 공통 검증 규칙을 적용한다.
abstract final class MetadataTagLabelValidator {
  /// 빈칸과 같은 태그 종류 안의 이름 중복을 검사한다.
  ///
  /// 수정 중인 태그의 [currentCode]는 중복 검사에서 제외한다.
  static MetadataTagLabelValidation validate({
    required MetadataTagType type,
    required String label,
    required Iterable<MetadataTag> tags,
    String? currentCode,
  }) {
    final normalizedLabel = label.trim().toLowerCase();
    if (normalizedLabel.isEmpty) {
      return MetadataTagLabelValidation.empty;
    }

    final matchesReservedSystemLabel =
        systemMetadataTagReservedLabels[type]?.any(
          (String reservedLabel) =>
              reservedLabel.trim().toLowerCase() == normalizedLabel,
        ) ??
        false;
    final matchesExistingLabel = tags.any(
      (MetadataTag tag) =>
          tag.type == type &&
          tag.code != currentCode &&
          tag.label.trim().toLowerCase() == normalizedLabel,
    );
    return matchesReservedSystemLabel || matchesExistingLabel
        ? MetadataTagLabelValidation.duplicate
        : MetadataTagLabelValidation.valid;
  }
}

/// 언어팩을 적용한 시스템 기본 태그 목록을 생성한다.
List<MetadataTag> localizedSystemMetadataTags(Map<String, String> strings) {
  return <MetadataTag>[
    for (final MapEntry<MetadataTagType, Map<String, String>> typeEntry
        in systemMetadataTagLocalizationKeys.entries)
      for (final MapEntry<String, String> tagEntry in typeEntry.value.entries)
        MetadataTag(
          type: typeEntry.key,
          code: tagEntry.key,
          label: strings[tagEntry.value] ?? tagEntry.key,
        ),
  ];
}

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

  /// 시스템에서 기본 제공하여 수정과 삭제가 제한되는 태그인지 반환한다.
  bool get isSystemDefault =>
      systemMetadataTagLocalizationKeys[type]?.containsKey(code) ?? false;

  /// 시스템 기본 태그에 대응하는 언어팩 키를 반환한다.
  String? get systemLocalizationKey =>
      systemMetadataTagLocalizationKeys[type]?[code];

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
