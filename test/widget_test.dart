// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

/// 기본 위젯 테스트 환경이 동작하는지 검증한다.
void main() {
  /// 테스트 러너 자체가 정상 동작하는지 확인한다.
  test('basic smoke test', () {
    expect(1 + 1, 2);
  });
}
