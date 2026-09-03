# 여행 모드 기능 설계

> 작성일: 2026-09-03  
> 상태: DB schema 초기화 구현, 나머지 기능 미구현  
> 목표: 기존 소비 소구분 `여행(t)` 집계를 유지하면서 `A여행`, `B여행`처럼 개별 여행별 소비를 조회한다.

## 1. 결론

여행은 새로운 소비 소구분이 아니라 기존 `여행(t)` 지출을 묶는 **별도 도메인 객체**로 다룬다.

```text
전체 여행 지출 = ExpenseEntry.subcategoryCode == 't'
개별 여행 지출 = ExpenseEntry.subcategoryCode == 't' && ExpenseEntry.tripId == 선택한 여행 ID
미분류 여행 지출 = ExpenseEntry.subcategoryCode == 't' && ExpenseEntry.tripId == null
```

여행마다 SQL View를 동적으로 생성하지 않는다. SQL View는 데이터를 저장하는 공간이 아니라 저장된 SELECT 문이며, 여행 이름 변경·삭제 때 schema 객체를 관리해야 하고 Web의 SharedPreferences 저장 방식과도 맞지 않는다. 사용자 데이터가 늘 때 schema 객체가 함께 늘어나는 구조보다, 고정 schema에 행을 추가하는 구조가 확장성과 백업 호환성이 좋다.

권장안은 다음 두 요소다.

1. 기존 `expense_entries`에 nullable `tripId` 컬럼을 하나 추가한다.
2. 여행 자체의 정보는 `household_travel.db`의 `trips` 테이블에서 관리한다.

이 구조는 기존 지출 분류 체계를 바꾸지 않고, 여행 기능을 별도 서비스와 Provider로 격리할 수 있다. 별도 DB로 인한 외래키와 원자성 제약은 애플리케이션 계층에서 명시적으로 처리한다.

### 구조 대안 비교

| 방식 | 장점 | 단점 | 판단 |
|---|---|---|---|
| 여행마다 SQL View 생성 | 특정 여행 SELECT가 짧아짐 | 사용자 데이터마다 schema 변경, Web 미지원, 이름 변경·삭제·백업 복잡 | 사용하지 않음 |
| 별도 DB에 `trips`와 `trip_expense_links` 저장 | 기존 지출 schema 무변경 | 조회마다 앱 조인, orphan link, 지출 저장과 연결 저장의 부분 실패 | 차선책 |
| 지출에 nullable `tripId` + 별도 `trips` DB | 조회와 직렬화가 단순하고 기존 행 호환 | 지출 DB v3 migration, DB 간 외래키 없음 | **권장** |
| 지출 DB 안에 `trips`와 외래키 저장 | JOIN·transaction·참조 무결성이 가장 강함 | 현재 서비스별 DB 분리 관례를 일부 재구성해야 함 | 장기 통합 시 검토 |

기존 지출 테이블을 절대로 변경할 수 없는 제약이 확정되면 두 번째 방식을 사용한다. 이 경우 `trip_expense_links(expenseId PRIMARY KEY, tripId, linkedAt)` 테이블과 orphan 정리 작업이 추가로 필요하다. 단순히 migration이 부담된다는 이유라면 nullable 컬럼을 추가하는 권장안이 구현량과 장애 지점이 더 적다.

## 2. 핵심 도메인 규칙

- `tripId != null`인 지출은 반드시 `subcategoryCode == 't'`여야 한다.
- `subcategoryCode == 't'`인 모든 지출이 반드시 여행에 연결될 필요는 없다. 기존 데이터와 아직 분류하지 않은 여행 지출은 `tripId == null`로 유지한다.
- 여행 모드 ON은 이후 생성하는 지출의 기본값에만 영향을 준다. 기존 지출을 일괄 변경하지 않는다.
- 여행 모드 OFF는 현재 선택만 해제한다. 이미 여행에 연결된 지출의 `tripId`는 유지한다.
- 지출 수정 시 현재 여행 모드보다 해당 지출에 저장된 `tripId`를 우선한다. 다른 여행이 활성화됐다는 이유로 과거 지출을 자동 재배정하지 않는다.
- 신규 지출이 활성 여행을 상속하면 소구분을 자동으로 `t`로 설정한다.
- 여행 연결 상태에서 사용자가 소구분을 `t`가 아닌 값으로 변경하면 `tripId`를 해제한다. UI에는 연결이 해제된다는 짧은 안내를 표시한다.
- 같은 날짜에 여러 여행이 존재하거나 여행 기간이 겹치는 것을 허용한다. 지출은 날짜 추정이 아니라 명시적인 `tripId`로 연결한다.
- 여행 이름은 중복을 허용하는 편이 안전하다. 화면에서는 기간을 함께 표시해 구분한다. 내부 식별에는 이름이 아닌 ID를 사용한다.

