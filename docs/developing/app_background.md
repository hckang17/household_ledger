# 앱 배경과 여행 기록 버튼

2026-09-11: 배경 선택과 여행 모드를 분리했다.

- `AppSettings.useGradientBackground`가 false이면 기본 단색, true이면 기존 `travelGradientPalette`의 4종 팔레트를 사용한다. 기존 팔레트 코드와 JSON 키는 유지한다.
- 새 설치나 팔레트 키가 없는 이전 데이터는 단색으로 시작한다. 새 bool 키 없이 유효한 기존 팔레트가 저장된 경우 그라데이션 선택으로 승계한다. 명시적인 false는 저장된 팔레트보다 우선하므로 단색으로 변경한 뒤 다시 실행해도 유지된다.
- `main`에서 SharedPreferences를 먼저 준비한다. `startupSettingsProvider`는 이 캐시의 설정만 읽어 첫 Flutter 프레임에 전달한다. `AppRestartWidget`으로 ProviderScope를 다시 만들 때도 저장소 캐시를 다시 읽는다.
- `appBackgroundProvider`는 초기 설정을 즉시 사용하고, 이후 가계부 설정 변경을 반영한다. DB 재조회 중 loading/error에서는 마지막 배경을 유지한다. 여행 Provider를 구독하지 않는다.
- `MaterialApp.builder`의 `AppBackground`가 Navigator 전체 뒤에 배경을 표시한다. 화면 전환에 따라 다시 나타나는 페이드 효과는 없으며, 기존의 은은한 움직임과 동작 줄이기 설정은 유지한다.
- `appPageTransitionsTheme`는 화면 전환용 배경 덮개를 투명하게 설정한다. Android는 예측 뒤로가기를 유지하고 일반 이동의 fallback 배경만 투명하게 만든다. Windows/Linux는 색의 알파를 다시 지정하는 기본 Zoom 전환 대신 투명 배경의 FadeForwards 전환을 사용한다. iOS/macOS는 기존 Cupertino 전환을 유지한다.
- 사이드바 닫기와 페이지 이동이 겹치는 경우를 포함해, Android/Windows의 이동·뒤로가기 중간 프레임을 픽셀로 검증한다. Drawer가 닫힌 후에는 화면 배경 픽셀이 실제 공통 배경과 같아야 하며, 배경 설정과 위젯도 유지되어야 한다.
- 홈과 지출기록 화면은 공통 `ExpenseRecordAction`을 사용한다. 유효한 활성 여행이 있으면 초록색/흰 글자와 여행 기록 문구, 그 외에는 노란색/짙은 글자와 일반 기록 문구를 표시한다. 입력 시트와 선택 날짜 전달은 기존 흐름을 유지한다.

Android/iOS가 Flutter 화면 이전에 표시하는 운영체제 시작 화면은 이 배경 Widget의 범위에 포함되지 않는다.
