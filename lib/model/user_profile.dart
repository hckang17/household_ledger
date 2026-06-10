/// 사용자 기본 프로필을 표현한다.
class UserProfile {
  /// 사용자 프로필을 생성한다.
  const UserProfile({required this.name, required this.age});

  /// 사용자 이름을 보관한다.
  final String name;

  /// 사용자 나이를 보관한다.
  final int age;

  /// 기본값을 가진 사용자 프로필을 생성한다.
  factory UserProfile.empty() {
    return const UserProfile(name: '', age: 0);
  }

  /// 현재 프로필의 수정본을 생성한다.
  UserProfile copyWith({String? name, int? age}) {
    return UserProfile(name: name ?? this.name, age: age ?? this.age);
  }

  /// 프로필이 설정 완료 상태인지 판별한다.
  bool get isConfigured => name.trim().isNotEmpty && age > 0;

  /// 프로필을 JSON 구조로 변환한다.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'name': name, 'age': age};
  }

  /// JSON 구조에서 프로필을 복원한다.
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      age: json['age'] as int? ?? 0,
    );
  }
}