## 3. 데이터 모델

### 3.1 `ExpenseEntry` 확장

```dart
class ExpenseEntry {
  // 기존 필드...
  final String? tripId;
}
```

다음 경로를 함께 수정해야 한다.

- 생성자와 `ExpenseEntry.create`
- `copyWith`와 명시적인 `clearTrip` 옵션
- `toJson` / `fromJson`
- `ExpenseDatabaseService._toRow` / `_fromRow`
- Web SharedPreferences JSON 직렬화
- CSV export/import

기존 JSON이나 CSV에 `tripId`가 없으면 `null`로 읽는다.

### 3.2 `Trip` 모델

```dart
enum TripStatus { upcoming, ongoing, completed, archived }

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.budget,
    this.note = '',
    this.archivedAt,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int? budget;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
}
```

`TripStatus`는 별도 저장값보다 날짜와 `archivedAt`에서 계산하는 것을 권장한다. 기기 날짜가 바뀔 때 상태를 별도로 갱신할 필요가 없기 때문이다.

- `archived`: `archivedAt != null`
- `upcoming`: 오늘 < `startDate`
- `ongoing`: `startDate` ≤ 오늘 ≤ `endDate`
- `completed`: `endDate` < 오늘

날짜가 확정되지 않은 여행까지 지원할 요구가 생기면 `startDate`와 `endDate`를 nullable로 바꾸되, 첫 버전에서는 필수로 두는 편이 UI와 집계가 단순하다.

### 3.3 여행 DB

파일: `household_travel.db`  
테이블: `trips`  
schema version: `1`

```sql
CREATE TABLE trips (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  startDate TEXT NOT NULL,
  endDate TEXT NOT NULL,
  budget INTEGER,
  note TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  archivedAt TEXT
)
```

보관하지 않은 여행의 시작일 정렬을 위해 partial index 하나를 생성한다. 보관된 여행은 활성 목록에서 제외되므로 불필요한 index entry를 만들지 않는다.

```sql
CREATE INDEX idx_trips_active_start_date
ON trips(startDate DESC)
WHERE archivedAt IS NULL;
```

Web에서는 기존 DB 서비스와 동일하게 `household_ledger_trips` SharedPreferences 키에 JSON 목록을 저장한다.

### 3.4 지출 DB migration

`expense_entries` schema를 version 2에서 3으로 올린다.

```sql
ALTER TABLE expense_entries ADD COLUMN tripId TEXT;
CREATE INDEX idx_expense_entries_trip_id ON expense_entries(tripId);
```

`onCreate`에는 처음부터 `tripId TEXT`와 인덱스를 포함하고, `onUpgrade`에는 `oldVersion < 3` 분기를 추가한다. 기존 행은 자동으로 `NULL`이 되어 현재 동작과 집계가 유지된다.

여행 DB가 별도 파일이므로 SQLite 외래키는 선언할 수 없다. 다음 무결성을 `TravelRepository` 또는 Provider에서 보장한다.

- 존재하지 않는 여행 ID를 신규 지출에 저장하지 않는다.
- 여행 영구 삭제 전에 연결된 지출을 조회하고 처리 방식을 결정한다.
- import 후 존재하지 않는 `tripId`는 오류로 중단하거나 `null`로 명시적으로 복구한다. 조용히 유실시키지 않는다.

## 4. 상태와 서비스 구조

기존 `LedgerState`와 `LedgerNotifier`를 더 키우지 않고 여행 기능을 분리한다.

