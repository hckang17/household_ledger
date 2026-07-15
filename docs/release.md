# Google Play 출시 가이드

> 기준일: 2026-07-15  
> 대상: Flutter 기반 오프라인 가계부 앱  
> 전제: Google Play Console 개발자 계정 등록 완료

이 문서는 이 저장소의 현재 상태를 기준으로, Google Play에 첫 버전을 출시하기 위해 지금부터 해야 할 일을 순서대로 정리한 체크리스트다. Google Play 정책과 콘솔 화면은 변경될 수 있으므로 실제 제출 직전에는 문서 마지막의 공식 링크와 Play Console의 최신 안내를 다시 확인한다.

## 0. 현재 상태와 출시 차단 요소

저장소를 확인한 결과, 앱 기능 개발과 별개로 아래 항목은 첫 AAB 업로드 전에 반드시 처리해야 한다.

| 우선순위 | 현재 상태 | 해야 할 일 |
|---|---|---|
| 필수 | `applicationId`와 `namespace`가 `com.example.household_ledger` | 소유한 고유 패키지명으로 변경한다. 예: `com.yourbrand.householdledger` |
| 필수 | release 빌드가 `debug` signing config 사용 | 업로드 키를 만들고 release signing config를 분리한다. 디버그 키로는 Play 출시가 불가능하다. |
| 필수 | 개인정보처리방침 없음 | 공개 HTTPS 웹페이지를 만들고 앱 내부에도 링크 또는 본문을 제공한다. PDF, 비공개 문서, 수정 가능한 공개 문서는 피한다. |
| 필수 | Play Store용 소개 문구·스크린샷·feature graphic 없음 | 한국어/일본어 스토어 등록정보와 그래픽을 준비한다. |
| 확인 | `version: 1.0.0+1` | 첫 출시 번호로 사용할 수 있으나, 이미 같은 `versionCode`를 업로드한 적이 있다면 `+2` 이상으로 올린다. |
| 양호 | `compileSdk = 36`, 현재 Flutter 기본 `targetSdkVersion = 36` | 현재 신규 앱 최소 요건인 API 35 이상을 만족한다. 제출 시 Play Console 경고로 다시 확인한다. |
| 양호 | 프로덕션 manifest에 별도 민감 권한 없음 | 최종 AAB의 병합 manifest와 Data safety 답변이 일치하는지 재확인한다. |
| 양호 | 원본 로고 `assets/image/Houseledger_logo.png`가 1024×1024 | 런처 아이콘과 별도로 Play Store용 512×512 PNG를 제작할 수 있다. |

패키지명은 첫 artifact를 Play Console에 올린 뒤에는 사실상 앱의 영구 식별자가 된다. 임시 패키지명으로 먼저 업로드하지 않는다.

## 1. 출시 범위 결정

- [ ] 앱 이름을 확정한다. 현재 Android 표시 이름은 한국어 `가계부`, 일본어 `家計簿`다.
- [ ] 고유 패키지명을 확정한다. 소유한 도메인이 있으면 역도메인 형식을 권장한다.
- [ ] 첫 출시 국가를 정한다. 현재 지원 언어와 통화를 고려하면 한국·일본부터 시작하는 편이 관리하기 쉽다.
- [ ] 가격을 `무료`로 할지 확정한다. 현재 광고, 인앱 상품, 구독 기능은 없다.
- [ ] 대상 사용자를 성인 중심으로 정한다. 특별히 아동을 대상으로 설계한 앱이 아니라면 아동 연령대를 마케팅 대상으로 선택하지 않는다.
- [ ] 지원 이메일 주소와 개인정보 문의 창구를 준비한다.

## 2. Android 출시 설정

### 2.1 패키지명 변경

- [ ] `android/app/build.gradle.kts`의 `namespace`와 `applicationId`를 새 패키지명으로 변경한다.
- [ ] `android/app/src/main/kotlin/com/example/household_ledger/MainActivity.kt`의 package 선언과 폴더 경로를 함께 변경한다.
- [ ] `com.example...`가 남아 있지 않은지 검색한다.
- [ ] 변경 후 기존 설치본과 별개의 앱으로 설치되는 것이 의도한 결과인지 확인한다.

```powershell
rg -n "com\.example\.household_ledger|com/example/household_ledger" android lib
```

### 2.2 앱 이름과 아이콘 확인

- [ ] `android/app/src/main/res/values/strings.xml`의 한국어 이름을 확인한다.
- [ ] `android/app/src/main/res/values-ja/strings.xml`의 일본어 이름을 확인한다.
- [ ] adaptive icon을 적용하고 밝은/어두운 배경 및 여러 런처에서 잘리지 않는지 확인한다.
- [ ] 필요하면 아래 명령으로 런처 아이콘을 다시 생성한다.

