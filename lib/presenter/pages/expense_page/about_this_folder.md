# 가계부 주기능 페이지

사용자가 일상적으로 가계부를 기록하고 확인하는 핵심 화면을 보관한다.

- `main_shell_page.dart`: 주기능 탭과 하단 Navigation 조합
- `home_page.dart`: 예산 현황과 최근 소비 요약
- `expense_record_page.dart`: 소비 기록 관리
- `income_page.dart`: 수입 관리
- `fixed_expense_page.dart`: 고정지출 관리
- `analysis_page.dart`: 수입·지출 분석
- `expense_management_page.dart`: 지출 관리 진입점

페이지 전용 Widget은 `lib/presenter/widgets/<page_name>/`, 여러 페이지가 공유하는 Widget은 `lib/presenter/widgets/common/`에 둔다.
