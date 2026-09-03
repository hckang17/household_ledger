# Household Ledger 코드베이스 리팩터링 분석 v2

> 작성일: 2026-07-14  
> 검토 범위: `lib/` 전체, `assets/language_data/ko.json`, `assets/language_data/jp.json`  
> 기준 규모: Dart 70개 파일, 약 19,780줄, 언어팩별 427개 키

---

## 0. 구현 반영 현황 (2026-07-14)

이 문서의 우선순위 제안을 구현한 뒤, 폴더 구조를 MVVM + 페이지 단위 View 구조로 다시 정리했다.

- `features/*/calculators`, `features/*/models`: UI와 분리된 계산과 계산 결과
- `provider/food_analysis_provider.dart`: 분석 View가 사용할 계산 결과 연결
- `presenter/widgets/common`: 둘 이상의 독립 페이지에서 사용하는 공통 Widget
- `presenter/widgets/<page_name>`: 특정 페이지 전용 Widget
- `presenter/controllers`: Widget이 아닌 UI 흐름 Controller
- `presenter/extensions`: 화면 표시용 Extension
- `model/reporting`: PDF 생성 요청과 옵션 모델
- `services/imexporting_file`: PDF 렌더링과 파일 생성 구현

`analysis_expense_tab.dart`는 계산기를 직접 호출하지 않고 `FoodAnalysisProvider`가 제공하는 결과를 View에 연결한다. 음식 분석 카드는 `presenter/widgets/analysis_page/food`, 리포트 Widget은 `presenter/widgets/generating_report_page`에 있다. 구버전 `presenter/pages/expense_editor_sheet.dart` 삭제 상태도 유지했다.

순수 계산 테스트는 Flutter 엔진에 의존하지 않도록 `package:test`를 사용한다. 음식 분석, 차트 시계열, 전월 비교, 소비 달력, PDF 집계를 검증하는 총 11건이 통과했으며 변경 영역의 정적 분석도 정상이다.

> 아래 1장 이후의 규모와 경로는 리팩터링 전 코드베이스를 분석한 기록이다. 현재 폴더 규칙은 `lib/features/README.md`와 `lib/presenter/widgets/README.md`를 기준으로 한다.

---

## 1. 결론 요약

현재 프로젝트는 기능이 늘어나면서 페이지에서 공통 위젯을 분리하는 작업이 상당 부분 진행됐다. 특히 기존 `refactoring_analysis.md`에서 제안했던 아래 항목은 이미 구현되어 있다.

- `AnalysisExpenseTabSection`, `AnalysisIncomeTabSection`
- `AnalysisPeriodControlCard`
- `AnalysisDailyChart`, `AnalysisDonutChart`, `analysis_chart_helpers.dart`
- `ExpenseCalendarSection`, `RecentExpensesList`
- `ExpenseEditorSheet`, `FixedExpenseEditorSheet`, `IncomeEditorSheet`
- `LoadingOverlay`, `MonthSelectorDialog`, `MonthNavigatorBar`
- `ReportPeriodSelector`, `ReportOptionSelector`, `ReportFileList`
- `TagManagementSection`

다만 분리된 코드가 대부분 `lib/presenter/common/widgets/` 한 폴더에 모이면서 새로운 문제가 생겼다.

1. `common`이 실제 공통 영역이 아니라 분석·지출·리포트 기능 전용 위젯까지 모두 수용하는 거대한 보관함이 됐다.
2. `analysis_expense_tab.dart`는 UI, 집계, 비교 문구, 차트 상태, 상세 Bottom Sheet, 소비 입력 연결을 모두 담당하며 1,811줄까지 커졌다.
3. 일부 대형 파일은 위젯 분리보다 먼저 계산 모델과 책임 경계를 분리해야 한다.
4. 동일한 소비 입력 시트가 두 파일에 존재하며, 하나는 사용되지 않는 구버전 코드다.
5. 페이지마다 튜토리얼 시작·종료·뒤로가기 처리 코드가 반복된다.
6. `LedgerState`, `LedgerNotifier`, DB 서비스가 상태·마이그레이션·영속화·현지화를 동시에 담당한다.
7. 언어팩 자체의 한·일 키 일치 상태는 좋지만, 문자열 접근이 동적 Map과 fallback 문자열에 의존해 컴파일 타임 검증이 불가능하다.
8. 실질적인 자동 테스트는 아직 없다. 현재 `test/widget_test.dart`는 `1 + 1 == 2`만 검증한다.