```powershell
flutter pub run flutter_launcher_icons
```

### 2.3 업로드 키와 release 서명 설정

Google Play 신규 앱은 Play App Signing을 사용한다. 로컬에서는 업로드 키로 AAB에 서명하고, Google Play가 배포용 APK를 앱 서명 키로 다시 서명한다.

- [ ] 장기 보관할 업로드 keystore(`.jks`)를 생성한다.
- [ ] keystore 파일과 암호를 소스 저장소 밖의 안전한 위치 두 곳 이상에 백업한다.
- [ ] `android/key.properties` 같은 별도 파일에서 암호와 키 경로를 읽도록 설정한다.
- [ ] keystore 및 `key.properties`가 `.gitignore`에 포함됐는지 확인한다.
- [ ] `android/app/build.gradle.kts`의 release build가 `signingConfigs.getByName("debug")`를 사용하지 않도록 바꾼다.
- [ ] Play Console 첫 업로드 과정에서 Play App Signing에 등록한다.

예시 명령은 다음과 같다. 별칭과 유효기간은 프로젝트 정책에 맞게 정한다.

```powershell
keytool -genkeypair -v -keystore household-ledger-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

키 파일이나 암호를 Git에 커밋하지 않는다. 업로드 키를 잃으면 재설정 절차가 필요하고, 백업과 복구 연락처를 미리 정해 두는 편이 안전하다.

### 2.4 버전과 빌드 번호

Flutter의 `version: 1.0.0+1`은 Android에서 다음과 같이 사용된다.

- `1.0.0`: 사용자에게 보이는 `versionName`
- `1`: Play가 업데이트 순서를 판별하는 `versionCode`

Play에 업로드할 때마다 `versionCode`는 이전 업로드보다 반드시 커야 한다. 재심사나 테스트 트랙용 새 빌드도 동일하다.

## 3. 개인정보와 정책 준비

### 3.1 이 앱의 데이터 흐름 정리

현재 코드 기준으로 확인되는 주요 흐름은 다음과 같다.

- 지출·수입·고정지출과 설정은 SQLite 또는 SharedPreferences에 로컬 저장된다.
- 백업 CSV, PNG, PDF를 만들고 사용자가 시스템 공유 화면을 통해 다른 앱으로 전달할 수 있다.
- 파일 가져오기와 열기를 위해 사용자가 직접 파일을 선택한다.
- 광고, 분석 SDK, 로그인, 자체 서버 전송 기능은 현재 의존성과 프로덕션 manifest에서 확인되지 않는다.
- 앱 설명상 내보내기 서명에 이메일 주소와 인증 키를 사용할 수 있으므로, 해당 값의 저장 위치·보존 기간·내보내기 파일 포함 여부를 구현과 함께 최종 확인해야 한다.

위 내용은 현재 저장소에 대한 판단이다. 제출용 AAB에 포함된 모든 서드파티 SDK와 병합 manifest를 기준으로 최종 답변해야 한다.

### 3.2 개인정보처리방침

모든 앱은 개인정보처리방침이 필요하다. 다음 내용을 포함한 공개 HTTPS 페이지를 만든다.

- [ ] 앱 이름과 Play Store에 표시되는 개발자/사업자명
- [ ] 개인정보 문의 이메일 또는 문의 방법
- [ ] 앱이 다루는 정보: 가계 기록, 메모, 이메일/인증 키(실제 사용 방식에 맞게 수정)
- [ ] 데이터가 기기 내부에 저장된다는 설명
- [ ] 사용자가 공유·백업을 선택했을 때 외부 앱 또는 저장소로 전달될 수 있다는 설명
- [ ] 광고·분석·자체 서버 수집 여부
- [ ] 보관 기간과 삭제 방법: 앱 내 전체 삭제, 앱 삭제, 백업 파일 직접 삭제 등
- [ ] 제3자 제공 및 처리 위탁 여부
- [ ] 정책 시행일과 변경 고지 방법

Play Console에는 공개 접근 가능하고 지역 제한이 없는 URL을 입력한다. 앱 내부에서는 설정 또는 저작권/라이선스 화면에 같은 정책으로 가는 링크나 정책 본문을 제공한다.

### 3.3 Data safety 작성 방향

Play Console의 `Policy and programs > App content > Data safety`를 작성한다.

현재 구현처럼 데이터가 기기 밖의 개발자 서버로 전송되지 않는다면 “개발자가 수집하거나 공유하는 데이터 없음”으로 답할 가능성이 높다. 사용자가 명시적으로 실행한 파일 공유는 Google의 정의상 예외가 될 수 있지만, 다음을 확인한 후 확정한다.

- [ ] 실제 네트워크 요청이 없는가?
- [ ] 포함된 SDK가 진단, 사용량, 기기 식별자 등을 전송하지 않는가?
- [ ] 인쇄·파일 열기·공유 플러그인의 최종 Android manifest와 동작이 선언과 일치하는가?
- [ ] 사용자가 공유한 파일에 어떤 개인정보와 금융 기록이 들어가는지 개인정보처리방침에 설명했는가?

로컬에서 금융 정보를 다룬다는 사실과 Play의 Data safety에서 말하는 “수집(기기 밖으로 전송)”은 동일한 개념이 아니다. 다만 답변은 개인정보처리방침 및 실제 동작과 서로 모순되면 안 된다.

### 3.4 App content 선언

Play Console의 `Policy and programs > App content`에서 다음 항목을 완료한다.

- [ ] 개인정보처리방침 URL
- [ ] 광고: 현재 구현 기준 `광고 없음`
- [ ] App access: 로그인이나 제한 영역이 없으므로 `모든 기능에 제한 없이 접근 가능`
- [ ] Target audience and content: 실제 의도한 성인 연령대를 선택
- [ ] Content rating: IARC 설문을 사실대로 작성
- [ ] Financial features: 모든 앱이 작성해야 함
- [ ] News apps 등 표시되는 추가 선언: 해당 없음을 정확히 선택

이 앱은 은행 연결, 결제, 송금, 대출, 투자, 보험, 금융 자문을 제공하지 않는 오프라인 기록 도구다. Financial features 설문에서는 그 사실을 기준으로 답하되, 제출 시 콘솔이 개인 재무관리/가계부를 `Other`에 포함하도록 안내하면 `Other`를 선택하고 “사용자가 직접 입력한 수입·지출을 기기에서 관리하는 기능이며 금융 거래·중개·자문은 없음”이라고 설명한다. 콘솔 문구가 단순히 열거된 금융 서비스 제공 여부를 묻는다면 `My app doesn't provide any financial features`가 맞을 수 있다. 이 판단 근거를 출시 기록에 남긴다.

