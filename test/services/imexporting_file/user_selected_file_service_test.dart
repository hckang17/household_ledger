import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/services/imexporting_file/user_selected_file_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/file_save');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Android save forwards source, name, and MIME type', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return 'content://downloads/report.pdf';
        });
    final service = UserSelectedFileService(
      channel: channel,
      useAndroidPicker: true,
    );

    final result = await service.saveAs(
      sourcePath: '/work/report.pdf',
      suggestedName: 'report.pdf',
      mimeType: 'application/pdf',
    );

    expect(result, 'content://downloads/report.pdf');
    expect(received?.method, 'saveFile');
    expect(received?.arguments, <String, Object>{
      'sourcePath': '/work/report.pdf',
      'suggestedName': 'report.pdf',
      'mimeType': 'application/pdf',
    });
  });

  test('Android picker cancellation returns null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    final service = UserSelectedFileService(
      channel: channel,
      useAndroidPicker: true,
    );

    expect(
      await service.saveAs(
        sourcePath: '/work/export.csv',
        suggestedName: 'export.csv',
        mimeType: 'text/csv',
      ),
      isNull,
    );
  });
}
