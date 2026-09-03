# Household Ledger 작업 가이드

## 문서 목적

이 파일은 저장소에서 작업하는 에이전트와 개발자가 현재 구조를 빠르게 이해하고, 기존 데이터와 동작을 깨뜨리지 않도록 하기 위한 최상위 지침이다. 코드와 설정을 우선 사실의 기준으로 삼고, 오래된 분석 문서는 배경 자료로만 사용한다.

## 프로젝트 현황

- Flutter 기반의 오프라인 개인 가계부 앱이다.
- 주요 기능은 지출, 고정지출, 수입, 월별 분석, 전월 동기 비교, 음식 소비 분석, 데이터 검색·일괄 관리, CSV 내보내기·가져오기, PDF/PNG 생성·공유, 온보딩, 한·일 현지화, 로컬 푸시 알림이다.
- 주 대상은 Android와 Windows다. iOS, macOS, Linux, Web 셸도 존재하지만 모든 기능이 동일하게 지원되는 것은 아니다.
- 상태 관리는 Riverpod 3, 네이티브 데이터 저장은 SQLite, 설정과 웹 대체 저장은 SharedPreferences를 사용한다.
- 앱 서버, 로그인, 광고, 분석 SDK, 실제 클라우드 백업은 아직 없다. `docs/developing/clouding.md`는 구현물이 아니라 향후 설계안이다.
- 개별 여행별 지출을 묶는 여행 모드는 `docs/developing/travel_mode_design.md`를 기준으로 구현 중이다. 여행 CRUD·활성 모드·신규 지출 연결·홈/소비기록 컨트롤·관리 화면까지 구현되었고, 여행별 상세 집계와 CSV 백업은 후속 범위다.
- 2026-09-03 기준 `flutter analyze`와 전체 42개 테스트가 통과한다.
- 한국어와 일본어 언어팩은 각각 502개 키이며 현재 키 집합이 일치한다.

### 진행된 구조 개선

- 분석, 비교, 달력, 리포트 집계를 UI에서 `lib/features/*/calculators`의 순수 계산 코드로 분리했다.
- 계산 결과 모델은 `lib/features/*/models`로 분리했다.
- 분석 계산은 Provider가 입력을 조합하고 View가 결과를 구독하는 흐름으로 정리했다.
- 공통 Widget과 페이지 전용 Widget을 `lib/presenter/widgets` 아래에서 사용 범위별로 분리했다.
- 튜토리얼 흐름 객체와 표시용 Extension을 각각 `presenter/controllers`, `presenter/extensions`로 분리했다.
- 주요 순수 계산, 메타데이터 태그, 알림 설정, 사용자 프로필에 단위 테스트를 추가했다.

### 아직 주의가 필요한 영역

- `export_pdf_report_service.dart`, `data_managing_page.dart`, `analysis_expense_tab.dart`, `settings_page.dart`, `ledger_dialogs.dart`, `generating_report_page.dart`, `ledger_provider.dart`, `ledger_state.dart`는 여전히 크거나 책임이 많다. 기능을 추가할 때 더 키우기보다 계산, 흐름, UI 책임을 기존 경계에 맞게 분리한다.
- 현지화는 타입 안전한 생성 코드가 아니라 `Map<String, String>`과 fallback 문자열을 사용한다.
- DB migration, CSV 왕복, 전체 가져오기, 로컬 알림에는 자동 회귀 테스트가 충분하지 않다.
- Windows는 문서상 주 대상이지만 현재 의존성에는 Windows용 SQLite 구현(`sqflite_common_ffi` 등)이 없다. Windows의 DB 런타임 동작은 검증 전까지 지원 완료로 간주하지 않는다.
- Android 출시는 아직 준비 중이다. 패키지명이 `com.example.household_ledger`이고 release 빌드가 debug signing을 사용하며, 개인정보처리방침과 스토어 자산도 준비되지 않았다. 상세 내용은 `docs/developing/release.md`를 따른다.

## 기준 환경과 명령

