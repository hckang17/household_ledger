# `presenter/widgets` 분류 기준

Widget은 실제 사용 범위에 따라 배치한다.

```text
widgets/
├── common/                  # 둘 이상의 독립 페이지에서 공통 사용
├── analysis_page/           # analysis_page 전용
├── expense_record_page/     # expense_record_page 전용
├── fixed_expense_page/      # fixed_expense_page 전용
├── generating_report_page/  # generating_report_page 전용
├── home_page/               # home_page 전용
├── income_page/             # income_page 전용
└── settings_page/           # settings_page 전용
```

## `common` 판정 규칙

- 현재 둘 이상의 독립 페이지가 직접 사용한다.
- 특정 페이지의 상태나 전용 결과 모델을 요구하지 않는다.
- 이름과 API가 한 페이지의 도메인 용어에 종속되지 않는다.

한 페이지에서만 사용하는 Widget은 재사용 가능성이 있어 보여도 해당 페이지 폴더에 둔다. 실제 두 번째 사용처가 생길 때 `common`으로 이동한다.

Widget이 아닌 UI 흐름 객체는 `presenter/controllers`, Extension은 `presenter/extensions`에 둔다.
