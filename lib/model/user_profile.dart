/// 사용자 기본 프로필을 표현한다.
class UserProfile {
  /// 사용자 프로필을 생성한다.
  const UserProfile({
    required this.name,
    this.email = '',
    this.birthDate,
    int age = 0,
  }) : _legacyAge = age;

  /// 사용자 이름을 보관한다.
  final String name;

  /// 사용자 이메일을 보관한다.
  final String email;

  /// 사용자 생년월일을 보관한다.
  final DateTime? birthDate;

  /// 생년월일 저장 이전 데이터와의 호환을 위한 기존 나이다.
  final int _legacyAge;

  /// 현재 날짜를 기준으로 계산한 만 나이를 반환한다.
  int get age => ageAt(DateTime.now());

  /// 주어진 날짜를 기준으로 만 나이를 계산한다.
  int ageAt(DateTime date) {
    final DateTime? birth = birthDate;
    if (birth == null) return _legacyAge;
    var calculated = date.year - birth.year;
    final bool beforeBirthday =
        date.month < birth.month ||
        (date.month == birth.month && date.day < birth.day);
    if (beforeBirthday) calculated--;
    return calculated < 0 ? 0 : calculated;
  }

  /// 기본값을 가진 사용자 프로필을 생성한다.
  factory UserProfile.empty() {
    return const UserProfile(name: '');
  }

  /// 현재 프로필의 수정본을 생성한다.
  UserProfile copyWith({
    String? name,
    String? email,
    DateTime? birthDate,
    int? age,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      birthDate: birthDate ?? this.birthDate,
      age: age ?? _legacyAge,
    );
  }

  /// 프로필이 설정 완료 상태인지 판별한다.
  bool get isConfigured =>
      name.trim().isNotEmpty && (birthDate != null || _legacyAge > 0);

  /// 프로필을 JSON 구조로 변환한다.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'email': email,
      'birthDate': birthDate?.toIso8601String(),
      // 구버전 앱 및 백업 파일 호환을 위해 계산된 나이도 유지한다.
      'age': age,
    };
  }

  /// JSON 구조에서 프로필을 복원한다.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final String? birthDateValue = json['birthDate'] as String?;
    return UserProfile(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      birthDate: birthDateValue == null
          ? null
          : DateTime.tryParse(birthDateValue),
      age: json['age'] as int? ?? 0,
    );
  }
}
