# Android 릴리스 크기 검토 (2026-09-24)

## 측정 조건

- Flutter stable 3.44.0, Dart 3.12.0
- `flutter build apk --release`
- `flutter build appbundle --release`
- `flutter build apk --release --split-per-abi`
- 난독화 미적용, Material Icons 트리 셰이킹 적용

## 측정 결과

| 산출물 | 압축 파일 크기 |
|---|---:|
| 범용 APK | 76.69 MiB |
| AAB 업로드 파일 | 73.55 MiB |
| armeabi-v7a APK | 32.84 MiB |
| arm64-v8a APK | 34.58 MiB |
| x86_64 APK | 36.04 MiB |

AAB 크기는 Play Store의 실제 다운로드 크기가 아니다. Play는 기기 ABI 등에 맞춰 분할된 APK를 전달하므로, 현재 로컬에서 확인 가능한 다운로드 크기의 보수적인 근사치는 ABI별 APK 32.84~36.04 MiB다. Play Console의 서명·최적화 이후 수치는 출시 트랙 업로드 때 다시 측정해야 한다.

## 글꼴 비중과 판단

오프라인 한·일 PDF를 위해 포함한 Noto Sans JP/KR Regular·Bold 4개는 원본 22.87 MiB, APK/AAB 내부 압축 기준 12.18 MiB다. arm64 APK에서는 약 35%를 차지한다. Material Icons는 빌드 중 1.57 MiB에서 약 0.02 MiB로 줄었다.

한·일 글리프 범위를 줄인 서브셋이나 네트워크 다운로드 방식은 신규 설치·오프라인 PDF의 글자 깨짐을 다시 만들 수 있어 적용하지 않는다. JP와 KR의 지역별 글자 형태 및 Regular/Bold 표현도 유지한다. 현재 단계에서는 AAB 배포로 ABI 중복 다운로드를 피하고, 네 글꼴을 유지하는 쪽이 데이터 신뢰성과 출력 품질에 맞다.

추후 크기를 더 줄일 때는 동일한 한·일 글리프와 굵기를 보장하는 단일 CJK 가변 글꼴 또는 TTC 패키지를 별도 실험 브랜치에서 비교한다. 후보 적용 전에는 한국어·일본어 PDF 전체 문구, 사용자 입력 혼합 문구, 오프라인 생성, 파일 크기를 함께 검증한다.