```text
lib/
├── model/travel.dart
├── features/travel/
│   ├── calculators/travel_summary_calculator.dart
│   └── models/travel_summary.dart
├── provider/travel_provider.dart
├── services/database/travel_database_service.dart
├── presenter/pages/expense_page/travel_page.dart
├── presenter/widgets/common/travel_mode_control.dart
└── presenter/widgets/travel_page/
```

### 4.1 `TravelState`

```dart
class TravelState {
  const TravelState({
    required this.trips,
    this.activeTripId,
  });

  final List<Trip> trips;
  final String? activeTripId;

  bool get isTravelModeOn => activeTripId != null;
}
```

`activeTripId`는 UI의 임시 토글처럼 보여도 앱 재시작 후 유지하는 편이 여행 중 사용성에 맞다. `SharedPreferences`의 독립 키 `household_ledger_active_trip_id`에 저장한다. 선택된 여행이 삭제·보관되었거나 존재하지 않으면 시작 시 자동으로 `null`로 정리한다.

### 4.2 Provider 책임

`travelProvider = AsyncNotifierProvider<TravelNotifier, TravelState>`가 다음을 담당한다.

- 여행 목록 로드
- 여행 생성·수정·보관
- 활성 여행 선택과 여행 모드 해제
- 활성 ID 유효성 검사
- 여행 삭제 전 연결 지출 존재 여부 확인

기간 또는 여행별 지출은 기존 `ExpenseDatabaseService`에 다음 조회 API를 추가한다.

```dart
Future<List<ExpenseEntry>> loadExpensesByTrip(String tripId);
Future<int> countExpensesByTrip(String tripId);
Future<void> clearTripFromExpenses(String tripId);
```

여행 요약 계산은 `features/travel`의 순수 계산기로 둔다.

```dart
class TravelSummary {
  final int totalExpense;
  final int? remainingBudget;
  final List<AnalysisBreakdownItem> categoryBreakdown;
  final List<DailyAmountPoint> dailyTotals;
  final int expenseCount;
}
```

기존 분석 결과 모델을 그대로 재사용할 수 있는지는 의미가 완전히 같은 경우에만 선택한다. UI 때문에 서로 다른 도메인을 억지로 결합하지 않는다.

## 5. 여행 모드 동작

### OFF → ON

1. 홈 또는 소비기록 화면의 공통 `TravelModeControl`을 누른다.
2. 활성화 가능한 여행 목록 Bottom Sheet를 연다.
3. 기존 여행 하나를 선택하거나 `새 여행 만들기`로 이동한다.
4. 선택을 완료한 뒤에만 `activeTripId`를 저장한다.
5. 두 화면은 같은 Provider를 구독하므로 즉시 동일한 ON 상태와 여행명을 표시한다.

여행이 한 건도 없을 때 토글만 ON으로 바꾸지 않는다. 먼저 여행 생성 화면을 열고 저장 성공 후 활성화한다.

### ON → OFF

1. 활성 여행명을 포함한 컨트롤을 누른다.
2. `여행 모드 끄기`를 선택한다.
3. `activeTripId`만 `null`로 저장한다.
4. 이미 기록된 지출은 변경하지 않는다.

여행 전환은 같은 메뉴의 `다른 여행 선택`으로 제공한다. 전환 이후 생성되는 지출에만 새 여행을 적용한다.

### 지출 추가

`showExpenseEditorSheet`는 새 지출일 때만 `travelProvider`의 활성 여행을 읽는다.

```text
신규 + 여행 모드 ON
  -> subcategoryCode 기본값을 't'로 설정
  -> tripId 기본값을 activeTripId로 설정
  -> 입력 시트 상단에 "A여행에 기록" Chip 표시

신규 + 여행 모드 OFF
  -> 현재 입력 동작 유지

기존 지출 수정
  -> 저장된 subcategoryCode와 tripId 유지
  -> 현재 활성 여행을 덮어쓰지 않음
```

입력 UI를 크게 바꿀 필요는 없다. 상단에 상태 Chip 하나만 추가하고, Chip을 누르면 이번 지출에 한해 여행 변경 또는 `여행에 포함하지 않음`을 선택할 수 있게 한다.

저장 직전에는 다음을 한 번 더 검증한다.

