# 순서 4: PDF 오프라인 글꼴·집계 기준 수정

2026-09-16. [후속 지침서](../beta_remediation_and_multidevice_ui_guide.md)의 B10·B11을 수정한다. 순서 1–3의 변경과 증거는 보존했다.

## 변경 내용

- PDF 생성 중 `PdfGoogleFonts` 네트워크 다운로드와 Helvetica 대체를 제거했다.
- SIL Open Font License 1.1의 Noto Sans JP/KR Regular·Bold TTF를 앱 자산에 포함했다. 라이선스 전문은 `assets/fonts/OFL.txt`에 둔다.
- 글꼴 자산이 없거나 손상되면 생성 실패를 전달한다. CJK 글리프가 없는 폰트로 바꿔 깨진 파일을 성공 처리하지 않는다.
- 카테고리 진행 막대, 도넛 조각, 범례가 모두 고정지출을 제외한 일반 지출 합계를 분모로 사용한다.
- PDF 섹션 제목에 `일반 지출`/`通常支出` 범위를 명시한다. 총 지출 요약은 기존처럼 일반 지출과 고정지출의 합계를 표시한다.

## 회귀 자료

검증 데이터는 일반 지출 숙박 40,000, 외식 12,000과 고정지출 800,000이다. 총 지출은 852,000이며 카테고리 막대·도넛·범례는 일반 지출 52,000을 기준으로 각각 77%, 23%를 표시해야 한다.

- [일본어 샘플 PDF](sample_japanese_report.pdf)와 [1쪽](japanese_page_1.png), [2쪽](japanese_page_2.png), [3쪽](japanese_page_3.png)
- [한국어 샘플 PDF](sample_korean_report.pdf)와 [1쪽](korean_page_1.png), [2쪽](korean_page_2.png), [3쪽](korean_page_3.png)

두 PDF의 모든 페이지를 1.5배 PNG로 렌더링해 글리프, 굵기, 표, 도넛과 범례를 육안 확인했다. 텍스트 추출에서도 총 지출 852,000과 77%·23%가 확인된다.

## 검사 결과

- 관련 글꼴·PDF 생성·집계 검사 5건 통과
- 전체 Flutter 테스트 156건 통과, 기존 제외 2건
- `flutter analyze` 통과
- 한국어·일본어 언어팩 604개 키 집합 일치
- Android x64 debug APK 빌드·설치와 네트워크 비활성 상태 앱 실행 통과
- APK 내부에 JP/KR Regular·Bold 글꼴 4개가 포함된 것을 확인

Android 오프라인 실행 UI 계층은 `android_offline_launch.xml`에 보관한다. 에뮬레이터의 실제 PDF 생성 화면 자동 조작은 사이드바 터치 좌표가 안정적으로 동작하지 않아 완료 판정에 사용하지 않았다. 네트워크를 사용하지 않는 생성 테스트와 APK 자산 검사, 한·일 PDF 전 페이지 렌더링으로 생성 경로를 검증했다.
