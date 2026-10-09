# Android AdMob 배너 연동

수입·분석·홈·소비 기록·고정지출의 모든 메인 탭 하단 내비게이션 위에 320×50 표준 배너 하나를 공유한다.
상하 여백은 각각 4로, 기본 광고 영역 높이는 58이다(Flutter 논리 픽셀).
개인정보 설정 버튼이 필요한 경우 버튼 높이가 별도로 추가된다.
가용 폭이 320보다 작으면 광고를 자르거나 축소하지 않고 요청하지 않는다.
IndexedStack 내부에 광고를 넣지 않아 숨은 탭에서 중복 요청하지 않는다.
튜토리얼과 키보드 입력 중에는 배너를 제거한다. 폭 또는 방향이 바뀌면 광고를
해제하고 가용 폭을 확인해 다시 요청한다. 로드 실패 시 광고 공간은 접히며 기록 기능은 유지된다.

## ID와 지원 범위

- Android 앱 ID: `ca-app-pub-2692116402537120~5454954264`
- 메인 탭 공용 배너 ID: `ca-app-pub-2692116402537120/2562704214`
- 앱 ID는 `android/app/src/main/AndroidManifest.xml`, 배너 ID는
  `lib/services/ads/mobile_ads_service.dart`에서 관리한다.
- `google_mobile_ads`는 Android/iOS용 플러그인이다. 현재 앱의 광고 구현은
  Android만 활성화한다. Windows/Web 및 별도 iOS 앱 ID가 없는 iOS는 요청하지 않는다.
- 광고 요청에는 가계부 금액, 메모, 프로필, 태그를 전달하지 않는다.

## 테스트

디버그/프로파일 빌드는 Google 적응형 배너 테스트 ID를 사용한다. 릴리즈에서
테스트하려면 `flutter build apk --release --dart-define=ADMOB_TEST_ADS=true`로 빌드한다.
이 옵션이 없는 릴리즈는 등록된 운영 배너 ID를 사용한다.

Android 기기에서 모든 메인 탭의 테스트 광고 및 탭 전환 시 배너 재사용, 회전,
작은 화면, 마지막 기록과 추가 버튼, 입력 키보드, 오프라인, 동의 변경을 확인한다.
운영 광고를 직접 클릭하지 않는다. Windows 실행 시 광고 플러그인 호출이 없어야 한다.

## AdMob 콘솔과 출시 작업

UMP로 앱 세션마다 동의 상태를 갱신하고 필요한 폼을 표시한 뒤 `canRequestAds()`가
허용할 때만 광고 SDK 초기화와 요청을 진행한다. 동의 선택 변경이 필요한 경우
배너 로드 성공 여부와 관계없이 하단에 개인정보 설정 버튼을 표시한다.
동의 갱신 실패 시 UMP가 허용한 기존 동의만 사용한다.

콘솔의 **개인정보 보호 및 메시지**에서 대상 지역 메시지를 설정·게시해야 한다.
코드 연동만으로 계정 인증, 앱 심사, app-ads.txt 확인이 완료되지는 않는다.
출시 전 개인정보처리방침과 Play 데이터 보안·광고 포함 신고를 실제 SDK 동작에
맞춰 갱신하고 앱 확인 및 광고 게재 상태를 점검한다.

공식 문서:
- https://developers.google.com/admob/flutter/quick-start
- https://developers.google.com/admob/flutter/banner
- https://developers.google.com/admob/flutter/privacy
