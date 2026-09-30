# 재조정 우선순위 1·2 검증 기록

검증일: 2026-09-16

## 1순위: PDF 파일 안전성과 암호 UI 정리

- 같은 시각에 같은 보고서를 두 번 생성해도 서로 다른 파일명을 사용한다.
- 임시 파일에 먼저 기록하고 완료 후 최종 파일명으로 변경한다.
- 쓰기 실패 시 기존 PDF를 유지하고 임시 파일을 제거한다.
- 구현되지 않은 PDF 암호 입력란과 관련 안내를 화면·언어팩·README에서 제거했다.

## 2순위: 사용자가 선택한 위치에 저장

- CSV와 PDF 완료 화면에 `다른 위치에 저장`을 추가했다.
- Android에서는 Storage Access Framework의 `ACTION_CREATE_DOCUMENT`를 사용한다.
- 기존 앱 전용 파일은 작업 파일로 유지하며, 사용자가 선택한 위치에는 복사본을 쓴다.
- 저장, 공유, PDF 열기, 완료 동작을 별도 버튼으로 제공한다.

## 자동 검증

- `flutter analyze`: 통과
- `flutter test`: 158개 통과, 2개 스킵
- PDF 생성·충돌·실패 보존 테스트: 통과
- Android 저장 채널 단위 테스트: 통과
- `flutter build apk --debug --target-platform android-x64`: 통과

## Android 에뮬레이터 확인

1. CSV 내보내기 완료 화면에서 `다른 위치에 저장`을 선택했다.
2. Android 시스템 파일 선택기가 열리고 제안 파일명이 표시되는 것을 확인했다.
3. Downloads에 `houseledger_20260916_073557.csv`를 저장했다(2,212 bytes).
4. 앱의 데이터 가져오기 화면에서 시스템 파일 선택기를 열어 같은 파일을 다시 선택했다. ADB로 앱 저장소에 파일을 복사하지 않았다.

증거 파일:

- `android_export_complete.xml`: 내보내기 완료 동작 구성
- `android_save_picker.png`, `android_save_picker.xml`: Android 저장 위치 선택기
- `android_save_complete.xml`: 사용자 위치 저장 완료 알림
- `android_import_reselect.png`, `android_import_reselect.xml`: 저장한 CSV를 가져오기 화면에서 다시 선택한 결과

PDF와 CSV는 같은 `UserSelectedFileService`와 Android MethodChannel을 사용한다. Android 네이티브 저장 흐름은 CSV로 실기기 수준 검증했고, PDF의 파일명·MIME 전달은 단위 테스트로 확인했다.
