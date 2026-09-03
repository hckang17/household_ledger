# 페이지 리팩터링 분석 및 리소스 사용 현황

> 작성일: 2026-06-23  
> 대상: `lib/presenter/pages/` 전체 (10개 파일)

---

## 목차

1. [전체 구조 개요](#1-전체-구조-개요)
2. [페이지별 리팩터링 분석](#2-페이지별-리팩터링-분석)
3. [공통 중복 패턴 & 분리 대상](#3-공통-중복-패턴--분리-대상)
4. [Provider 설계 개선안](#4-provider-설계-개선안)
5. [메모리 & 리소스 사용 추정](#5-메모리--리소스-사용-추정)
6. [리팩터링 우선순위 로드맵](#6-리팩터링-우선순위-로드맵)

---

## 1. 전체 구조 개요

```
lib/presenter/
├── pages/               ← 10개 파일, 총 약 5,676줄
├── common/
│   ├── bootstrap_style/
│   ├── extension/
│   └── widgets/         ← 7개 파일 (현행 공유 위젯)
└── provider/            ← 5개 파일
```

### 현행 Widget 타입 분포

| 타입 | 파일 수 | 파일 목록 |
|---|---|---|
| `ConsumerStatefulWidget` | 8 | analysis, expense_record, fixed_expense, income, settings, export_data, import_data, generating_report |
| `ConsumerWidget` | 2 | home, main_shell |

`ConsumerStatefulWidget` 중 실제로 StatefulWidget이 **필요한** 이유:

| 파일 | 상태 필요 이유 |
|---|---|
| `analysis_page` | 기간 선택, 차트 모드, 터치 인덱스 |
| `expense_record_page` | 달력 확대/축소, 선택일 |
| `fixed_expense_page` | 월 선택 (`_focusedMonth`) |
| `income_page` | 월 선택 (`_focusedMonth`) |
| `settings_page` | TextEditingController, 섹션 확대/축소 |
| `export_data_page` | Form controller, 쿨다운 타이머 |
| `import_data_page` | Form controller, 파일 경로 |
| `generating_report_page` | Form controller, 기간 선택, 로딩 상태 |

---

## 2. 페이지별 리팩터링 분석

### 2-1. `home_page.dart` ✅ 비교적 양호

**현황**

| 항목 | 수치 |
|---|---|
| 전체 줄 수 | 313줄 |
| `build()` 줄 수 | ~260줄 |
| 사용 Provider | 5개 |
| Widget 타입 | `ConsumerWidget` |

**UI에 섞인 로직**

```dart
// build() 내부에서 직접 계산
final monthlyBudget = monthlyIncomeTotal > 0
    ? monthlyIncomeTotal
    : ledger.settings.monthlyBudget;                 // ← 비즈니스 로직
final remainingBudget = monthlyBudget
    - monthlyExpense - monthlyFixedExpense;           // ← 비즈니스 로직

// 최근 5건 필터 + 날짜별 그룹화 (약 30줄)
final sorted = entries.toList()
  ..sort(...);
final recent = sorted.take(5).toList();
final grouped = <DateTime, List<ExpenseEntry>>{...};  // ← 변환 로직
```

**분리 권장 항목**

| 분리 대상 | 이동 위치 | 효과 |
|---|---|---|
| `remainingBudget` 계산 | `homeBudgetProvider` | 중복 계산 제거 |
| 최근 지출 5건 그룹화 | `RecentExpensesList` 위젯 | build() ~80줄 축소 |
| `_resolveTagLabel()` | `MetadataTag` extension | 4곳 중복 제거 |
| `_deleteExpense()` | `ExpenseEntryTile` onDelete 콜백 정리 | 시그니처 단순화 |

---

### 2-2. `analysis_page.dart` 🔴 즉시 리팩터링 필요

**현황**

| 항목 | 수치 |
|---|---|
| 전체 줄 수 | 1,582줄 |
| `build()` 줄 수 | ~545줄 |
| 사용 Provider | 5개 |
| Widget 타입 | `ConsumerStatefulWidget` |
| 메서드 수 | 20+ |

**UI에 섞인 로직 (심각)**

```dart
// 366~469줄: 도넛 차트 섹션 생성 (카테고리 집계, 색상 배정, 정렬)
List<DonutSection> _buildCategoryDonutSections(...) { ... }

// 471~498줄: 일별 지출 FlSpot 목록 생성
List<FlSpot> _buildDailyExpenseSpots(List<ExpenseEntry> entries) { ... }

// 500~527줄: 일별 수입 FlSpot 목록 생성
List<FlSpot> _buildDailyIncomeSpots(List<IncomeEntry> incomes) { ... }

// 303~320줄: 전월동기 쿼리 계산
void _computeAnalysisPrevQuery() { ... }
```

**분리 권장 항목**

| 분리 대상 | 이동 위치 | 줄 수 절감 |
|---|---|---|
| `_buildCategoryDonutSections()` | `analysisDonutDataProvider` (family) | ~100줄 |
| `_buildDailyExpenseSpots()` | `analysisDailySpotsProvider` | ~55줄 |
| `_buildDailyIncomeSpots()` | `analysisIncomeSpotsProvider` | ~55줄 |
| `_computeAnalysisPrevQuery()` | `analysisPeriodProvider` 통합 | ~40줄 |
| 지출 탭 전체 블록 (~430줄) | `AnalysisExpenseTabSection` 위젯 | build() 절반 축소 |
| 수입 탭 전체 블록 (~100줄) | `AnalysisIncomeTabSection` 위젯 | build() 추가 축소 |
| 상단 컨트롤 카드 | `AnalysisPeriodControlCard` 위젯 | ~60줄 |
| `_pickMonth()` (97~193줄) | `MonthSelectorDialog` 공유 위젯 | 중복 제거 |
| 차트 모드 상태 | `analysisModeProvider` (StateProvider) | 상태 분리 |

**목표 build() 줄 수**: 545줄 → 150줄 이하

---

### 2-3. `expense_record_page.dart` 🟡 중간 우선순위

**현황**

| 항목 | 수치 |
|---|---|
| 전체 줄 수 | 582줄 |
| `build()` 줄 수 | ~300줄 |
| 사용 Provider | 5개 |
| Widget 타입 | `ConsumerStatefulWidget` |

**UI에 섞인 로직**

```dart
// 80~127줄: 달력 셀 생성, 일별 합계, 날짜 그룹화
List<DateTime> _calendarCells() { ... }
Map<DateTime, int> _dailyTotals(...) { ... }
Map<DateTime, List<ExpenseEntry>> _groupEntriesByDay(...) { ... }
```

**분리 권장 항목**

| 분리 대상 | 이동 위치 |
|---|---|
| 달력 UI (322~478줄) | `ExpenseCalendarView` 위젯 |
| 일별 합계 계산 | `dailyTotalsProvider(month)` |
| 지출 목록 섹션 | `ExpenseDayGroupList` 위젯 |
| `_resolveTagLabel()` | `MetadataTag` extension |

---

### 2-4. `fixed_expense_page.dart` 🟡 중간 우선순위

**현황**

| 항목 | 수치 |
|---|---|
| 전체 줄 수 | 497줄 |
| `build()` 줄 수 | ~150줄 |
| 사용 Provider | 3개 |
| Widget 타입 | `ConsumerStatefulWidget` |

**분리 권장 항목**

| 분리 대상 | 이동 위치 |
|---|---|
| 에디터 모달 (104~320줄, StatefulBuilder 포함) | `FixedExpenseEditorSheet` 위젯 |
| 고정지출 아이템 카드 (415~487줄) | `FixedExpenseTile` 위젯 |
| `_pickMonth()` | `MonthSelectorDialog` 공유 위젯 |
| `_focusedMonth` 상태 + 네비게이션 로직 | 이미 `MonthNavigatorBar` 사용 중 — 연동 개선 |

---

### 2-5. `income_page.dart` 🟡 중간 우선순위

**현황**

| 항목 | 수치 |
|---|---|
| 전체 줄 수 | 355줄 |
| `build()` 줄 수 | ~145줄 |
| 사용 Provider | 3개 |
| Widget 타입 | `ConsumerStatefulWidget` |

**분리 권장 항목**

| 분리 대상 | 이동 위치 |
|---|---|
| 에디터 모달 (45~179줄) | `IncomeEditorSheet` 위젯 (또는 공통 에디터 기반) |
| 수입 항목 카드 (311~346줄) | `IncomeTile` 위젯 |
| `_delete()` 로직 | `showLedgerConfirmDialog` + provider read로 단순화 |

---

### 2-6. `main_shell_page.dart` ✅ 리팩터링 불필요

**현황**: 39줄, `ConsumerWidget`, 단순한 `IndexedStack` + `BottomNavBar`  
잘 설계되어 있어 추가 분리 불필요.

---

### 2-7. `settings_page.dart` 🟡 중간 우선순위

**현황**

| 항목 | 수치 |
|---|---|
| 전체 줄 수 | 530줄 |
| `build()` 줄 수 | ~150줄 |
| 사용 Provider | 2개 |
| Widget 타입 | `ConsumerStatefulWidget` |

**분리 권장 항목**

| 분리 대상 | 이동 위치 |
|---|---|
| `_addTag()`, `_editTag()`, `_deleteTag()` 로직 | `settingsTagProvider` (Notifier) |
| `_buildTagSection()` (270~355줄) × 3회 | `TagManagementSection` 재사용 위젯 |
| `_buildDataManagementSection()` | `DataManagementSection` 위젯 |

---

### 2-8. `export_data_page.dart` 🟡 중간 우선순위

**현황**

| 항목 | 수치 |
|---|---|
| 전체 줄 수 | 634줄 |
| `build()` 줄 수 | ~330줄 |
| Widget 타입 | `ConsumerStatefulWidget` |

**분리 권장 항목**

| 분리 대상 | 이동 위치 |
|---|---|
| 진행 오버레이 UI | `LoadingOverlay` 공유 위젯 (import_data, generating_report와 공유) |
| 범위 선택 섹션 | `ExportRangePicker` 위젯 |
| 쿨다운 타이머 로직 | `CooldownTimer` mixin 또는 내부 분리 |

---

### 2-9. `import_data_page.dart` 🟢 낮은 우선순위

**현황**: 331줄, 역할이 명확하고 비교적 단순.

**분리 권장 항목**

| 분리 대상 | 이동 위치 |
|---|---|
| `_buildProgressOverlay()` | `LoadingOverlay` 공유 위젯 |

---

### 2-10. `generating_report_page.dart` 🔴 즉시 리팩터링 필요

**현황**

| 항목 | 수치 |
|---|---|
| 전체 줄 수 | 813줄 |
| `build()` 줄 수 | ~380줄 |
| 사용 Provider | 5개 |
| Widget 타입 | `ConsumerStatefulWidget` |

**분리 권장 항목**

| 분리 대상 | 이동 위치 |
|---|---|
| `_onGeneratePressed()` (159~280줄) | `ReportGeneratorNotifier` |
| 기간 설정 카드 | `ReportPeriodSelector` 위젯 |
| 포함 데이터 체크박스 섹션 | `ReportOptionSelector` 위젯 |
| 이전 리포트 목록 | `ReportFileList` 위젯 |
| `_pickMonth()` | `MonthSelectorDialog` 공유 위젯 |
| 진행 오버레이 | `LoadingOverlay` 공유 위젯 |

---

## 3. 공통 중복 패턴 & 분리 대상

### 3-1. 중복 함수 현황

| 함수/패턴 | 중복 위치 | 해결 방법 |
|---|---|---|
| `_resolveTagLabel(tags, code)` | home, expense_record, fixed_expense, analysis (4곳) | `extension MetadataTagListX on List<MetadataTag>` |
| `_text(key)` / `strings[key] ?? ''` | expense_record, income, fixed_expense | `Map<String, String>` extension |
| 삭제 확인 다이얼로그 패턴 | home, expense_record, fixed_expense, settings (4곳) | 이미 `showLedgerConfirmDialog` 존재 → 호출 방식 통일 |
| 월 선택 다이얼로그 | analysis, generating_report, fixed_expense (3곳) | `showMonthSelectorDialog()` 공유 함수 |
| 진행 오버레이 | export_data, import_data, generating_report (3곳) | `LoadingOverlay` 공유 위젯 |

### 3-2. 신규 공유 위젯 제안

```
lib/presenter/common/widgets/
├── (기존 위젯들)
├── loading_overlay.dart          ← export/import/report 공유
├── month_selector_dialog.dart    ← analysis/fixed/generating 공유
├── recent_expenses_list.dart     ← home_page 분리
├── expense_calendar_view.dart    ← expense_record_page 분리
├── tag_management_section.dart   ← settings_page 분리
└── report_period_selector.dart   ← generating_report_page 분리
```

### 3-3. MetadataTag Extension 제안

```dart
// lib/presenter/common/extension/metadata_tag_extension.dart

extension MetadataTagListX on List<MetadataTag> {
  String labelFor(String code) {
    try {
      return firstWhere((t) => t.code == code).label;
    } catch (_) {
      return code;
    }
  }
}
```

사용 예:
```dart
// Before (4곳에서 반복)
_resolveTagLabel(categoryTags, entry.categoryCode)

// After (1줄)
categoryTags.labelFor(entry.categoryCode)
```

---

## 4. Provider 설계 개선안

### 4-1. 현행 Provider 목록

| Provider | 타입 | 역할 |
|---|---|---|
| `ledgerProvider` | `AsyncNotifierProvider` | 전체 가계부 상태 |
| `monthlyExpensesProvider(month)` | `FutureProvider.family` | 월별 지출 |
| `rangeExpensesProvider(range)` | `FutureProvider.family` | 기간별 지출 |
| `monthlyIncomesProvider(month)` | `FutureProvider.family` | 월별 수입 |
| `monthlyFixedExpensesProvider(month)` | `FutureProvider.family` | 월별 고정지출 |
| `localizedStringsProvider` | `Provider` | 현재 언어 문자열 |
| `comparisonProvider` | `Provider` | 전월동기 비교 결과 |
| `currentNavTabProvider` | `NotifierProvider` | 탭 인덱스 |
| `dataManageProvider` | `NotifierProvider` | 데이터 검색/관리 |

### 4-2. 추가 권장 Provider

| 신규 Provider | 위치 | 역할 | 현재 문제 |
|---|---|---|---|
| `homeBudgetProvider` | `home_provider.dart` | 잔여예산 계산 | build()에서 직접 계산 |
| `analysisDotDataProvider(params)` | `analysis_provider.dart` | 도넛 차트 섹션 | analysis_page 540줄 메서드 |
| `analysisSpotsProvider(entries)` | `analysis_provider.dart` | 일별 FlSpot 목록 | analysis_page 메서드들 |
| `analysisModeProvider` | `analysis_provider.dart` | 차트 모드 상태 | `_chartMode` State 변수 |
| `reportGeneratorProvider` | `report_provider.dart` | PDF 생성 로직 | `_onGeneratePressed()` 160줄 |

### 4-3. 의존 관계도 (현행 → 목표)

```
현행:
UI (build) → ref.watch(provider) → 계산 → 표시
              └─ 계산도 build() 내부에서 직접

목표:
UI (build) → ref.watch(computedProvider)
                    ↓
             computedProvider → ref.watch(rawDataProvider)
                                        ↓
                                 rawDataProvider → DB
```

---

## 5. 메모리 & 리소스 사용 추정

> Flutter 앱에서 실제 메모리 수치는 기기/OS/이미지 캐시 등에 따라 큰 차이가 있습니다.  
> 아래는 **위젯 복잡도 + Provider 구독 수 + 상태 변수**를 기반으로 한 **상대적 리소스 추정**입니다.

### 5-1. 페이지별 리소스 사용 추정

| 페이지 | 위젯 트리 깊이 | Provider 구독 | 상태 변수 수 | 리빌드 빈도 | 상대 메모리 | 리소스 등급 |
|---|---|---|---|---|---|---|
| `main_shell_page` | 얕음 | 1개 | 0 | 탭 전환 시 | 최소 | ⭐ 최경량 |
| `home_page` | 중간 | 5개 | 0 | 지출 추가/삭제 시 | 낮음 | ⭐⭐ |
| `income_page` | 중간 | 3개 | 1 (`_focusedMonth`) | 수입 CRUD, 월 변경 시 | 낮음 | ⭐⭐ |
| `fixed_expense_page` | 중간 | 3개 | 1 (`_focusedMonth`) | 고정지출 CRUD, 월 변경 시 | 낮음 | ⭐⭐ |
| `import_data_page` | 중간 | 1개 | 3 (controller × 2, 경로) | 거의 없음 | 낮음 | ⭐⭐ |
| `settings_page` | 중간 | 2개 | 4 (controller × 2, 확장 × 3) | 태그 CRUD 시 | 중간 | ⭐⭐⭐ |
| `expense_record_page` | 깊음 | 5개 | 4 (날짜, 달력 상태) | 날짜 선택, 지출 CRUD 시 | 중간 | ⭐⭐⭐ |
| `export_data_page` | 깊음 | 2개 | 7 (controller × 3, 범위/날짜) | 입력, 내보내기 시 | 중간 | ⭐⭐⭐ |
| `generating_report_page` | 매우 깊음 | 5개 | 8+ (controller × 2, 기간, 옵션 × 4) | 입력, 기간 변경 시 | 높음 | ⭐⭐⭐⭐ |
| `analysis_page` | 매우 깊음 | 5개 | 6 (기간, 차트 모드, 터치) | 기간 변경, 차트 상호작용 시 | **가장 높음** | ⭐⭐⭐⭐⭐ |

### 5-2. 불필요한 리빌드 위험

| 페이지 | 위험 요인 | 영향 |
|---|---|---|
| `analysis_page` | `_buildCategoryDonutSections()` 등이 build()에서 직접 호출 → 모든 상태 변경 시 재계산 | 기간 변경, 터치 이벤트마다 전체 집계 재실행 |
| `home_page` | 5개 provider 구독 → 어느 하나라도 변경 시 전체 rebuild | 지출 추가 시 최근 5건 리스트 전체 rebuild |
| `generating_report_page` | 체크박스 토글 시 전체 build() 재실행 (8+개 상태 변수) | 무거운 build() ~380줄 전체 재실행 |
| `expense_record_page` | 달력 날짜 탭 시 전체 build() 재실행 | 달력 GridView + 지출 리스트 동시 rebuild |

### 5-3. `IndexedStack` 효과 (main_shell)

`IndexedStack`을 사용하므로 모든 탭 위젯이 **메모리에 상시 유지**됩니다.

```
탭 이동 시:
  메모리 상주 페이지: home + analysis + expense_record + fixed_expense + income
  동시 provider 구독: 최대 ~19개 (5개 페이지의 provider 합산)
  동시 활성 위젯 트리: 5개 페이지 전부
```

#### 이 구조의 장단점

**장점**: 탭 전환 시 위젯 재생성 비용 없음, 스크롤 위치 유지  
**단점**: 5개 페이지가 항상 메모리 점유, provider 구독 항상 활성

> 현재 앱 규모에서는 문제가 될 수준은 아니나, `analysis_page`의 리소스 무게(⭐⭐⭐⭐⭐)가  
> 상시 유지된다는 점은 고려할 필요가 있습니다.

### 5-4. 리팩터링 후 기대 효과 (리소스 관점)

| 개선 항목 | 기대 효과 |
|---|---|
| `analysis_page` 계산 로직 → Provider 이동 | 동일 입력 시 계산 결과 캐싱 → 재계산 0 |
| `const` 위젯 분리 (StatelessWidget으로 분리) | Flutter 엔진 위젯 재사용 → rebuild 횟수 감소 |
| `generating_report_page` 상태 → Notifier 분리 | 체크박스 토글 시 해당 위젯만 rebuild |
| `_resolveTagLabel()` → extension | 참조 해석 중복 연산 제거 |

---

## 6. 리팩터링 우선순위 로드맵

### Phase 1 — 공통 유틸 정리 (즉시 가능, 낮은 위험)

- [ ] `MetadataTag` extension 추출 → `_resolveTagLabel` 4곳 통합
- [ ] `LoadingOverlay` 위젯 생성 → export/import/report 3곳 통합
- [ ] `showMonthSelectorDialog()` 생성 → analysis/fixed/generating 3곳 통합

### Phase 2 — analysis_page 분해 (최우선, 가장 큰 효과)

- [ ] `_buildCategoryDonutSections()` → `analysisDonutDataProvider`
- [ ] `_buildDailyExpenseSpots()`, `_buildDailyIncomeSpots()` → `analysisSpotsProvider`
- [ ] 지출 탭 UI → `AnalysisExpenseTabSection` 위젯
- [ ] 수입 탭 UI → `AnalysisIncomeTabSection` 위젯
- [ ] 상단 컨트롤 → `AnalysisPeriodControlCard` 위젯
- [ ] `_chartMode` → `StateProvider`

### Phase 3 — generating_report_page 분해

- [ ] `_onGeneratePressed()` 로직 → `ReportGeneratorNotifier`
- [ ] 기간 설정 카드 → `ReportPeriodSelector` 위젯
- [ ] 포함 옵션 섹션 → `ReportOptionSelector` 위젯
- [ ] 이전 파일 목록 → `ReportFileList` 위젯

### Phase 4 — 나머지 페이지 정리

- [ ] `expense_record_page`: 달력 → `ExpenseCalendarView`
- [ ] `fixed_expense_page`: 에디터 시트 → `FixedExpenseEditorSheet`
- [ ] `income_page`: 에디터 시트 → `IncomeEditorSheet`
- [ ] `settings_page`: 태그 섹션 → `TagManagementSection`
- [ ] `home_page`: 최근 지출 리스트 → `RecentExpensesList`

### Phase 5 — Provider 계층 정비

- [ ] `homeBudgetProvider` 추가 (잔여예산 계산 분리)
- [ ] 전체 Provider 의존 관계 다이어그램 작성

---

## 요약

| 지표 | 현황 | Phase 2 이후 목표 |
|---|---|---|
| `analysis_page` build() 줄 수 | 545줄 | 150줄 이하 |
| `generating_report_page` build() 줄 수 | 380줄 | 150줄 이하 |
| `_resolveTagLabel` 중복 수 | 4곳 | 0 (extension 1곳) |
| `LoadingOverlay` 중복 수 | 3곳 | 0 (공유 위젯) |
| `showMonthSelectorDialog` 중복 수 | 3곳 | 0 (공유 함수) |
| 차트 데이터 불필요 재계산 | 상태 변경마다 | Provider 캐싱 활용 |