계정 생성 기능은 현재 없으므로 계정 삭제 URL 요건은 적용되지 않는다. 향후 로그인·동기화를 추가하면 앱 안과 웹 양쪽에서 계정 삭제 요청을 제공해야 한다.

## 4. 스토어 등록정보 준비

### 4.1 텍스트

한국어를 기본 등록정보로 만들고 일본어 번역을 추가한다.

| 항목 | 제한 | 준비 내용 |
|---|---:|---|
| 앱 이름 | 30자 | `가계부` / `家計簿`보다 검색성과 브랜드를 고려한 고유 이름 권장 |
| 짧은 설명 | 80자 | 핵심 가치 한 문장. 순위, 가격 홍보, 과도한 키워드 사용 금지 |
| 자세한 설명 | 4,000자 | 지출·수입·고정비·분석·백업·PDF 기능과 로컬 저장 방식을 정확히 설명 |
| 출시 노트 | 트랙별 입력 | 첫 출시 기능과 알려진 제한을 간결하게 작성 |

스토어 문구는 앱에서 실제 제공하는 기능만 표현한다. 예를 들어 현재 UI에 “PDF 암호화 미지원” 안내가 있으므로, 암호화 PDF를 지원한다고 홍보하지 않는다.

### 4.2 그래픽

- [ ] Play Store 앱 아이콘: 512×512, 32-bit PNG, 1,024KB 이하
- [ ] Feature graphic: 1,024×500 이미지
- [ ] 휴대전화 스크린샷 최소 2장. 권장 화면: 홈, 지출 기록, 분석, 데이터 관리/PDF
- [ ] 한국어와 일본어 스크린샷을 각각 준비하거나 언어에 무관한 화면으로 구성
- [ ] 개인정보, 실명, 실제 카드/계좌 정보가 없는 데모 데이터 사용
- [ ] 작은 휴대전화, 큰 휴대전화, 태블릿 대응 여부를 검토하고 지원 대상에 맞는 스크린샷 추가

원본 로고가 1024×1024이므로 Store 아이콘 원본으로 활용할 수 있지만, 단순 축소 전에 Play 아이콘의 안전 영역과 배경 표현을 확인한다.

### 4.3 기본 설정

- [ ] App 또는 Game: `App`
- [ ] Category: 앱 성격상 `Finance` 우선 검토
- [ ] 무료/유료 설정
- [ ] 지원 이메일, 선택적으로 웹사이트와 전화번호
- [ ] 배포 국가/지역