- Flutter: stable 3.44.0
- Dart: 3.12.0 (`pubspec.yaml`의 SDK 제약은 `^3.12.0`)
- 셸 예시는 저장소 개발 환경에 맞춰 PowerShell을 기준으로 한다.

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
```

특정 순수 Dart 테스트는 다음처럼 좁혀 실행할 수 있다.

```powershell
dart test test/features/analysis/calculators/food_analysis_calculator_test.dart
flutter test test/model/metadata_tag_test.dart
```

릴리스 관련 변경에서만 필요한 빌드 명령은 다음과 같다.

```powershell
flutter build apk --release
flutter build appbundle --release
flutter build windows --release
```

패키지를 일괄 최신화하지 않는다. 의존성 변경은 요구 기능에 필요한 최소 범위로 제한하고 Android, Windows와 해당 플러그인의 플랫폼 지원을 확인한다. 생성물인 `.dart_tool/`, `build/`, 플랫폼별 `ephemeral/` 파일은 직접 편집하거나 커밋하지 않는다.

## 디렉터리와 책임

```text
lib/
├── main.dart                 # 앱 부트스트랩, 테마, 생명주기, 알림 초기화
├── router/                   # 이름 기반 화면 라우팅
├── model/                    # 직렬화 가능한 도메인/입력 모델
├── provider/                 # Riverpod 상태와 기능 연결
├── features/                 # UI와 분리된 순수 계산 및 결과 모델
├── services/
│   ├── database/             # 지출·수입·고정지출 저장소
│   ├── imexporting_file/     # CSV/PDF/PNG 생성과 파일 처리
│   └── push_message/         # 로컬 알림 권한과 스케줄
├── presenter/
│   ├── pages/expense_page/   # 일상적인 가계부 핵심 화면
│   ├── pages/sub_page/       # 설정, 데이터 이동, 리포트, 진입 흐름
│   ├── widgets/common/       # 둘 이상의 독립 페이지가 직접 쓰는 Widget
│   ├── widgets/<page_name>/  # 한 페이지 전용 Widget
│   ├── controllers/          # Widget이 아닌 UI 흐름 제어
│   └── extensions/           # 화면 표시용 Extension
└── source_block/             # 런타임 외 참고 자산; 참조 여부 확인 후 취급

assets/language_data/         # ko.json, jp.json
test/                         # lib 구조에 대응하는 단위/Widget 테스트
docs/developing/              # DB, 리팩터링, 클라우드 설계, 출시 가이드
```

세부 배치 기준은 `lib/features/README.md`, `lib/presenter/widgets/README.md`, 각 pages 폴더의 `about_this_folder.md`를 우선한다.

## 의존 방향

기본 흐름은 아래 방향을 유지한다.

```text
View (presenter/pages, presenter/widgets)
  -> Provider / ViewModel (provider)
  -> 순수 계산 (features)
  -> 도메인 모델 (model)

Provider / 서비스 조정
  -> 저장소·파일·알림 구현 (services)
