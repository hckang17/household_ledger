# DATABASE

이 문서는 `lib/services` 폴더의 DB 관련 코드를 기준으로 현재 저장 구조를 정리한 문서다.

## 개요

이 프로젝트는 플랫폼에 따라 저장소가 다르게 동작한다.

- Native(Android/iOS/Desktop): `sqflite` 기반 SQLite 사용
- Web: `shared_preferences` 기반 JSON 문자열 저장

DB 서비스는 3개다.

- 지출: `ExpenseDatabaseService` (`lib/services/expense_database_service.dart`)
- 수입: `IncomeDatabaseService` (`lib/services/income_database_service.dart`)
- 고정지출: `FixedExpenseDatabaseService` (`lib/services/fixed_expense_database_service.dart`)

## 1) Expense DB

### 기본 정보

- DB 파일명: `household_ledger.db`
- 테이블명: `expense_entries`
- SQLite 버전: `1`
- Web 저장 키: `household_ledger_expenses`

### 테이블 스키마

```sql
CREATE TABLE expense_entries (
  id TEXT PRIMARY KEY,
  spentAt TEXT NOT NULL,
  categoryCode TEXT NOT NULL,
  subcategoryCode TEXT NOT NULL,
  paymentMethodCode TEXT NOT NULL,
  description TEXT NOT NULL,
  amount INTEGER NOT NULL,
  note TEXT NOT NULL
)
```

### 컬럼 설명

- `id` (TEXT, PK): 지출 식별자(UUID 문자열 등)
- `spentAt` (TEXT): 지출 일시(ISO-8601 문자열)
- `categoryCode` (TEXT): 카테고리 코드
- `subcategoryCode` (TEXT): 서브카테고리 코드
- `paymentMethodCode` (TEXT): 결제수단 코드
- `description` (TEXT): 지출 설명
- `amount` (INTEGER): 금액
- `note` (TEXT): 메모

### 주요 동작

- 전체 조회: `loadAllExpenses()`
  - SQLite: `ORDER BY spentAt DESC`
  - Web: JSON decode 후 `spentAt DESC` 정렬
- 기간 조회: `loadExpensesByRange(start, endExclusive)`
  - 조건: `spentAt >= start AND spentAt < endExclusive`
- 월 조회: `loadExpensesByMonth(month)`
  - 내부적으로 월 시작/다음 달 시작을 계산해 기간 조회 호출
- 단건 저장/수정: `upsertExpense(entry)`
  - SQLite: `insert(..., conflictAlgorithm: replace)`
  - Web: 동일 `id` 제거 후 추가
- 다건 저장/수정: `upsertExpenses(entries)`
  - SQLite: `batch.insert(... replace)`
  - Web: `Map<id, entry>`로 merge
- 단건 삭제: `deleteExpense(id)`
- 태그 코드 일괄 치환: `replaceExpenseTagCode(type, fromCode, toCode)`
  - SQLite: `UPDATE expense_entries SET <column>=? WHERE <column>=?`
  - `type`에 따라 대상 컬럼 변경
    - category -> `categoryCode`
    - subcategory -> `subcategoryCode`
    - paymentMethod -> `paymentMethodCode`

### 직렬화/역직렬화

- DB Row <-> Model
  - `_toRow(ExpenseEntry)`
  - `_fromRow(Map<String, Object?>)`
- Web JSON <-> Model
  - 저장: `entry.toJson()` 리스트를 JSON 문자열로 저장
  - 로드: `ExpenseEntry.fromJson(...)`

## 2) Income DB

### 기본 정보

- DB 파일명: `household_income.db`
- 테이블명: `income_entries`
- SQLite 버전: `1`
- Web 저장 키: `household_ledger_incomes`

### 테이블 스키마

```sql
CREATE TABLE income_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  earnedAt TEXT NOT NULL,
  amount INTEGER NOT NULL,
  description TEXT NOT NULL
)
```

### 컬럼 설명

- `id` (INTEGER, PK, AUTOINCREMENT): 수입 식별자
- `earnedAt` (TEXT): 수입 일시(ISO-8601 문자열)
- `amount` (INTEGER): 금액
- `description` (TEXT): 수입 설명

### 주요 동작

- 기간 조회: `loadIncomesByRange(start, endExclusive)`
  - 조건: `earnedAt >= start AND earnedAt < endExclusive`
  - 정렬: `earnedAt DESC, id DESC`
