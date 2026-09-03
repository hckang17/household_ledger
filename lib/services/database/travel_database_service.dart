import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/services/debugging_logger.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// 여행 메타데이터를 SQLite(Web은 SharedPreferences)에 저장한다.
class TravelDatabaseService {
  TravelDatabaseService._();

  /// 앱 전체에서 같은 데이터베이스 연결을 재사용한다.
  static final TravelDatabaseService instance = TravelDatabaseService._();

  static const String databaseName = 'household_travel.db';
  static const String tableName = 'trips';
  static const String activeStartDateIndexName = 'idx_trips_active_start_date';
  static const int schemaVersion = 1;
  static const String _webStorageKey = 'household_ledger_trips';

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

  /// 여행 목록을 보관 여부와 시작일 순으로 조회한다.
  Future<List<Trip>> loadAllTrips() async {
    if (kIsWeb) {
      return _loadTripsFromPreferences();
    }

    final db = await _getDatabase();
    final rows = await db.query(
      tableName,
      orderBy: 'CASE WHEN archivedAt IS NULL THEN 0 ELSE 1 END, startDate DESC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  /// 여행 한 건을 추가하거나 수정한다.
  Future<void> upsertTrip(Trip trip) async {
    if (kIsWeb) {
      final trips = await _loadTripsFromPreferences();
      final next = <String, Trip>{
        for (final current in trips) current.id: current,
        trip.id: trip,
      };
      await _saveTripsToPreferences(next.values.toList());
      return;
    }

    final db = await _getDatabase();
    await db.insert(
      tableName,
      _toRow(trip),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, Object?> _toRow(Trip trip) {
    return <String, Object?>{
      'id': trip.id,
      'name': trip.name,
      'startDate': trip.startDate.toIso8601String(),
      'endDate': trip.endDate.toIso8601String(),
      'budget': trip.budget,
      'note': trip.note,
      'createdAt': trip.createdAt.toIso8601String(),
      'updatedAt': trip.updatedAt.toIso8601String(),
      'archivedAt': trip.archivedAt?.toIso8601String(),
    };
  }

  Trip _fromRow(Map<String, Object?> row) {
    return Trip.create(
      id: row['id']! as String,
      name: row['name']! as String,
      startDate: DateTime.parse(row['startDate']! as String),
      endDate: DateTime.parse(row['endDate']! as String),
      budget: row['budget'] as int?,
      note: row['note']! as String,
      createdAt: DateTime.parse(row['createdAt']! as String),
      updatedAt: DateTime.parse(row['updatedAt']! as String),
      archivedAt: DateTime.tryParse(row['archivedAt'] as String? ?? ''),
    );
  }

  Future<List<Trip>> _loadTripsFromPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_webStorageKey);
    if (raw == null || raw.isEmpty) {
      return <Trip>[];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    final trips = decoded
        .map((dynamic item) => Trip.fromJson(item as Map<String, dynamic>))
        .toList();
    _sortTrips(trips);
    return trips;
  }

  Future<void> _saveTripsToPreferences(List<Trip> trips) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _webStorageKey,
      jsonEncode(trips.map((Trip trip) => trip.toJson()).toList()),
    );
  }

  void _sortTrips(List<Trip> trips) {
    trips.sort((Trip left, Trip right) {
      if (left.isArchived != right.isArchived) {
        return left.isArchived ? 1 : -1;
      }
      return right.startDate.compareTo(left.startDate);
    });
  }
}