```

- `features`는 Flutter Widget, `BuildContext`, Riverpod Provider, 현지화 문자열, 파일 시스템, 화면 이동을 import하지 않는다.
- 계산기는 원시 입력과 도메인 모델을 받아 불변 결과를 반환한다. 번역된 문장, 색상, Dialog 선택은 View가 담당한다.
- 페이지가 DB 서비스를 직접 호출하지 않게 한다. 데이터 변경은 Provider/Notifier를 통해 수행한다.
- 둘 이상의 독립 페이지에서 실제로 쓰이지 않는 Widget을 미리 `common`에 두지 않는다.
- 라우트 문자열과 화면 매핑은 `lib/router/app_router.dart`에 유지한다. 파일 이동만을 이유로 공개 라우트 이름을 바꾸지 않는다.

## 상태와 데이터 저장에서 반드시 알아둘 점

### 전역 상태

- `ledgerProvider`는 `AsyncNotifierProvider<LedgerNotifier, LedgerState>`이며 앱 설정, 프로필, 태그, 현재 월 지출, 전체 고정지출, 전월 동기 지출을 조합한다.
- `LedgerState.expenses`는 전체 이력이 아니라 기본적으로 현재 월 지출이다. 임의의 기간이나 월 데이터는 `rangeExpensesProvider`, `monthlyExpensesProvider`를 사용한다.
- 수입은 `LedgerState`에 포함되지 않는다. `monthlyIncomesProvider`와 `IncomeDatabaseService`를 통해 별도로 조회·변경한다.
- `prevPeriodExpenses`는 런타임 비교용이며 영속화 대상이 아니다.
- `LocalStorageService`는 설정, 프로필, 태그를 `household_ledger_state` 키에 저장한다. 저장 직전에 `expenses`와 `fixedExpenses`를 JSON에서 제거한다.

### 데이터베이스

- 지출: `household_ledger.db`, `expense_entries`, schema version 3
- 수입: `household_income.db`, `income_entries`, schema version 1
- 고정지출: `household_fixed_expense.db`, `fixed_expenses`, schema version 1
- 여행 메타데이터: `household_travel.db`, `trips`, schema version 1
- 네이티브에서는 SQLite, Web에서는 각 DB 서비스가 SharedPreferences JSON으로 분기한다.
- 날짜는 ISO-8601 문자열로 저장하며 기간 조회는 `[start, endExclusive)` 규칙을 사용한다.
- DB 필드나 모델 직렬화 키를 변경할 때 기존 설치 데이터용 migration과 구버전 JSON/CSV 호환 처리를 함께 작성한다. 기존 컬럼이나 키를 조용히 재해석하지 않는다.
- 식사 유형이 없던 구형 `점심/식당명` 데이터에 대한 자동 migration이 있다. migration은 반복 실행해도 안전해야 한다.
- 태그 삭제는 연관 지출·고정지출의 코드를 대체한 뒤 수행한다. 시스템 기본 태그는 삭제할 수 없으며, 메모리 상태와 SQLite/Web 저장소를 모두 갱신해야 한다.

### 가져오기와 내보내기

- 가져오기는 merge가 아니라 기존 지출·고정지출·수입 DB를 모두 비운 뒤 교체한다. 파싱과 전체 검증이 끝나기 전에 현재 데이터를 삭제하지 않는다.
- CSV의 `signature`는 이메일과 사용자가 입력한 문자열 키로 만든 무결성/일치 확인값이다. 파일 본문을 암호화하지 않으며 이메일 소유권도 검증하지 않는다. UI나 문서에서 이를 암호화, 패스키, 본인 인증으로 과장하지 않는다.
- 내보내기 스키마, 모델 JSON, DB schema 중 하나를 바꾸면 round-trip과 구버전 파일 복원을 함께 검토한다.
- Web의 파일 내보내기는 현재 `UnsupportedError`를 발생시키므로 지원된다고 가정하지 않는다.

## 현지화와 화면 문구

- 지원 앱 locale은 한국어 `ko`와 일본어 설정 코드 `jp`다. Flutter locale로 연결할 때 `jp`를 `ja`로 변환한다.
- 사용자에게 보이는 새 문구는 `assets/language_data/ko.json`과 `jp.json`에 같은 키로 함께 추가한다.
- 두 언어의 placeholder 이름과 개수를 동일하게 유지한다. 번역 누락을 숨기기 위한 새 하드코딩 fallback을 남발하지 않는다.
- 시스템 메타데이터 태그의 코드와 현지화 키는 `lib/model/metadata_tag.dart`의 계약이다. 표시 언어가 바뀌어도 저장 코드가 바뀌어서는 안 된다.
- 사용자 생성 태그는 번역하지 않는다. 시스템 기본 태그만 현재 언어팩 레이블로 복원한다.
- 소스, JSON, Markdown은 UTF-8로 유지한다. 깨진 문자가 보이면 저장하기 전에 실제 파일 인코딩을 확인한다.

## 구현 규칙

- 기존 Dart 스타일과 `flutter_lints`를 따른다. 공개 타입과 복잡한 데이터 흐름에는 이유를 설명하는 `///` 문서를 유지한다.
- 상태 객체와 계산 결과는 가능한 한 불변으로 두고 기존 `copyWith` 패턴을 따른다.
- 통화는 정수 금액으로 처리한다. 화면 포맷은 `presenter/extensions/currency_extension.dart`와 현재 locale/currency 설정을 재사용한다.
- 월과 기간 계산에서 시간대, 월말, 윤년, 1월의 전월을 고려한다. 날짜 비교를 문자열이나 고정 일수로 대체하지 않는다.
- 비동기 Provider는 loading/error 상태를 보존한다. `AsyncValue`가 아직 데이터가 아닌 상황을 임의의 빈 정상 상태로 오인하지 않는다.
- 데이터 쓰기는 성공한 저장소 작업과 메모리 상태가 어긋나지 않도록 기존 Notifier 순서를 검토한다. 여러 DB를 건드리는 작업은 중간 실패 시 데이터 손실 가능성을 별도로 다룬다.
- 로그에 사용자의 금액 상세, 메모, 이메일, 인증 문자열 또는 전체 백업 내용을 추가하지 않는다.
- API 키, keystore, 서명 비밀번호, `key.properties`를 저장소에 넣지 않는다.
- 관련 없는 대형 리팩터링, 전체 파일 재포맷, 자동 패키지 업그레이드를 기능 수정과 섞지 않는다.