가장 현실적인 순서는 **분석 계산을 순수 Dart 코드로 먼저 분리하고 테스트를 만든 뒤, 분석 UI를 카드 단위로 나누는 것**이다. 폴더 전체를 한 번에 feature-first 구조로 옮기는 작업은 그 다음 단계가 안전하다.

---

## 2. 현재 규모와 우선순위

### 2.1 파일 크기 분포

| 구간 | 파일 수 |
|---|---:|
| 1,000줄 이상 | 3 |
| 500~999줄 | 7 |
| 300~499줄 | 12 |
| 300줄 미만 | 48 |

### 2.2 가장 큰 파일

| 순위 | 파일 | 줄 수 | 핵심 문제 | 우선순위 |
|---:|---|---:|---|---|
| 1 | `presenter/common/widgets/analysis_expense_tab.dart` | 1,811 | 분석 계산·UI·상호작용·입력 연결 혼합 | P0 |
| 2 | `services/imexporting_file/export_pdf_report_service.dart` | 1,611 | 집계·PDF 레이아웃·파일 저장 혼합 | P1 |
| 3 | `presenter/pages/data_managing_page.dart` | 1,385 | 검색 상태·필터·작업·테이블 UI 혼합 | P1 |
| 4 | `presenter/pages/generating_report_page.dart` | 685 | 폼 상태·리포트 생성 orchestration 혼합 | P1 |
| 5 | `presenter/common/widgets/ledger_dialogs.dart` | 681 | 확인창·태그 편집·영수증·Painter 혼합 | P1 |
| 6 | `presenter/pages/export_data_page.dart` | 680 | 폼·범위·쿨다운·내보내기 흐름 혼합 | P2 |
| 7 | `presenter/pages/settings_page.dart` | 613 | 프로필·태그·마이그레이션·튜토리얼 혼합 | P2 |
| 8 | `provider/ledger_provider.dart` | 606 | 초기화·CRUD·DB·import·migration orchestration 혼합 | P1 |
| 9 | `model/ledger_state.dart` | 555 | 도메인 상태·CRUD·현지화·직렬화 혼합 | P1 |
| 10 | `services/imexporting_file/data_im_export_service.dart` | 554 | CSV·서명·파싱·튜토리얼 복원 혼합 | P2 |

파일 길이는 문제를 찾는 신호일 뿐, 줄 수 자체가 목표는 아니다. 분리 후 파일이 짧아져도 데이터 흐름이 더 복잡해지거나 매개변수가 지나치게 많아지면 좋은 리팩터링이 아니다.

---

## 3. 즉시 확인할 항목

### P0-1. `debugPaintSizeEnabled = true`

`lib/main.dart`에서 레이아웃 경계 시각화가 항상 활성화되어 있다.

```dart
debugPaintSizeEnabled = true;
```

개발 중 의도한 설정이라면 로컬 디버그에서만 켜야 한다. 릴리스 또는 일반 디버그 실행의 기본값은 `false`가 안전하다.

권장안:

```dart
assert(() {
  debugPaintSizeEnabled = false;
  return true;
}());
```

또는 별도의 `--dart-define=DEBUG_PAINT=true`일 때만 켜도록 한다.

### P0-2. 소비 입력 시트 중복

다음 두 파일이 동일한 전역 함수명을 가진 서로 다른 구현이다.

- 현재 사용 중: `lib/presenter/common/widgets/expense_editor_sheet.dart` (474줄)
- 참조되지 않음: `lib/presenter/pages/expense_editor_sheet.dart` (243줄)

현재 프로젝트의 import 검색 결과 모든 호출부는 `common/widgets/expense_editor_sheet.dart`만 사용한다. 구버전 파일은 혼동과 잘못된 import 위험이 있으므로 기능 비교 후 삭제하는 것이 좋다.

### P0-3. 자동 테스트 부재

현재 테스트는 테스트 러너 동작만 확인한다. 특히 다음 로직은 변경 위험이 높고 순수 함수 테스트가 반드시 필요하다.

- 전월 동기 범위 계산
- 엥겔지수 및 외식·카페·장보기 통계
- 식사 유형별 현재/전월 비교
- 기본 태그 복구·현지화·삭제 방지
- CSV import/export round trip
- 기존 `점심/식당명` 데이터 migration
- 리포트용 합계와 앱 화면 합계의 일치 여부

