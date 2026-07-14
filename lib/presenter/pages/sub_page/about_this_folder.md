# 서브기능 및 앱 흐름 페이지

가계부 기록 자체가 아닌 설정, 데이터 이동, 리포트, 앱 진입 흐름을 보관한다.

- `settings_page.dart`: 환경설정과 태그 관리
- `data_managing_page.dart`: 저장 데이터 검색과 일괄 관리
- `import_data_page.dart`: 데이터 가져오기
- `export_data_page.dart`: 데이터 내보내기
- `generating_report_page.dart`: PDF 리포트 생성
- `onboarding_page.dart`: 최초 실행 안내
- `setup_page.dart`: 초기 사용자 설정
- `loading_page.dart`: 데이터 로딩과 주기능 화면 워밍업

라우트 이름은 폴더 이동과 무관하게 `AppRouter`에서 기존 값을 유지한다.
