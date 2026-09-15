# Android 베타테스트 증거

결과와 우선순위는 [보고서](../android_beta_test_report_2026-09.md)를 기준으로 읽는다. 이 폴더의 데이터는 전용 에뮬레이터에 만든 가상 가계부다.

| 파일 | 용도 |
|---|---|
| `android_*.png`, `android_*.xml` | Android 화면 및 UIAutomator 계층. 캡처와 계층 수집 사이에 시간이 있으므로 애니메이션 중 서로 다른 프레임일 수 있음 |
| `android_matrix.json` | 기본 Android 화면 행렬 24개. 별도 일본어 캡처는 보고서에 기록 |
| `screen_matrix.json`, 조건명으로 시작하는 PNG | 호스트 Widget 96개 화면 검사. Android 캡처와 혼동하지 말 것 |
| `backup_probe.json`, `tutorial_restart_probe.json` | 실제 서비스와 SQLite를 사용한 결함 재현 결과 |
| `native_*verification.json`, `android_database_verification.json` | 내보내기·복원·여행 삭제의 저장 결과 |
| `native_bulk_before.json`, `native_bulk_after.json` | 분류 일괄 변경 후 및 지출 일괄 삭제 후 저장 상태 |
| `native_report_*.pdf`, `pdf_*page_*.png` | Android 생성 PDF와 5쪽씩의 렌더링 증거 |
| `native_export.csv`, `native_receipt.png` | 앱이 생성한 CSV 및 영수증 이미지 |
| `tests_current.txt`, `analyze_current.txt` | 현재 기준 전체 테스트와 최종 정적 분석 |

## 재실행

저장소 루트에서 실행한다. 감사용 Widget 검사는 오류를 수집하므로 성공 종료 여부 외에 JSON의 `errors`도 확인해야 한다. 재실행하면 같은 이름의 증거 파일을 갱신한다.

```powershell
flutter test docs/developing/beta_test_evidence/screen_matrix_test.dart
flutter test docs/developing/beta_test_evidence/backup_probe_test.dart
flutter test docs/developing/beta_test_evidence/tutorial_restart_probe_test.dart
flutter analyze
flutter test
python docs/developing/beta_test_evidence/android_probe.py capture manual_check
```

Android 도구는 `emulator-5554`를 대상으로 한다. 동일 이름의 개인 데이터가 있는 기기가 아닌 전용 `ledger_beta_api36` 에뮬레이터인지 먼저 확인한다. 화면 행렬 스크립트는 디스플레이와 글자 크기를 바꾼다. 화면 검사는 한 에뮬레이터의 크기를 변경한 것이며 여러 실물 기기 시험이 아니다.

PDF 검토는 임시 디렉터리에 설치한 PyMuPDF로 각 페이지를 이미지로 렌더링한 뒤 진행했다. 최초 오프라인 PDF와 네트워크를 켠 뒤 생성한 PDF를 별도 보관했다. OS 공유창까지만 열었으며 외부 사람·클라우드로 전송하지 않았다.

파일명은 조작 당시의 의도를 나타낼 수 있다. `finished`, `completed` 등의 이름만으로 완료 판정하지 말고 보고서에서 인용한 최종 화면과 DB 증거를 확인한다. 초기 호스트 글꼴 문제의 캡처는 읽을 수 있는 글꼴로 다시 생성했으며, 호스트 플러그인 진단과 에뮬레이터 프로세스 종료를 앱 결함 수에 포함하지 않았다.