---

## 4. `analysis_expense_tab.dart` 상세 분석

### 4.1 현재 한 파일이 담당하는 역할

`analysis_expense_tab.dart`는 현재 최소 여섯 가지 책임을 가진다.

1. 도넛 차트 모드와 터치 상태 관리
2. 카테고리·소구분·식사 유형·소비수단별 집계
3. 엥겔지수와 외식·회식·카페·장보기 통계 계산
4. 전월 동기 비교 문구 결정
5. 분석 카드와 차트 렌더링
6. 상세 Bottom Sheet 및 소비 입력 Bottom Sheet 실행

대표적인 혼합 지점은 `_buildFoodInsightSection()`이다. 이 메서드 안에 다음 로직이 지역 함수로 존재한다.

- `categoryEntries()`
- `totalOf()`
- `averageOf()`
- `dailyOf()`
- `frequencyComparison()`
- `countComparison()`
- `visitCard()`

한 메서드가 데이터 집계, 번역 문구 선택, UI 생성까지 담당하기 때문에 요구사항이 추가될 때마다 메서드와 private 위젯이 함께 증가한다.

### 4.2 리빌드 범위 문제

도넛 차트를 터치해 `_touchedIndex`만 변경해도 상위 `build()`가 다시 실행되면서 다음 계산이 재수행된다.

- 전체 지출·고정지출 합계
- 전월 카테고리 합계
- 도넛 섹션 생성
- 일별 `FlSpot` 생성
- 각 섹션에 대한 필터 후보 구성
- 음식 관련 상세 통계 구성

현재 데이터 규모에서는 치명적인 성능 문제는 아닐 수 있지만, UI 상태 변경과 데이터 집계의 수명이 분리되어 있지 않다는 신호다.

### 4.3 권장 데이터 모델

먼저 UI와 무관한 결과 모델을 만든다.

```dart
class ExpenseAnalysisSnapshot {
  const ExpenseAnalysisSnapshot({
    required this.totalExpense,
    required this.foodInsights,
    required this.categoryBreakdown,
    required this.dailyTotals,
  });

  final int totalExpense;
  final FoodInsights foodInsights;
  final List<BreakdownItem> categoryBreakdown;
  final List<DailyAmount> dailyTotals;
}

class FoodInsights {
  const FoodInsights({
    required this.engelIndex,
    required this.dining,
    required this.cafe,
    required this.grocery,
  });

  final double engelIndex;
  final VisitInsight dining;
  final VisitInsight cafe;
  final VisitInsight grocery;
}

class VisitInsight {
  const VisitInsight({
    required this.count,
    required this.total,
    required this.average,
    required this.dailyAverage,
    required this.previousCount,
    required this.previousDailyAverage,
  });
  // ...
}
```

비교 결과는 번역된 문장보다 의미를 반환해야 한다.

```dart
enum ComparisonDirection { increase, decrease, similar, unavailable }

class MetricComparison {
  const MetricComparison({
    required this.current,
    required this.previous,
    required this.direction,
    required this.difference,
  });
  // ...
}
```

이렇게 하면 계산기는 한국어·일본어 문자열을 알 필요가 없고, Widget에서 `direction`을 언어팩 문구로 변환할 수 있다.

### 4.4 권장 계산기

`ExpenseAnalysisCalculator`는 Flutter, Riverpod, `BuildContext`, localization Map을 import하지 않는 순수 Dart 클래스로 만든다.

```text
features/analysis/domain/
├── expense_analysis_snapshot.dart
├── food_insights.dart
├── metric_comparison.dart
└── expense_analysis_calculator.dart
```

입력:

- 현재 기간 지출
- 전월 동기 지출
- 현재 기간 고정지출
- 기간 시작/종료

출력:

- 모든 카드가 공유하는 하나의 불변 snapshot

Provider는 계산 로직 자체가 아니라 입력 데이터 선택과 snapshot 캐싱을 담당하는 것이 좋다.

### 4.5 권장 위젯 분리

