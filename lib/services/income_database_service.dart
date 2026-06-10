import 'package:flutter/foundation.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/services/debugging_logger.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

/// 소득 데이터를 SQLite(웹은 shared_preferences)에 저장/조회한다.
class IncomeDatabaseService {
  static const String _databaseName = 'household_income.db';
  static const String _tableName = 'income_entries';
  static const String _webStorageKey = 'household_ledger_incomes';
  static const String _logPrefix = '[IncomeDatabaseService]';

  Database? _database;

  void _log(String methodName, String action) {
    logger.d('[income_database_service.dart] $methodName ( $action )');
  }

  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();
    final fullPath = path.join(databasePath, _databaseName);

    _database = await openDatabase(
      fullPath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            earnedAt TEXT NOT NULL,
            amount INTEGER NOT NULL,
            description TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  Future<List<IncomeEntry>> loadIncomesByMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final endExclusive = DateTime(month.year, month.month + 1, 1);
    return loadIncomesByRange(start: start, endExclusive: endExclusive);
  }

  Future<List<IncomeEntry>> loadIncomesByRange({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    _log('loadIncomesByRange', '소득 기간 조회 시작');
    if (kIsWeb) {
      final allEntries = await _loadAllIncomesFromPreferences();
      return allEntries.where((IncomeEntry entry) {
        return !entry.earnedAt.isBefore(start) &&
            entry.earnedAt.isBefore(endExclusive);
      }).toList()..sort((IncomeEntry left, IncomeEntry right) {
        final byDate = right.earnedAt.compareTo(left.earnedAt);
        if (byDate != 0) {
          return byDate;
        }
        return (right.id ?? 0).compareTo(left.id ?? 0);
      });
    }

    final db = await _getDatabase();
    final rows = await db.query(
      _tableName,
      where: 'earnedAt >= ? AND earnedAt < ?',
      whereArgs: <Object?>[
        start.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
      orderBy: 'earnedAt DESC, id DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> upsertIncome(IncomeEntry entry) async {
    _log('upsertIncome', '소득 저장/수정 시작');
    if (kIsWeb) {
      final allEntries = await _loadAllIncomesFromPreferences();
      int? nextId = entry.id;
      if (nextId == null) {
        final maxId = allEntries.fold<int>(
          0,
          (int maxValue, IncomeEntry item) =>
              item.id != null && item.id! > maxValue ? item.id! : maxValue,
        );
        nextId = maxId + 1;
      }

      final nextEntry = entry.copyWith(id: nextId);
      final filtered = allEntries
          .where((IncomeEntry item) => item.id != nextId)
          .toList();
      filtered.add(nextEntry);
      await _saveAllIncomesToPreferences(filtered);
      return;
    }

    final db = await _getDatabase();
    if (entry.id == null) {
      await db.insert(_tableName, _toRow(entry));
      return;
    }

    await db.update(
      _tableName,
      _toRow(entry),
      where: 'id = ?',
      whereArgs: <Object?>[entry.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteIncome(int id) async {
    _log('deleteIncome', '소득 삭제 시작');
    if (kIsWeb) {
      final allEntries = await _loadAllIncomesFromPreferences();
      final filtered = allEntries
          .where((IncomeEntry item) => item.id != id)
          .toList();
      await _saveAllIncomesToPreferences(filtered);
      return;
    }

    final db = await _getDatabase();
    await db.delete(_tableName, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<IncomeEntry>> _loadAllIncomesFromPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_webStorageKey);
    if (rawValue == null || rawValue.isEmpty) {
      return <IncomeEntry>[];
    }

    final decoded = jsonDecode(rawValue) as List<dynamic>;
    final entries = decoded.map((dynamic item) {
      final json = item as Map<String, dynamic>;
      return IncomeEntry.create(
        id: json['id'] as int?,
        earnedAt: DateTime.parse(json['earnedAt'] as String),
        amount: json['amount'] as int? ?? 0,
        description: json['description'] as String? ?? '',
      );
    }).toList();

    entries.sort((IncomeEntry left, IncomeEntry right) {
      final byDate = right.earnedAt.compareTo(left.earnedAt);
      if (byDate != 0) {
        return byDate;
      }
      return (right.id ?? 0).compareTo(left.id ?? 0);
    });
    return entries;
  }

  Future<void> _saveAllIncomesToPreferences(List<IncomeEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    final sorted = <IncomeEntry>[...entries]
      ..sort((IncomeEntry left, IncomeEntry right) {
        final byDate = right.earnedAt.compareTo(left.earnedAt);
        if (byDate != 0) {
          return byDate;
        }
        return (right.id ?? 0).compareTo(left.id ?? 0);
      });

    final json = sorted
        .map(
          (IncomeEntry entry) => <String, Object?>{
            'id': entry.id,
            'earnedAt': entry.earnedAt.toIso8601String(),
            'amount': entry.amount,
            'description': entry.description,
          },
        )
        .toList();
    await preferences.setString(_webStorageKey, jsonEncode(json));
  }

  Map<String, Object?> _toRow(IncomeEntry entry) {
    return <String, Object?>{
      if (entry.id != null) 'id': entry.id,
      'earnedAt': entry.earnedAt.toIso8601String(),
      'amount': entry.amount,
      'description': entry.description,
    };
  }

  IncomeEntry _fromRow(Map<String, Object?> row) {
    return IncomeEntry.create(
      id: row['id'] as int?,
      earnedAt: DateTime.parse(row['earnedAt']! as String),
      amount: row['amount']! as int,
      description: row['description']! as String,
    );
  }
}
