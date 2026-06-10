/// 앱 전역 설정을 표현한다.
class AppSettings {
  /// 앱 설정을 생성한다.
  const AppSettings({
    required this.localeCode,
    required this.currencyUnit,
    required this.monthlyBudget,
    required this.onboardingCompleted,
  });

  /// 현재 언어 코드를 보관한다.
  final String localeCode;

  /// 표시할 통화 단위를 보관한다.
  final String currencyUnit;

  /// 월별 사용 가능 예산을 보관한다.
  final int monthlyBudget;

  /// 초기 설정 완료 여부를 보관한다.
  final bool onboardingCompleted;

  /// 기본 앱 설정을 생성한다.
  factory AppSettings.initial() {
    return const AppSettings(
      localeCode: 'ko',
      currencyUnit: '₩',
      monthlyBudget: 0,
      onboardingCompleted: false,
    );
  }

  /// 현재 설정의 수정본을 생성한다.
  AppSettings copyWith({
    String? localeCode,
    String? currencyUnit,
    int? monthlyBudget,
    bool? onboardingCompleted,
  }) {
    return AppSettings(
      localeCode: localeCode ?? this.localeCode,
      currencyUnit: currencyUnit ?? this.currencyUnit,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  /// 설정을 JSON 구조로 변환한다.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'localeCode': localeCode,
      'currencyUnit': currencyUnit,
      'monthlyBudget': monthlyBudget,
      'onboardingCompleted': onboardingCompleted,
    };
  }

  /// JSON 구조에서 설정을 복원한다.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final localeCode = json['localeCode'] as String? ?? 'ko';
    final fallbackCurrencyUnit = localeCode == 'jp' ? '¥' : '₩';
    return AppSettings(
      localeCode: localeCode,
      currencyUnit: json['currencyUnit'] as String? ?? fallbackCurrencyUnit,
      monthlyBudget: json['monthlyBudget'] as int? ?? 0,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
    );
  }
}
