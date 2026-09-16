import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_restore_data.dart';

/// 삭제/교체 전에 원본을 영속화한다. 네이티브는 flush 후 원자적 rename을 사용한다.
class BackupJournal {
  BackupJournal({this.directory});
  final Directory? directory;
  static const _key = 'pending_ledger_import_v1';

  Future<File> _file() async => File(
    '${(directory ?? await getApplicationSupportDirectory()).path}/$_key.json',
  );

  Future<BackupRestoreData?> read() async {
    final String? raw;
    if (kIsWeb) {
      raw = (await SharedPreferences.getInstance()).getString(_key);
    } else {
      final file = await _file();
      raw = await file.exists() ? await file.readAsString() : null;
    }
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Unknown recovery version');
    }
    return BackupRestoreData.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> save(BackupRestoreData data) async {
    if (await read() != null) throw StateError('Recovery must finish first');
    final raw = jsonEncode({'version': 1, 'data': data.toJson()});
    if (kIsWeb) {
      if (!await (await SharedPreferences.getInstance()).setString(_key, raw)) {
        throw StateError('Could not save recovery data');
      }
    } else {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(raw, flush: true);
      await temporary.rename(file.path);
    }
    // Read back before allowing any destructive write.
    if (jsonEncode((await read())?.toJson()) != jsonEncode(data.toJson())) {
      throw StateError('Recovery verification failed');
    }
  }

  Future<void> clear() async {
    if (kIsWeb) {
      if (!await (await SharedPreferences.getInstance()).remove(_key)) {
        throw StateError('Could not finish recovery');
      }
    } else {
      final file = await _file();
      if (await file.exists()) await file.delete();
    }
  }
}