```text
features/analysis/presentation/widgets/expense/
├── expense_analysis_content.dart          # 전체 순서만 조립
├── expense_breakdown_carousel.dart        # 도넛 모드/목록
├── fixed_expense_analysis_card.dart
├── food/
│   ├── food_insight_section.dart
│   ├── engel_index_card.dart
│   ├── dining_overview_card.dart
│   ├── dining_detail_card.dart
│   ├── company_dining_section.dart
│   └── visit_frequency_card.dart           # 카페/장보기 공용
├── charts/
│   ├── comparison_bar_chart.dart
│   ├── dining_occasion_chart.dart
│   └── chart_legend.dart
├── common/
│   ├── insight_header.dart
│   ├── insight_value.dart
│   ├── comparison_message.dart
│   └── no_current_data_prompt.dart
└── sheets/
    └── breakdown_detail_sheet.dart
```

분리 기준:

- `EngelIndexCard`, `DiningDetailCard`처럼 독립적인 입력 모델과 시각적 경계가 있는 단위는 별도 파일로 분리한다.
- `_AnimatedVerticalBar`처럼 특정 차트에서만 쓰는 작은 위젯은 `dining_occasion_chart.dart` 내부 private 클래스로 유지한다.
- 모든 `SizedBox`나 `Text`를 별도 위젯으로 만들지는 않는다.
- `AnalysisExpenseTabSection`에서 소비 입력 시트를 직접 import하지 말고 `VoidCallback onAddExpense`를 받도록 한다. 실제 Bottom Sheet 호출은 페이지가 담당한다.

### 4.6 목표 크기

| 대상 | 현재 | 목표 |
|---|---:|---:|
| `analysis_expense_tab.dart` | 1,811줄 | 250~350줄 |
| 상위 `build()` | 약 270줄 | 100~140줄 |
| 음식 통계 계산 | Widget 내부 | 순수 calculator 1곳 |
| 비교 문구 판단 | Widget 내부 | 의미 모델 + localization formatter |

목표 줄 수는 강제 규칙이 아니라 책임 분리가 성공했는지 확인하는 보조 지표다.

---

## 5. 반복 코드와 공통 위젯 후보

### 5.1 튜토리얼 수명주기 반복

`home`, `setup`, `income`, `fixed_expense`, `expense_record`, `analysis`, `data_managing`, `settings`, `generating_report`, `export_data`에서 다음 패턴이 반복된다.

- `_showcaseStarted`
- `_showcaseContext`
- `_maybeStartShowcase()`
- `_onShowcaseComplete()`
- `_handleBackDuringTutorial()`
- `PopScope`와 `ShowCaseWidget` 조합
- mock data 정리 후 튜토리얼 종료

권장안:

- `TutorialShowcaseController` 또는 `TutorialPageCoordinator`로 시작·dismiss·exit 흐름을 모은다.
- 페이지는 자신의 `TutorialPhase`, showcase key 목록, 완료 후 다음 phase만 전달한다.
- Widget 상속용 mixin보다 조합 가능한 controller가 테스트하기 쉽다.

### 5.2 에디터 시트 공통 구조

소비·고정지출·수입 시트에는 다음 패턴이 반복된다.

- `showModalBottomSheet(isScrollControlled: true)`
- 키보드 inset을 반영한 Padding
- 날짜 선택 필드
- 금액 필드와 숫자 검증
- 저장 중 중복 클릭 방지
- 저장 후 provider 갱신

모든 폼을 하나의 거대한 generic editor로 합치지는 않는 것이 좋다. 대신 다음 작은 기반 위젯만 공유한다.

- `LedgerEditorSheetScaffold`
- `LedgerDateTimeField`
- `LedgerAmountField`
- `MetadataTagDropdown`
- `CompactSaveButton` 또는 `AsyncSaveButton`

도메인별 폼 상태와 저장 규칙은 각 시트에 남긴다.

### 5.3 문자열 조회 방식 반복

현재 다음 형태가 혼재한다.

- `_text(key, fallback)`
- `_t(strings, key, fallback)`
- `_s(strings, key, fallback)`
- `strings[key] ?? fallback`

권장안:

```dart
extension LocalizedStringsX on Map<String, String> {
  String text(String key, String fallback) => this[key] ?? fallback;
}
```

단기적으로 extension으로 호출 방식을 통일하고, 장기적으로는 `AppStrings` 같은 typed wrapper 또는 Flutter `gen_l10n`으로 이전한다.

### 5.4 날짜·금액 표현 반복

- `DateFormat('yyyy-MM-dd')`, `DateFormat('MM.dd')`, `DateFormat('yyyy.MM')`가 여러 파일에 분산되어 있다.
- `currency` 문자열 결합과 `toCurrency()` 사용 방식도 화면과 PDF에서 따로 구현된다.

