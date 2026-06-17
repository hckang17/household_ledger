import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/services/debugging_logger.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// 고정지출 데이터를 SQLite(웹은 shared_preferences)에 저장/조회한다.
class FixedExpenseDatabaseService {
  static const String _databaseName = 'household_fixed_expense.db';
  static const String _tableName = 'fixed_expenses';
  static const String _webStorageKey = 'household_ledger_fixed_expenses';

  Database? _database;

  void _log(String methodName, String action) {
    logger.d('[fixed_expense_database_service.dart] $methodName ( $action )');
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
            id TEXT PRIMARY KEY,
            appliedAt TEXT NOT NULL,
            categoryCode TEXT NOT NULL,
            paymentMethodCode TEXT NOT NULL,
            description TEXT NOT NULL,
            amount INTEGER NOT NULL,
            note TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  Future<List<FixedExpense>> loadAllFixedExpenses() async {
    _log('loadAllFixedExpenses', '고정지출 전체 조회 시작');
    if (kIsWeb) {
      final entries = await _loadAllFromPreferences();
      _log('loadAllFixedExpenses', '고정지출 전체 조회 완료(shared_preferences)');
      return entries;
    }

    final db = await _getDatabase();
    final rows = await db.query(_tableName, orderBy: 'appliedAt DESC, id DESC');
    final entries = rows.map(_fromRow).toList();
    _log('loadAllFixedExpenses', '고정지출 전체 조회 완료(SQLite)');
    return entries;
  }

  Future<List<FixedExpense>> loadFixedExpensesByMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final endExclusive = DateTime(month.year, month.month + 1, 1);
    return loadFixedExpensesByRange(start: start, endExclusive: endExclusive);
  }

