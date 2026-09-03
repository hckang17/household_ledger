import 'package:flutter/foundation.dart';
import 'package:household_ledger/services/debugging_logger.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// 여행 메타데이터를 보관할 SQLite 스키마를 관리한다.
///
/// 여행 기능의 CRUD와 화면 연결은 아직 구현하지 않으며, 현재는 앱 시작 시
/// `household_travel.db`의 `trips` 테이블과 조회 인덱스만 준비한다.
class TravelDatabaseService {
  TravelDatabaseService._();

  /// 앱 전체에서 같은 데이터베이스 연결을 재사용한다.
  static final TravelDatabaseService instance = TravelDatabaseService._();

  static const String databaseName = 'household_travel.db';
  static const String tableName = 'trips';
  static const String activeStartDateIndexName = 'idx_trips_active_start_date';
  static const int schemaVersion = 1;

  Database? _database;

  /// 지원되는 네이티브 플랫폼에서 여행 데이터베이스 스키마를 초기화한다.
  ///
  /// Web은 SQLite를 사용하지 않으므로 이후 여행 기능 구현 시 기존 DB
  /// 서비스와 같은 SharedPreferences 대체 저장소를 별도로 연결한다.
  Future<void> initialize() async {
    if (kIsWeb) {
      logger.d(
        '[travel_database_service.dart] initialize '
        '( Web SQLite 초기화 생략 )',
      );
      return;
    }

    await _getDatabase();
  }

  Future<Database> _getDatabase() async {
    final current = _database;
    if (current != null) {
      return current;
    }

    final databasePath = await getDatabasesPath();
    final fullPath = path.join(databasePath, databaseName);

    final database = await openDatabase(
      fullPath,
      version: schemaVersion,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            startDate TEXT NOT NULL,
            endDate TEXT NOT NULL,
            budget INTEGER,
            note TEXT NOT NULL DEFAULT '',
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            archivedAt TEXT,
            CHECK (endDate >= startDate)
          )
        ''');
        await db.execute('''
          CREATE INDEX $activeStartDateIndexName
          ON $tableName(startDate DESC)
          WHERE archivedAt IS NULL
        ''');
      },
    );

    _database = database;
    return database;
  }
}