권장안:

- `AppDateFormatter`
- `MoneyFormatter`
- locale 및 currency를 입력으로 받는 formatter provider

모델의 `formattedDate`처럼 locale에 따라 바뀌는 표현은 모델보다 presentation formatter에 두는 것이 좋다.

### 5.5 색상과 텍스트 스타일 반복

`0xFF0D6EFD`, `0xFF198754`, `0xFFDC3545`, `0xFF486581`, `0xFF627D98`가 여러 위젯에 반복된다.

권장안:

```text
core/design_system/
├── app_colors.dart
├── app_spacing.dart
├── app_text_styles.dart
└── app_theme.dart
```

비교 증가·감소 색상은 `ComparisonDirection`에서 직접 색을 반환하지 않고 UI mapper가 theme 색을 선택하도록 한다.

### 5.6 확인창과 상세창

`ledger_dialogs.dart`는 서로 다른 책임이 한 파일에 있다.

권장 분리:

```text
common/dialogs/
├── ledger_confirm_dialog.dart
├── tag_editor_dialog.dart
├── replacement_tag_dialog.dart
└── receipt/
    ├── receipt_dialog.dart
    ├── receipt_content.dart
    └── receipt_painters.dart
```

`DetailRow`는 영수증에서만 사용한다면 receipt 폴더 내부에 두고, 실제 여러 기능에서 사용될 때만 common으로 올린다.

---

## 6. 폴더별 리뷰

### 6.1 `lib/model`

좋은 점:

- 엔티티의 기본 필드와 JSON 변환이 비교적 명확하다.
- `MetadataTagListX.labelFor()`로 태그 조회 중복을 줄였다.

개선점:

- `LedgerState`가 상태 컨테이너이면서 CRUD 규칙, 기본 태그 복구, localization, JSON 직렬화를 모두 담당한다.
- `LedgerState.initial()`이 `PlatformDispatcher`를 사용해 도메인 모델이 Flutter UI 런타임에 의존한다.
- `metadata_tag.dart`에 시스템 태그의 localization key가 들어 있어 도메인과 언어 리소스가 결합된다.
- `prevPeriodExpenses`는 런타임 조회 상태인데 `LedgerState`의 영속 상태와 같은 객체에 들어 있다.

권장:

- 엔티티와 직렬화 DTO를 분리할 필요가 생기기 전까지는 `toJson/fromJson`을 유지해도 된다.
- 우선 `DefaultMetadataTagCatalog`와 `SystemTagLocalizer`를 model 밖으로 이동한다.
- `LedgerState`에는 상태와 `copyWith` 중심만 남기고, CRUD와 migration은 notifier/use case로 이동한다.

### 6.2 `lib/provider`

좋은 점:

- Riverpod provider 이름과 역할이 대체로 명확하다.
- 월별/기간별 query provider가 분리되어 있다.

개선점:

- `LedgerNotifier` 하나가 앱 초기화, 세 종류 CRUD, 태그 관리, localization, import, migration을 모두 수행한다.
- CRUD 메서드마다 current null 검사, 로그, DB 호출, `_commit` 패턴이 반복된다.
- 분석의 순수 계산 일부가 provider가 아닌 Widget에 남아 있다.

권장:

- `ledgerProvider`를 즉시 여러 provider로 쪼개기보다는 repository/use case를 먼저 분리한다.
- `ExpenseRepository`, `IncomeRepository`, `FixedExpenseRepository`, `SettingsRepository`를 주입한다.
- 화면 선택 상태와 영속 데이터 상태를 같은 notifier에 넣지 않는다.
- 분석 provider는 `AnalysisRequest`를 입력으로 받아 `ExpenseAnalysisSnapshot`을 반환하도록 한다.

### 6.3 `lib/services/database`

현재 세 서비스가 각각 별도 SQLite 파일을 열고 웹에서는 `SharedPreferences`로 분기한다.

- `household_ledger.db`
- `household_fixed_expense.db`
- `household_income.db`

문제점:

- DB open, web 분기, JSON 목록 저장, CRUD 로그가 반복된다.
- 서로 다른 데이터의 원자적 transaction이 어렵다.
- DB version과 migration 지점이 여러 파일로 분산된다.

권장 목표:

```text
core/persistence/
├── app_database.dart
├── database_migrations.dart
└── storage_platform.dart

features/expenses/data/
├── expense_local_data_source.dart
└── expense_repository_impl.dart
```

SQLite 통합은 migration 위험이 있으므로 UI 리팩터링과 같은 PR에서 진행하지 않는다. 먼저 repository interface를 만든 뒤 backend를 교체해야 한다.

### 6.4 `lib/services/imexporting_file`

폴더명 `imexporting_file`은 의미가 불명확하다. `import_export`와 `reporting`으로 나누는 편이 낫다.

- `data_im_export_service.dart`: CSV 구성, 서명, parsing, 설정 복원, tutorial 복원이 혼합됨
- `export_pdf_report_service.dart`: 리포트 데이터 집계, PDF 레이아웃, 차트, 파일 저장이 혼합됨
- `generating_png_service.dart`: 영수증 이미지 생성으로 PDF/CSV와 역할이 다름

권장 분리:

```text
features/data_transfer/
├── domain/export_bundle.dart
├── application/data_export_service.dart
└── data/csv_ledger_codec.dart

features/reporting/
├── domain/report_data.dart
├── application/report_data_builder.dart
├── data/pdf_report_renderer.dart
└── data/report_file_store.dart

features/receipts/
└── data/receipt_image_service.dart
```

화면과 PDF가 각각 합계를 다시 계산하지 않도록 공통 분석 결과 모델을 재사용하는 것이 중요하다.

### 6.5 `lib/presenter/common`

`bootstrap_style`은 현재 프로젝트의 디자인 시스템 역할을 한다. 다만 파일명은 Bootstrap 웹 프레임워크를 연상시키므로 Flutter 앱의 장기 명명으로는 `design_system`이 더 명확하다.

`common/widgets`에는 진짜 공통 위젯과 feature 전용 위젯이 섞여 있다.

진짜 공통 후보:

- `loading_overlay.dart`
- `month_selector_dialog.dart`
- `month_navigator_bar.dart`

feature로 이동할 후보:

- `analysis_*` 전체 → analysis
- `expense_*` → expenses
- `report_*` → reporting
- `tag_management_section.dart` → settings/tags
- `recent_expenses_list.dart`, `comparison_card.dart` → home

원칙은 “두 기능 이상에서 실제 사용되는가?”이다. 미래에 재사용할 것 같다는 이유만으로 common에 올리지 않는다.

### 6.6 `lib/presenter/pages`

페이지는 route entry와 feature composition만 담당하는 것이 이상적이다.

현재 문제:

- 페이지마다 tutorial orchestration이 반복된다.
- `data_managing_page.dart`처럼 페이지 내부에 세부 위젯 builder가 다수 존재한다.
- `expense_page`, `sub_page` 아래에는 실제 Dart 코드 없이 설명용 Markdown만 존재한다.
- 설명 문서는 `docs/architecture/`로 이동하고 비어 있는 폴더는 제거하는 것이 좋다.

### 6.7 `lib/source_block`

- `ledger_converter.html`은 앱 런타임 코드가 아니며 현재 Dart 코드에서 참조되지 않는다.
- `whole_app_scaffold.dart`도 실제 앱 구조와 별개인 scaffold/참고 코드라면 `tool/`, `devtools/`, `docs/examples/` 중 하나로 이동한다.

`lib/`에는 실제 앱 컴파일 대상 코드만 두는 것이 탐색성과 분석 속도에 유리하다.

### 6.8 `assets/language_data`

현재 상태:

- `ko.json`: 427개 키
- `jp.json`: 427개 키
- 한쪽에만 존재하는 키: 0개

좋은 점:

- 한·일 키 집합이 정확히 일치한다.
- 최근 추가된 시스템 태그와 분석 문구도 양쪽에 대응되어 있다.

개선점:

- 427개 키가 하나의 flat JSON에 있어 기능별 탐색이 어렵다.
- 동적 Map 조회라 오타가 컴파일 단계에서 잡히지 않는다.
- `LocalizationService.fallbackStrings`는 전체 키를 포함하지 않아 asset 로드 실패 시 화면마다 서로 다른 inline fallback을 사용한다.
- locale 파일은 `jp.json`이지만 Flutter locale은 표준 코드 `ja`로 변환한다. 장기적으로 `ja.json`으로 통일하는 것이 명확하다.
- placeholder (`{count}`, `{amount}` 등)의 언어별 일치 검증이 없다.