## 5. 빌드 전 품질 점검

### 5.1 자동 검사

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

- [ ] `flutter analyze` 오류와 경고 검토
- [ ] 모든 테스트 통과
- [ ] release AAB 빌드 성공
- [ ] 빌드 결과: `build/app/outputs/bundle/release/app-release.aab`
- [ ] 업로드 전 Git 작업 트리와 실제 release commit/tag 기록

### 5.2 실제 기기 테스트

최소한 한국어/일본어, 원/엔 조합과 서로 다른 Android 버전·화면 크기에서 다음 흐름을 확인한다.

- [ ] 첫 실행, 온보딩, 초기 설정
- [ ] 지출·수입·고정지출 생성/수정/삭제
- [ ] 앱 강제 종료와 재실행 후 데이터 유지
- [ ] 월 이동, 검색, 차트, 대량 데이터 표시
- [ ] CSV 내보내기 → 앱 데이터 변경 → 다시 가져오기
- [ ] 잘못된 인증 키 또는 손상 파일 처리
- [ ] PDF/PNG 생성, 열기, 공유, 인쇄
- [ ] 앱 데이터 전체 삭제 및 복구 불가 안내
- [ ] 오프라인/비행기 모드에서 핵심 기능 동작
- [ ] 다크 모드, 큰 글자, 화면 회전, 뒤로 가기
- [ ] TalkBack 레이블, 색 대비, 터치 영역
- [ ] 저사양 기기에서 시작 시간, 스크롤, 메모리 사용

금액 데이터 손실은 가계부 앱에서 치명적이다. 특히 앱 업데이트 전후 DB migration과 내보내기/가져오기는 별도의 회귀 테스트로 유지한다.

## 6. Play Console에서 테스트 출시

### 6.1 앱 생성과 첫 업로드

- [ ] Play Console에서 앱을 생성하고 기본 언어, 앱/게임, 무료/유료, 연락처 정보를 설정한다.
- [ ] `Test and release > Testing > Internal testing`에서 release를 만든다.
- [ ] 서명된 AAB를 업로드하고 Play App Signing을 활성화한다.
- [ ] Play가 표시하는 target API, 권한, 지원 기기, 크기 경고를 확인한다.
- [ ] 내부 테스터를 등록하고 Play Store를 통해 설치한다. 로컬 `flutter run` 설치만으로 대체하지 않는다.

내부 테스트는 최대 100명의 신뢰할 수 있는 테스터에게 빠르게 배포할 수 있다.

### 6.2 Pre-launch report

AAB 업로드 후 `Test and release > Testing > Pre-launch report`에서 다음 결과를 확인한다.

- [ ] Stability: crash, ANR
- [ ] Performance: 느린 시작, 메모리 문제
- [ ] Accessibility: 레이블, 대비, 터치 영역
- [ ] Android compatibility: 제한 API와 기기별 문제
- [ ] 자동 탐색 화면 캡처에서 깨진 글자나 overflow가 없는지 확인

중대한 오류는 수정하고 `versionCode`를 올린 새 AAB를 다시 업로드한다.

### 6.3 비공개 테스트와 개인 계정 조건

개인 개발자 계정이 **2023-11-13 이후 생성**됐다면 프로덕션 접근 신청 전에 다음 조건이 적용된다.

- [ ] Closed testing 트랙 생성
- [ ] 최소 12명의 테스터가 참여 상태를 14일 연속 유지
- [ ] 단순 등록이 아니라 실제 핵심 기능을 사용하고 피드백 제공
- [ ] 테스트 결과, 발견한 문제, 수정 내용 기록
- [ ] 조건 충족 후 Dashboard에서 production access 신청 질문 작성

Google은 production access 신청을 통상 7일 이내 검토하지만 더 오래 걸릴 수 있다. 조직 계정이거나 해당 날짜 이전에 만든 개인 계정이면 콘솔에 표시되는 실제 요구사항을 따른다.

테스터에게 최소한 다음 시나리오를 배정한다.

1. 1개월치 수입·지출·고정비 입력
2. 수정·삭제 및 분석 결과 확인
3. 백업 파일 내보내기와 다른 기기/초기화 상태에서 가져오기
4. PDF 생성·열기·공유
5. 한국어/일본어와 원/엔 전환
6. 불편, 오류, 데이터 불일치 보고

## 7. 프로덕션 제출

제출 직전에 Play Console Dashboard의 미완료 항목이 없는지 확인한다.