```dart
if (tripId != null && subcategoryCode != 't') {
  tripId = null;
}
```

도메인 factory에서도 같은 invariant를 보장해 UI 이외의 import나 테스트 데이터가 규칙을 우회하지 못하게 한다.

## 6. UI 정보 구조

### 홈 화면

빠른 지출 기록 버튼 위에 작은 공통 카드를 배치한다.

```text
┌──────────────────────────────────┐
│ ✈ 여행 모드       [ OFF / ON ]   │
│ ON: A여행 · 9/10~9/14            │
└──────────────────────────────────┘
```

- OFF 탭: 여행 선택 Bottom Sheet
- 여행명 탭: 여행 상세 화면
- ON 상태 메뉴: 다른 여행 선택 / 모드 끄기

### 소비기록 화면

AppBar action 또는 달력 위에 같은 `TravelModeControl`을 사용한다. 별도 상태를 만들지 않고 홈과 동일한 Provider를 구독한다.

여행 모드가 켜져 있어도 기존 FAB와 입력 폼의 구조는 유지한다. 색상이나 배너를 통해 자동 분류 상태만 분명히 보여준다.

### 여행 목록 화면

- 진행 중, 예정, 완료, 보관됨 순서 또는 탭
- 여행명, 기간, 지출 합계, 예산 잔액
- `새 여행` 버튼
- 여행 선택 모드와 일반 관리 모드를 같은 목록 Widget으로 재사용

### 여행 상세 화면

- 여행명, 기간, 예산, 메모
- 총 지출과 잔여 예산
- 대분류별 지출 비율
- 일별 지출 추이
- 여행에 연결된 지출 목록
- 기존 여행 지출 연결/해제
- 수정, 보관, 삭제

기존 `여행(t)`이지만 `tripId == null`인 항목은 `미분류 여행 지출`로 보여주고, 여행 상세 또는 데이터 관리 화면에서 일괄 배정할 수 있게 한다.

여행을 만들 때마다 새로운 Widget, Dart 파일 또는 route를 생성하지 않는다. 다음처럼 하나의 화면을 모든 여행이 공유한다.

```text
/travel                 -> TravelPage: 여행 목록
/travel-detail + tripId -> TravelDetailPage: 전달받은 ID의 여행 조회
```

`AppRouter`에는 목록과 상세 route만 고정 등록하고, 상세 route argument의 타입과 누락 상태를 검증한다.

## 7. 삭제와 수정 정책

- 이름, 기간, 예산 수정은 연결된 지출에 영향을 주지 않는다. 지출은 ID로 연결된다.
- 일반 삭제 대신 `보관`을 기본 동작으로 제공한다. 보관된 여행은 새 지출의 선택 목록에서 숨기되 과거 집계에는 남긴다.
- 연결 지출이 있는 여행을 영구 삭제할 때는 자동 삭제하지 않는다.
  - 권장 선택지: `지출은 유지하고 여행 연결만 해제`
  - 선택 가능: `다른 여행으로 이동`
- 여행 삭제가 지출 자체를 삭제하는 기능으로 이어지지 않게 한다.
- 활성 여행을 보관·삭제하면 여행 모드를 먼저 OFF로 전환한다.

## 8. CSV와 전체 가져오기

현재 CSV version `2.0`을 `3.0`으로 올리고 다음을 추가한다.

### `[EXPENSES]`

```csv
id,spentAt,categoryCode,subcategoryCode,diningOccasionCode,tripId,paymentMethodCode,description,amount,note
```

### `[TRIPS]`

```csv
id,name,startDate,endDate,budget,note,createdAt,updatedAt,archivedAt
```

`activeTripId`는 기기 사용 상태이므로 기본적으로 백업하지 않는다. 복원 직후 의도치 않게 여행 모드가 켜지는 것을 방지한다.

호환 정책:

- v2 이하 import: 여행 목록 없음, 모든 `tripId = null`
- v3 import: 모든 expense와 trip을 먼저 파싱하고 참조 무결성을 검사
- `tripId != null`인데 여행이 없거나 소구분이 `t`가 아니면 import를 중단하고 사용자에게 오류를 알림
- 검증이 끝난 뒤에만 기존 DB를 교체