권장 단기안:

1. CI에서 한·일 키 집합과 placeholder 집합이 같은지 검사한다.
2. 키를 prefix 기준으로 정렬한다: `analysis.*`, `expense.*`, `report.*` 또는 현재 camelCase prefix 유지.
3. 문자열 접근 helper를 하나로 통일한다.

권장 장기안:

- Flutter `gen_l10n` + ARB 또는 JSON 기반 typed code generation 도입
- `jp` 저장값은 migration을 거쳐 `ja`로 표준화
- 시스템 기본 태그의 표시 이름은 영속 데이터에 덮어쓰기보다 code + locale resolver로 표시

---

## 7. 권장 목표 폴더 구조

최종적으로는 feature-first 구조가 현재 기능 성장 방향에 적합하다.

```text
lib/
├── app/
│   ├── app.dart
│   ├── app_router.dart
│   └── app_restart_widget.dart
├── core/
│   ├── design_system/
│   ├── localization/
│   ├── persistence/
│   ├── formatting/
│   └── logging/
├── features/
│   ├── analysis/
│   │   ├── domain/
│   │   ├── application/
│   │   └── presentation/
│   ├── expenses/
│   │   ├── domain/
│   │   ├── data/
│   │   ├── application/
│   │   └── presentation/
│   ├── fixed_expenses/
│   ├── incomes/
│   ├── home/
│   ├── settings/
│   ├── data_management/
│   ├── data_transfer/
│   ├── reporting/
│   └── tutorial/
└── main.dart
```

모든 feature에 네 계층을 억지로 만들 필요는 없다. 파일이 하나뿐인 기능은 `presentation/`만 두고, 실제로 domain/data 책임이 생길 때 추가한다.

### 점진적 이전 구조

한 번에 전체 import를 바꾸는 대신 다음처럼 시작할 수 있다.

```text
lib/presenter/features/analysis/
├── analysis_page.dart
├── models/
├── calculators/
└── widgets/
```

분석 기능이 안정된 뒤 `lib/features/analysis/`로 완전히 옮긴다. 이 방식은 대규모 rename으로 인한 merge 충돌을 줄인다.

---

## 8. 단계별 실행 계획

### Phase 0. 안전망과 정리 — 낮은 위험, 즉시

- [ ] `debugPaintSizeEnabled` 기본 비활성화
- [ ] 사용되지 않는 `presenter/pages/expense_editor_sheet.dart` 제거
- [ ] 빈 `expense_page`, `sub_page` 폴더의 문서를 `docs/`로 이동
- [ ] `source_block`의 실제 사용 여부 확인 후 `tool/` 또는 `docs/`로 이동
- [ ] localization 키/placeholder 일치 테스트 추가
- [ ] 전월 동기 범위 계산과 시스템 태그 테스트 추가

완료 기준:

- `flutter analyze` 통과
- 기존 화면 동작 변화 없음
- dead file import 0건

### Phase 1. 분석 계산 분리 — 가장 먼저

- [ ] `ExpenseAnalysisSnapshot`과 하위 결과 모델 작성
- [ ] `ExpenseAnalysisCalculator` 작성
- [ ] 엥겔지수·외식·회식·카페·장보기·전월 비교 unit test 작성
- [ ] `analysis_chart_helpers.dart`의 집계를 calculator/adaptor로 재배치
- [ ] hardcoded category code `C/F/G`를 `ExpenseCategoryCodes`로 중앙화

완료 기준:

- 분석 Widget 내부의 `fold`, 통계용 `where`, 비교 방향 판단 제거
- 같은 입력에 대해 화면과 PDF 결과가 동일

### Phase 2. 분석 UI 분리

- [ ] `FoodInsightSection`
- [ ] `EngelIndexCard`
- [ ] `DiningOverviewCard`
- [ ] `DiningDetailCard`
- [ ] `VisitFrequencyCard`
- [ ] `ExpenseBreakdownCarousel`
- [ ] `BreakdownDetailSheet`
- [ ] 차트 전용 작은 위젯을 각 차트 파일 내부로 이동
- [ ] 소비 입력은 `onAddExpense` callback으로 역전

완료 기준:

- `analysis_expense_tab.dart` 350줄 이하
- 각 카드가 snapshot 일부만 입력으로 받음
- 일본어, 데이터 없음, 큰 text scale Widget test 통과