## 테스트와 완료 기준

변경 범위와 같은 계층에 테스트를 추가한다.

- 순수 계산/모델: `test/features/...` 또는 `test/model/...`에 `package:test` 중심의 빠른 단위 테스트를 추가한다.
- Provider 상태 전이: Provider override와 가짜 서비스를 사용해 loading, success, failure 및 저장 호출을 검증한다.
- Widget/UI: 빈 데이터, loading, error, 작은 화면, 한글·일본어 긴 문구를 포함한 Widget 테스트를 추가한다.
- DB/migration/import: 신규 설치, 기존 schema, 중복 실행, 잘못된 파일, 부분 실패, round-trip을 검증한다.
- 날짜/금액 계산: 월말, 윤년, 1월, 데이터 0건, 비교 기간 0건을 포함한다.

작업 완료 전 최소 검증은 다음과 같다.

1. 수정한 Dart 파일을 포맷한다.
2. 관련 테스트를 먼저 실행한다.
3. `flutter analyze`를 실행한다.
4. 공용 모델, Provider, 저장소, 현지화를 건드렸다면 전체 `flutter test`를 실행한다.
5. 플랫폼 플러그인, 알림, 파일 공유, DB, release 설정을 건드렸다면 대상 실제 플랫폼에서 수동 확인 또는 빌드를 수행하고, 실행하지 못한 검증을 결과에 명시한다.
6. 한·일 문구를 변경했다면 두 JSON의 키와 placeholder 일치를 확인한다.

현재 `test/widget_test.dart`의 smoke test는 앱 전체 렌더링을 검증하지 않는다. 테스트 개수만 보고 UI 회귀가 검증됐다고 판단하지 않는다.

## 문서와 Git 작업 주의사항

- `README.md`와 `README_JP.md`는 사용자 기능과 사용법을 설명한다. 사용자 동작이 바뀌면 두 문서를 함께 갱신한다.
- `DATABASE.md`에는 일부 예전 경로와 schema 정보가 남아 있을 수 있다. DB의 최종 사실은 `lib/services/database` 구현으로 확인하고, DB 변경 시 문서도 갱신한다.
- `docs/developing/refactoring_analysis_v2.md`의 0장은 반영 현황이고 이후 장은 리팩터링 전 분석 기록이다. 과거 줄 수와 경로를 현재 구조로 간주하지 않는다.
- 개발 문서는 `docs/developing/`에 둔다. 현재 작업 트리에는 기존 `docs/*.md`를 이 폴더로 이동한 미커밋 변경이 있으므로 원래 위치에 중복 생성하거나 이동을 되돌리지 않는다.
- 기존의 사용자 변경을 보존한다. 작업 전후 `git status --short`와 필요한 경우 `git diff -- <path>`로 자신의 변경 범위를 확인한다.
- `.metadata`와 플랫폼 생성 파일은 Flutter 도구가 관리하므로 명확한 플랫폼 마이그레이션 목적 없이 수정하지 않는다.

## 작업 시작 체크리스트

1. `git status --short`로 기존 변경을 확인한다.
2. 수정 영역의 README, 모델, Provider, 서비스, 관련 테스트를 함께 읽는다.
3. 데이터와 현지화 호환성 영향을 먼저 판단한다.
4. 가장 작은 책임 경계에 구현하고 같은 계층에 테스트를 추가한다.
5. 포맷, 관련 테스트, 정적 분석, 필요 시 전체 테스트와 플랫폼 검증을 수행한다.
