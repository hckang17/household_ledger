import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

/// 생성된 작업 파일을 사용자가 고른 위치에 복사한다.
class UserSelectedFileService {
  UserSelectedFileService({MethodChannel? channel, bool? useAndroidPicker})
    : _channel = channel ?? const MethodChannel('household_ledger/file_save'),
      _useAndroidPicker = useAndroidPicker ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _useAndroidPicker;

  /// 취소하면 null, 저장하면 선택한 위치를 설명하는 문자열을 반환한다.
  Future<String?> saveAs({
    required String sourcePath,
    required String suggestedName,
    required String mimeType,
  }) async {
    if (_useAndroidPicker) {
      return _channel.invokeMethod<String>('saveFile', <String, Object>{
        'sourcePath': sourcePath,
        'suggestedName': suggestedName,
        'mimeType': mimeType,
      });
    }
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(label: suggestedName, mimeTypes: <String>[mimeType]),
      ],
    );
    if (location == null) return null;
    await File(sourcePath).copy(location.path);
    return location.path;
  }
}