- 월 조회: `loadIncomesByMonth(month)`
  - 내부적으로 월 범위 계산 후 기간 조회 호출
- 저장/수정: `upsertIncome(entry)`
  - SQLite:
    - `id == null` -> `insert`
    - `id != null` -> `update(... where id = ?, conflictAlgorithm: replace)`
  - Web:
    - `id == null`이면 현재 최대 id + 1로 신규 id 부여
    - 동일 id 항목 교체 저장
- 삭제: `deleteIncome(id)`

### 직렬화/역직렬화

- DB Row <-> Model
  - `_toRow(IncomeEntry)`
  - `_fromRow(Map<String, Object?>)`
- Web JSON <-> Model
  - 저장: `{id, earnedAt, amount, description}` 리스트를 JSON 문자열로 저장
  - 로드: JSON map을 `IncomeEntry.create(...)`로 변환

## 3) 플랫폼별 저장소 차이

- Native는 실제 SQLite 파일 3개를 분리 운용한다.
  - 지출 DB: `household_ledger.db`
  - 수입 DB: `household_income.db`
  - 고정지출 DB: `household_fixed_expense.db`
- Web은 SQLite를 사용하지 않고 `SharedPreferences` 문자열에 JSON으로 저장한다.
- 지출/수입/고정지출 모두 날짜 컬럼을 TEXT(ISO-8601)로 저장하고 문자열 범위 조회를 사용한다.

## 4) 고정지출 저장 경로

### 기본 정보

- DB 파일명: `household_fixed_expense.db`
- 테이블명: `fixed_expenses`
- SQLite 버전: `1`
- Web 저장 키: `household_ledger_fixed_expenses`

### 테이블 스키마

```sql
CREATE TABLE fixed_expenses (
  id TEXT PRIMARY KEY,
  appliedAt TEXT NOT NULL,
  categoryCode TEXT NOT NULL,
  paymentMethodCode TEXT NOT NULL,
  description TEXT NOT NULL,
  amount INTEGER NOT NULL,
  note TEXT NOT NULL
)
```

### 컬럼 설명

- `id` (TEXT, PK): 고정지출 식별자
- `appliedAt` (TEXT): 적용 월(ISO-8601 문자열, 월 시작일로 정규화)
- `categoryCode` (TEXT): 카테고리 코드
- `paymentMethodCode` (TEXT): 결제수단 코드
- `description` (TEXT): 고정지출 설명
- `amount` (INTEGER): 금액
- `note` (TEXT): 메모

### 주요 동작

- 전체 조회: `loadAllFixedExpenses()`
  - SQLite: `ORDER BY appliedAt DESC, id DESC`
- 월 조회: `loadFixedExpensesByMonth(month)`
  - 조건: `appliedAt >= start AND appliedAt < endExclusive`
- 저장/수정: `upsertFixedExpense(item)`
  - SQLite: `insert(..., conflictAlgorithm: replace)`
- 다건 저장/수정: `upsertFixedExpenses(items)`
  - 구버전 shared_preferences 데이터 마이그레이션 시 사용
- 삭제: `deleteFixedExpense(id)`
- 태그 코드 치환: `replaceFixedExpenseTagCode(type, fromCode, toCode)`
  - category/paymentMethod 타입 치환 지원

### 상태 저장과의 관계

- 현재 고정지출의 소스 오브 트루스는 FixedExpense DB다.
- `LocalStorageService.saveState()` 저장 시 `expenses`, `fixedExpenses`는 제외한다.
- `LedgerNotifier.build()`에서 기존 설정 저장본의 `fixedExpenses`가 남아있고 DB가 비어있으면 1회 마이그레이션한다.

## 5) 마이그레이션/버전 관리 현황

- 세 DB 모두 `version: 1`
- `onUpgrade` 구현 없음
- 현재는 초기 스키마 생성(`onCreate`)만 존재

향후 스키마 변경 시 권장 사항:

- `openDatabase(..., version: N, onUpgrade: ...)` 추가
- 컬럼 추가/기본값/인덱스 생성 SQL을 버전별로 분기
- 기존 데이터 백필(backfill) 로직 명시

## 6) 참고 코드 위치

- `lib/services/expense_database_service.dart`
- `lib/services/income_database_service.dart`
- `lib/services/fixed_expense_database_service.dart`
- `lib/model/fixed_expense.dart`
- `lib/provider/ledger_provider.dart` (서비스 주입/호출)
