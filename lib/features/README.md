# `features` 계산 기능 구조

이 프로젝트에서 `features`는 UI 소유권 폴더가 아니라 **View와 분리된 계산 기능**을 보관한다. Flutter Widget, `BuildContext`, Riverpod Provider, 현지화 문자열은 이 폴더에 두지 않는다.

```text
features/
├── analysis/
│   ├── calculators/   # 음식·분류·일별 시계열 분석 계산식
│   └── models/        # 음식·차트 분석 결과
├── comparison/
│   ├── calculators/   # 현재·이전 소비 비교 계산식
│   └── models/        # 소비 비교 결과
├── expense/
│   └── calculators/   # 소비 기록 달력의 날짜별 집계
└── reporting/
    ├── calculators/   # PDF 공통 합계 계산식
    └── models/        # PDF 집계 결과
```

의존 방향은 다음과 같다.

```text
View(presenter/pages, presenter/widgets)
    ↓ watch
ViewModel(provider)
    ↓ calculate
Calculation Feature(features)
    ↓ read
Model(model)
```

`features`의 계산기는 입력을 받아 결과를 반환할 뿐 화면 이동, Dialog, 색상, 문구 선택, 파일 저장을 수행하지 않는다.

PDF 렌더링이나 CSV/DB 같은 외부 구현은 `services`, 화면 입력 모델은 `model`, UI 흐름 Controller는 `presenter/controllers`에 둔다.