현재도 지출·수입·고정지출이 서로 다른 DB라 전체 import가 단일 SQLite transaction은 아니다. 여행 DB까지 추가하면 중간 실패 위험이 더 커진다. 구현 단계에서 다음 중 하나를 반드시 적용한다.

1. import 직전 현재 전체 snapshot을 임시 백업하고 실패 시 복원
2. 각 DB에 staging 데이터를 쓴 뒤 검증 완료 후 교체

MVP에는 1번이 구현 난도가 낮다.

## 9. 구현 단계

### Phase 1 — 데이터 계약과 단위 테스트

- `Trip`, `TravelState`, `TravelSummary` 모델 작성
- `ExpenseEntry.tripId` 추가
- 지출 DB v3 migration 및 여행 DB v1 구현
- Web JSON fallback 구현
- invariant, migration, 직렬화 왕복 테스트

완료 기준: 기존 데이터가 모두 `tripId == null`로 정상 로드되고 기존 33개 테스트가 그대로 통과한다.

### Phase 2 — Provider와 집계

- `travelProvider`와 활성 여행 영속화
- 여행 CRUD와 보관 정책
- 여행별 지출 조회
- 여행 합계, 대분류별, 일별 계산기와 테스트
- 미분류 여행 지출 조회

### Phase 3 — 지출 입력 자동 연결

- `showExpenseEditorSheet`가 신규 입력에만 활성 여행을 적용
- `여행에 기록` Chip과 단건 변경 기능
- 수정 시 기존 `tripId` 보존
- 비여행 소구분 변경 시 연결 해제
- 홈, 소비기록, 분석, 데이터 관리 등 모든 입력 진입점 회귀 테스트

### Phase 4 — 여행 UI

- 홈과 소비기록에 공통 모드 컨트롤 추가
- 여행 선택·생성 Bottom Sheet
- 여행 목록과 상세 화면
- 미분류 지출 배정
- 한글·일본어 언어팩 동시 추가

### Phase 5 — 백업과 복원

- CSV v3와 `[TRIPS]` section
- v2 하위 호환 import
- import 전체 사전 검증과 실패 복구
- v2→v3 및 v3 round-trip 테스트

## 10. 필수 테스트 시나리오

- 모드 OFF에서 만든 지출은 기존과 동일하게 저장된다.
- A여행 ON 상태의 신규 지출은 `subcategoryCode == 't'`, `tripId == A.id`다.
- A여행 지출 수정 중 B여행이 활성화되어도 A 연결을 유지한다.
- 모드를 OFF로 바꿔도 기존 A여행 지출은 유지된다.
- A에서 B로 전환한 뒤의 신규 지출만 B에 연결된다.
- 여행 연결 지출의 소구분을 평상시로 바꾸면 연결이 해제된다.
- 기존 여행 소구분 지출은 `미분류 여행 지출`로 집계된다.
- 전체 여행 합계에는 A, B, 미분류가 모두 포함된다.
- 여행별 합계는 다른 여행과 미분류 지출을 포함하지 않는다.
- 여행 이름 변경 후에도 연결과 합계가 유지된다.
- 보관된 여행은 과거 상세에서 조회되지만 신규 선택 목록에서는 제외된다.
- 여행 삭제 실패나 import 중간 실패가 지출 삭제로 이어지지 않는다.
- Android SQLite와 Web SharedPreferences 경로가 같은 결과를 반환한다.
- 한글·일본어에서 키와 placeholder가 일치하고 긴 여행명이 레이아웃을 깨지 않는다.

## 11. 이후 확장 가능성

이 설계에서 `Trip`은 단순 태그보다 수명주기와 속성을 가진 객체이므로 다음 기능을 무리 없이 추가할 수 있다.

- 여행별 예산과 초과 알림
- 동행자별 비용 및 정산
- 국가·도시, 통화, 환율
- 영수증 이미지 연결
- 여행 리포트 PDF/PNG 공유
- 여행 단위 클라우드 백업

동행자 정산이나 다중 통화가 필요해질 때는 별도 transaction/participant 모델을 설계한다. 첫 버전부터 `Trip`이나 `ExpenseEntry`에 임시 문자열 필드를 계속 추가하지 않는다.