### Phase 3. 대형 화면 분해

#### Data management

- [ ] `DataManageFilterCard`
- [ ] `DataManageResultList`
- [ ] `DataManageActionBar`
- [ ] `TagBulkChangeSheet`
- [ ] 검색 progress state를 notifier로 이동

#### Reporting

- [ ] `ReportDataBuilder`
- [ ] `PdfReportRenderer`
- [ ] `ReportFileStore`
- [ ] PDF section renderer 파일 분리

#### Dialogs

- [ ] 태그 dialog와 receipt dialog 분리
- [ ] receipt painter를 receipt 폴더로 이동

### Phase 4. 데이터 계층 정비

- [ ] repository interface 도입
- [ ] platform storage adapter 분리
- [ ] 공통 DB factory와 migration registry 도입
- [ ] 세 SQLite 파일을 하나로 통합할지 별도 migration 설계 후 결정
- [ ] `LedgerNotifier`에서 import/migration use case 분리
- [ ] `LedgerState`에서 localization과 runtime query state 분리

이 단계는 데이터 손실 위험이 있으므로 반드시 export 백업, migration test, 구버전 DB fixture가 준비된 후 진행한다.

### Phase 5. feature-first 폴더 이전

- [ ] analysis부터 한 feature씩 이동
- [ ] common에는 실제 2개 이상 feature가 사용하는 항목만 유지
- [ ] `imexporting_file`을 `data_transfer`, `reporting`, `receipts`로 분리
- [ ] tutorial coordinator 도입
- [ ] route import 정리

---

## 9. 테스트 권장안

### Unit test

```text
test/features/analysis/domain/
├── expense_analysis_calculator_test.dart
├── dining_insight_test.dart
└── metric_comparison_test.dart
```

필수 케이스:

- 현재·전월 모두 0건
- 현재만 0건
- 전월만 0건
- 윤년 2월과 월말 전월 동기
- 회식만 존재하는 기간
- custom 식사 유형 존재
- 고정지출만 존재하는 기간

### Widget test

- `DiningDetailCard`: 한국어/일본어, 320px 폭, text scale 확대
- 비교 막대 label 한 줄 유지
- 빈 데이터 CTA가 Bottom Sheet callback을 실행
- 시스템 기본 태그 수정/삭제 버튼 disabled

### Golden test

차트와 카드 UI는 다음 세 상태만 golden test를 두어도 회귀 방지 효과가 크다.

- 정상 데이터
- 현재 데이터 없음
- 일본어 + 긴 문자열

### Integration test

- 소비 입력 → 월별 provider invalidate → 분석 카드 갱신
- CSV export → import → 식사 유형과 시스템 태그 유지
- 구버전 description migration

---

## 10. 피해야 할 리팩터링

1. **줄 수만 줄이기 위한 메서드 이동**  
   계산과 UI 경계가 그대로라면 파일만 여러 개가 되고 의존성은 더 복잡해진다.

2. **모든 계산을 Provider로 만들기**  
   순수 계산기는 일반 Dart 클래스로 두고, Provider는 상태 구독과 캐싱에만 사용한다.

3. **소비·수입·고정지출 폼을 하나의 generic form으로 통합**  
   공통 필드만 재사용하고 도메인별 저장 규칙은 분리한다.

4. **UI 분리와 DB 통합을 한 번에 진행**  
   회귀 원인과 데이터 migration 문제를 분리할 수 없게 된다.

5. **미래 재사용을 예상해 모든 위젯을 common으로 이동**  
   두 기능 이상에서 실제 사용될 때만 common으로 승격한다.

---

## 11. 최종 권장 순서

가장 먼저 실행할 작업은 다음 다섯 가지다.

1. 분석 계산 snapshot/calculator와 unit test 작성
2. `analysis_expense_tab.dart`의 음식 분석 카드 분리
3. 사용되지 않는 구버전 소비 입력 시트 제거
4. 튜토리얼 page coordinator로 반복 수명주기 통합
5. PDF의 데이터 계산과 렌더링 분리

이 순서를 따르면 사용자 기능과 DB를 건드리지 않으면서 가장 큰 파일부터 안전하게 줄일 수 있다. 특히 `analysis_expense_tab.dart`는 먼저 위젯만 잘게 자르는 것보다, **계산 결과 모델을 확정한 후 UI를 분리하는 순서**가 중요하다.