  Future<List<FixedExpense>> loadFixedExpensesByRange({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    _log('loadFixedExpensesByRange', '고정지출 기간 조회 시작');
    if (kIsWeb) {
      final entries = await _loadAllFromPreferences();
      final filtered =
          entries.where((FixedExpense item) {
            return !item.appliedAt.isBefore(start) &&
                item.appliedAt.isBefore(endExclusive);
          }).toList()..sort((FixedExpense left, FixedExpense right) {
            final byDate = right.appliedAt.compareTo(left.appliedAt);
            if (byDate != 0) {
              return byDate;
            }
            return right.id.compareTo(left.id);
          });
      _log('loadFixedExpensesByRange', '고정지출 기간 조회 완료(shared_preferences)');
      return filtered;
    }

    final db = await _getDatabase();
    final rows = await db.query(
      _tableName,
      where: 'appliedAt >= ? AND appliedAt < ?',
      whereArgs: <Object?>[
        start.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
      orderBy: 'appliedAt DESC, id DESC',
    );
    final entries = rows.map(_fromRow).toList();
    _log('loadFixedExpensesByRange', '고정지출 기간 조회 완료(SQLite)');
    return entries;
  }

  Future<void> upsertFixedExpense(FixedExpense item) async {
    _log('upsertFixedExpense', '고정지출 저장/수정 시작');
    if (kIsWeb) {
      final current = await _loadAllFromPreferences();
      final merged = <String, FixedExpense>{
        for (final entry in current) entry.id: entry,
        item.id: item,
      };
      await _saveAllToPreferences(merged.values.toList());
      _log('upsertFixedExpense', '고정지출 저장/수정 완료(shared_preferences)');
      return;
    }

    final db = await _getDatabase();
    await db.insert(
      _tableName,
      _toRow(item),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _log('upsertFixedExpense', '고정지출 저장/수정 완료(SQLite)');
  }

  Future<void> upsertFixedExpenses(List<FixedExpense> items) async {
    _log('upsertFixedExpenses', '고정지출 다건 저장/수정 시작');
    if (items.isEmpty) {
      _log('upsertFixedExpenses', '입력 목록 비어 있어 저장 스킵');
      return;
    }

    if (kIsWeb) {
      final current = await _loadAllFromPreferences();
      final merged = <String, FixedExpense>{
        for (final entry in current) entry.id: entry,
        for (final entry in items) entry.id: entry,
      };
      await _saveAllToPreferences(merged.values.toList());
      _log('upsertFixedExpenses', '고정지출 다건 저장/수정 완료(shared_preferences)');
      return;
    }

    final db = await _getDatabase();
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        _tableName,
        _toRow(item),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _log('upsertFixedExpenses', '고정지출 다건 저장/수정 완료(SQLite)');
  }

  Future<void> deleteAllFixedExpenses() async {
    _log('deleteAllFixedExpenses', '고정지출 전체 삭제 시작');
    if (kIsWeb) {
      await _saveAllToPreferences(<FixedExpense>[]);
      _log('deleteAllFixedExpenses', '고정지출 전체 삭제 완료(shared_preferences)');
      return;
    }

    final db = await _getDatabase();
    await db.delete(_tableName);
    _log('deleteAllFixedExpenses', '고정지출 전체 삭제 완료(SQLite)');
  }

  Future<void> deleteFixedExpense(String id) async {
    _log('deleteFixedExpense', '고정지출 삭제 시작');
    if (kIsWeb) {
      final current = await _loadAllFromPreferences();
      final filtered = current
          .where((FixedExpense item) => item.id != id)
          .toList();
      await _saveAllToPreferences(filtered);
      _log('deleteFixedExpense', '고정지출 삭제 완료(shared_preferences)');
      return;
    }

    final db = await _getDatabase();
    await db.delete(_tableName, where: 'id = ?', whereArgs: <Object?>[id]);
    _log('deleteFixedExpense', '고정지출 삭제 완료(SQLite)');
  }

  Future<void> replaceFixedExpenseTagCode({
    required MetadataTagType type,
    required String fromCode,
    required String toCode,
  }) async {
    _log('replaceFixedExpenseTagCode', '고정지출 태그 코드 치환 시작');
    if (fromCode == toCode) {
      return;
    }

    String? columnName;
    switch (type) {
      case MetadataTagType.category:
        columnName = 'categoryCode';
      case MetadataTagType.subcategory:
        columnName = null;
      case MetadataTagType.paymentMethod:
        columnName = 'paymentMethodCode';
    }

    if (columnName == null) {
      _log('replaceFixedExpenseTagCode', '치환 대상 컬럼 없음(subcategory)');
      return;
    }

    if (kIsWeb) {
      final entries = await _loadAllFromPreferences();
      final replaced = entries.map((FixedExpense item) {
        if (columnName == 'categoryCode') {
          return item.categoryCode == fromCode
              ? item.copyWith(categoryCode: toCode)
              : item;
        }
        return item.paymentMethodCode == fromCode
            ? item.copyWith(paymentMethodCode: toCode)
            : item;
      }).toList();
      await _saveAllToPreferences(replaced);
      _log(
        'replaceFixedExpenseTagCode',
        '고정지출 태그 코드 치환 완료(shared_preferences)',
      );
      return;
    }

    final db = await _getDatabase();
    final query =
        'UPDATE $_tableName SET $columnName = ? WHERE $columnName = ?';
    await db.rawUpdate(query, <Object?>[toCode, fromCode]);
    _log('replaceFixedExpenseTagCode', '고정지출 태그 코드 치환 완료(SQLite)');
  }

  Future<List<FixedExpense>> _loadAllFromPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_webStorageKey);
    if (rawValue == null || rawValue.isEmpty) {
      return <FixedExpense>[];
    }

    final decoded = jsonDecode(rawValue) as List<dynamic>;
    final items = decoded
        .map(
          (dynamic item) => FixedExpense.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    items.sort((FixedExpense left, FixedExpense right) {
      final byDate = right.appliedAt.compareTo(left.appliedAt);
      if (byDate != 0) {
        return byDate;
      }
      return right.id.compareTo(left.id);
    });
    return items;
  }

  Future<void> _saveAllToPreferences(List<FixedExpense> items) async {
    final preferences = await SharedPreferences.getInstance();
    final sorted = <FixedExpense>[...items]
      ..sort((FixedExpense left, FixedExpense right) {
        final byDate = right.appliedAt.compareTo(left.appliedAt);
        if (byDate != 0) {
          return byDate;
        }
        return right.id.compareTo(left.id);
      });

    await preferences.setString(
      _webStorageKey,
      jsonEncode(sorted.map((FixedExpense item) => item.toJson()).toList()),
    );
  }

  Map<String, Object?> _toRow(FixedExpense item) {
    return <String, Object?>{
      'id': item.id,
      'appliedAt': item.appliedAt.toIso8601String(),
      'categoryCode': item.categoryCode,
      'paymentMethodCode': item.paymentMethodCode,
      'description': item.description,
      'amount': item.amount,
      'note': item.note,
    };
  }

  FixedExpense _fromRow(Map<String, Object?> row) {
    return FixedExpense.create(
      id: row['id']! as String,
      appliedAt: DateTime.parse(row['appliedAt']! as String),
      categoryCode: row['categoryCode']! as String,
      paymentMethodCode: row['paymentMethodCode']! as String,
      description: row['description']! as String,
      amount: row['amount']! as int,
      note: row['note']! as String,
    );
  }
}