- [ ] Store listing과 번역 완료
- [ ] App content의 모든 필수 선언 완료
- [ ] Data safety와 개인정보처리방침이 실제 AAB 동작과 일치
- [ ] Content rating 발급 완료
- [ ] 국가/지역, 가격, 기기 카탈로그 확인
- [ ] 지원 이메일이 실제로 수신 가능
- [ ] 테스트에서 검증한 것과 동일한 commit의 AAB 업로드
- [ ] release name과 한국어/일본어 출시 노트 입력
- [ ] `Review release`의 오류·경고를 모두 검토
- [ ] `Send for review` 또는 production rollout 실행

첫 프로덕션 출시는 선택한 국가의 모든 대상 사용자에게 공개된다. staged rollout은 첫 출시가 아니라 후속 업데이트부터 사용할 수 있다. 첫 출시 위험을 줄이려면 국가 범위를 작게 시작하고, 충분한 내부/비공개 테스트를 먼저 마친다.

심사 중에는 다음을 피한다.

- 패키지명, 서명 키, 핵심 기능을 바꾸는 별도 빌드 생성
- 개인정보처리방침 URL 비공개 전환
- 리뷰어가 확인할 기능과 스토어 설명의 불일치
- 추가 AAB 업로드로 심사 대상을 불필요하게 변경

## 8. 출시 후 운영

### 출시 당일~72시간

- [ ] 실제 Play Store에서 검색·설치·업데이트 확인
- [ ] Android vitals의 crash/ANR 확인
- [ ] 사용자 리뷰와 지원 이메일 확인
- [ ] 백업/복구, PDF, 로컬 데이터 보존 관련 문의 우선 대응
- [ ] 심각한 결함이 있으면 배포 중단 또는 수정 버전 준비

### 이후 업데이트

- [ ] 모든 빌드에서 `versionCode` 증가
- [ ] 내부 테스트 → 필요 시 closed/open 테스트 → production 순서 유지
- [ ] 후속 업데이트는 staged rollout으로 소수 비율부터 배포하고 crash/ANR 확인 후 확대
- [ ] 새 SDK, 권한, 로그인, 광고, 서버 동기화 추가 시 Data safety와 개인정보처리방침을 함께 갱신
- [ ] 매년 target API 마감일 최소 3개월 전에 Flutter/Android 호환성 점검
- [ ] 업로드 키와 개인정보처리방침 URL의 정기 백업·유효성 확인

## 추천 일정

| 기간 | 목표 |
|---|---|
| 1주차 | 패키지명, 이름, 국가, 지원 연락처 확정. release signing과 개인정보처리방침 준비 |
| 2주차 | 스토어 문구·그래픽 제작, 회귀 테스트 보강, release AAB 생성 |
| 3주차 | 내부 테스트, Pre-launch report 수정, 실제 기기 호환성 점검 |
| 4~5주차 | 해당 계정이면 12명/14일 closed test 진행 및 피드백 반영 |
| 이후 | production access 신청, 최종 정책 점검, 심사 제출 및 출시 모니터링 |

개인 계정의 의무 비공개 테스트가 없다면 일정은 단축할 수 있지만, 데이터 손실 위험이 있는 앱 특성상 내부 테스트와 백업/복구 검증은 생략하지 않는 것을 권장한다.

## 공식 문서

- [Google Play target API 요건](https://support.google.com/googleplay/android-developer/answer/11926878)
- [앱 생성 및 Store listing 설정](https://support.google.com/googleplay/android-developer/answer/9859152)
- [미리보기 asset 요구사항](https://support.google.com/googleplay/android-developer/answer/9866151)
- [앱 서명과 Play App Signing](https://developer.android.com/studio/publish/app-signing)
- [Play Console에 App Bundle 업로드](https://developer.android.com/studio/publish/upload-bundle)
- [Flutter Android release 가이드](https://docs.flutter.dev/deployment/android)
- [Data safety 작성 안내](https://support.google.com/googleplay/android-developer/answer/10787469)
- [User Data 및 개인정보처리방침 정책](https://support.google.com/googleplay/android-developer/answer/10144311)
- [App content와 심사 준비](https://support.google.com/googleplay/android-developer/answer/9859455)
- [Financial features 선언](https://support.google.com/googleplay/android-developer/answer/13849271)
- [신규 개인 계정 테스트 요건](https://support.google.com/googleplay/android-developer/answer/14151465)
- [테스트 트랙 설정](https://support.google.com/googleplay/android-developer/answer/9845334)
- [Pre-launch report](https://support.google.com/googleplay/android-developer/answer/9842757)
- [Release 생성 및 배포](https://support.google.com/googleplay/android-developer/answer/9859348)

