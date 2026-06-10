import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:household_ledger/services/debugging_logger.dart';
import 'package:sqflite/sqflite.dart';

/// 지출내역 핵심 데이터를 SQLite에 저장/조회한다.
class ExpenseDatabaseService {
  static const String _databaseName = 'household_ledger.db';
  static const String _tableName = 'expense_entries';
  static const String _webStorageKey = 'household_ledger_expenses';
  static const String _logPrefix = '[ExpenseDatabaseService]';

  Database? _database;

  void _log(String methodName, String action) {
    logger.d('[expense_database_service.dart] $methodName ( $action )');
  }

  /// SQLite 데이터베이스 인스턴스를 초기화하거나 반환한다.
  Future<Database> _getDatabase() async {
    _log('_getDatabase', 'SQLite 데이터베이스 인스턴스 조회 시작');
    if (_database != null) {
      _log('_getDatabase', '기존 데이터베이스 인스턴스 재사용');
      logger.d('$_logPrefix _getDatabase() reuse existing database instance.');
      return _database!;
    }

    logger.d('$_logPrefix _getDatabase() opening SQLite database.');
    final String fullPath;
    final databasePath = await getDatabasesPath();
    fullPath = path.join(databasePath, _databaseName);
    logger.d('$_logPrefix _getDatabase() database path: $fullPath');

    _database = await openDatabase(
      fullPath,
      version: 1,
      onCreate: (Database db, int version) async {
        logger.d(
          '$_logPrefix _getDatabase() onCreate() called. creating table=$_tableName',
        );
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            spentAt TEXT NOT NULL,
            categoryCode TEXT NOT NULL,
            subcategoryCode TEXT NOT NULL,
            paymentMethodCode TEXT NOT NULL,
            description TEXT NOT NULL,
            amount INTEGER NOT NULL,
            note TEXT NOT NULL
          )
        ''');
        logger.d('$_logPrefix _getDatabase() table created: $_tableName');
      },
    );

    logger.d('$_logPrefix _getDatabase() database opened successfully.');
    _log('_getDatabase', '데이터베이스 오픈 완료');
    return _database!;
  }

  /// DB에 저장된 모든 지출내역을 최신순으로 조회한다.
  Future<List<ExpenseEntry>> loadAllExpenses() async {
    _log('loadAllExpenses', '지출내역 전체 조회 시작');
    logger.d(
      '$_logPrefix loadAllExpenses() started. platform=${kIsWeb ? 'web' : 'native'}',
    );
    if (kIsWeb) {
      final webEntries = await _loadAllExpensesFromPreferences();
      logger.d(
        '$_logPrefix loadAllExpenses() completed via shared_preferences. count=${webEntries.length}',
      );
      _log('loadAllExpenses', '지출내역 전체 조회 완료(shared_preferences)');
      return webEntries;
    }

    final db = await _getDatabase();
    final rows = await db.query(_tableName, orderBy: 'spentAt DESC');
    final entries = rows.map(_fromRow).toList();
    logger.d(
      '$_logPrefix loadAllExpenses() completed via SQLite. count=${entries.length}',
    );
    _log('loadAllExpenses', '지출내역 전체 조회 완료(SQLite)');
    return entries;
  }

  /// 선택한 월의 지출내역만 최신순으로 조회한다.
  Future<List<ExpenseEntry>> loadExpensesByMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final endExclusive = DateTime(month.year, month.month + 1, 1);
    return loadExpensesByRange(start: start, endExclusive: endExclusive);
  }

  /// 선택한 기간(start <= spentAt < endExclusive)의 지출내역을 최신순으로 조회한다.
  Future<List<ExpenseEntry>> loadExpensesByRange({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    _log('loadExpensesByRange', '기간 지출내역 조회 시작');
    logger.d(
      '$_logPrefix loadExpensesByRange() started. start=$start, endExclusive=$endExclusive, platform=${kIsWeb ? 'web' : 'native'}',
    );

    if (kIsWeb) {
      final entries = await _loadAllExpensesFromPreferences();
      final filtered =
          entries.where((ExpenseEntry entry) {
            return !entry.spentAt.isBefore(start) &&
                entry.spentAt.isBefore(endExclusive);
          }).toList()..sort(
            (ExpenseEntry left, ExpenseEntry right) =>
                right.spentAt.compareTo(left.spentAt),
          );
      _log('loadExpensesByRange', '기간 지출내역 조회 완료(shared_preferences)');
      logger.d(
        '$_logPrefix loadExpensesByRange() completed via shared_preferences. count=${filtered.length}',
      );
      return filtered;
    }

    final db = await _getDatabase();
    final rows = await db.query(
      _tableName,
      where: 'spentAt >= ? AND spentAt < ?',
      whereArgs: <Object?>[
        start.toIso8601String(),
        endExclusive.toIso8601String(),
      ],
      orderBy: 'spentAt DESC',
    );
    final entries = rows.map(_fromRow).toList();
    _log('loadExpensesByRange', '기간 지출내역 조회 완료(SQLite)');
    logger.d(
      '$_logPrefix loadExpensesByRange() completed via SQLite. count=${entries.length}',
    );
    return entries;
  }

  /// 지출내역 1건을 삽입하거나 갱신한다.
  Future<void> upsertExpense(ExpenseEntry entry) async {
    _log('upsertExpense', '지출내역 단건 저장/수정 시작');
    logger.d(
      '$_logPrefix upsertExpense() started. id=${entry.id}, amount=${entry.amount}, platform=${kIsWeb ? 'web' : 'native'}',
    );
    if (kIsWeb) {
      final entries = await _loadAllExpensesFromPreferences();
      final filtered = entries
          .where((ExpenseEntry item) => item.id != entry.id)
          .toList();
      filtered.add(entry);
      await _saveAllExpensesToPreferences(filtered);
      logger.d(
        '$_logPrefix upsertExpense() completed via shared_preferences. total=${filtered.length}',
      );
      _log('upsertExpense', '지출내역 단건 저장/수정 완료(shared_preferences)');
      return;
    }

    final db = await _getDatabase();
    await db.insert(
      _tableName,
      _toRow(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    logger.d(
      '$_logPrefix upsertExpense() completed via SQLite. id=${entry.id}',
    );
    _log('upsertExpense', '지출내역 단건 저장/수정 완료(SQLite)');
  }

  /// 여러 지출내역을 한 번에 삽입하거나 갱신한다.
  Future<void> upsertExpenses(List<ExpenseEntry> entries) async {
    _log('upsertExpenses', '지출내역 다건 저장/수정 시작');
    logger.d(
      '$_logPrefix upsertExpenses() started. inputCount=${entries.length}, platform=${kIsWeb ? 'web' : 'native'}',
    );
    if (entries.isEmpty) {
      _log('upsertExpenses', '입력 목록 비어 있어 저장 스킵');
      logger.d('$_logPrefix upsertExpenses() skipped. input list is empty.');
      return;
    }

    if (kIsWeb) {
      final currentEntries = await _loadAllExpensesFromPreferences();
      final mergedEntries = <String, ExpenseEntry>{
        for (final entry in currentEntries) entry.id: entry,
        for (final entry in entries) entry.id: entry,
      };
      await _saveAllExpensesToPreferences(mergedEntries.values.toList());
      logger.d(
        '$_logPrefix upsertExpenses() completed via shared_preferences. mergedCount=${mergedEntries.length}',
      );
      _log('upsertExpenses', '지출내역 다건 저장/수정 완료(shared_preferences)');
      return;
    }

    final db = await _getDatabase();
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert(
        _tableName,
        _toRow(entry),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    logger.d(
      '$_logPrefix upsertExpenses() completed via SQLite. upsertedCount=${entries.length}',
    );
    _log('upsertExpenses', '지출내역 다건 저장/수정 완료(SQLite)');
  }

  /// 식별자 기준으로 지출내역 1건을 삭제한다.
  Future<void> deleteExpense(String id) async {
    _log('deleteExpense', '지출내역 단건 삭제 시작');
    logger.d(
      '$_logPrefix deleteExpense() started. id=$id, platform=${kIsWeb ? 'web' : 'native'}',
    );
    if (kIsWeb) {
      final entries = await _loadAllExpensesFromPreferences();
      final filtered = entries
          .where((ExpenseEntry item) => item.id != id)
          .toList();
      await _saveAllExpensesToPreferences(filtered);
      logger.d(
        '$_logPrefix deleteExpense() completed via shared_preferences. remaining=${filtered.length}',
      );
      _log('deleteExpense', '지출내역 단건 삭제 완료(shared_preferences)');
      return;
    }

    final db = await _getDatabase();
    final deletedCount = await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
    logger.d(
      '$_logPrefix deleteExpense() completed via SQLite. deletedCount=$deletedCount',
    );
    _log('deleteExpense', '지출내역 단건 삭제 완료(SQLite)');
  }

  /// 메타데이터 태그 코드 변경 시 소비기록의 참조 코드를 SQL UPDATE로 일괄 치환한다.
  Future<void> replaceExpenseTagCode({
    required MetadataTagType type,
    required String fromCode,
    required String toCode,
  }) async {
    _log('replaceExpenseTagCode', '소비기록 태그 코드 일괄 치환 시작');
    if (fromCode == toCode) {
      _log('replaceExpenseTagCode', '치환 스킵(fromCode == toCode)');
      return;
    }

    String columnName;
    switch (type) {
      case MetadataTagType.category:
        columnName = 'categoryCode';
      case MetadataTagType.subcategory:
        columnName = 'subcategoryCode';
      case MetadataTagType.paymentMethod:
        columnName = 'paymentMethodCode';
    }

    if (kIsWeb) {
      final entries = await _loadAllExpensesFromPreferences();
      final replacedEntries = entries.map((ExpenseEntry entry) {
        switch (type) {
          case MetadataTagType.category:
            return entry.categoryCode == fromCode
                ? entry.copyWith(categoryCode: toCode)
                : entry;
          case MetadataTagType.subcategory:
            return entry.subcategoryCode == fromCode
                ? entry.copyWith(subcategoryCode: toCode)
                : entry;
          case MetadataTagType.paymentMethod:
            return entry.paymentMethodCode == fromCode
                ? entry.copyWith(paymentMethodCode: toCode)
                : entry;
        }
      }).toList();
      await _saveAllExpensesToPreferences(replacedEntries);
      _log('replaceExpenseTagCode', '소비기록 태그 코드 일괄 치환 완료(shared_preferences)');
      return;
    }

    final db = await _getDatabase();
    final query =
        'UPDATE $_tableName SET $columnName = ? WHERE $columnName = ?';
    final updatedCount = await db.rawUpdate(query, <Object?>[toCode, fromCode]);
    logger.d(
      '$_logPrefix replaceExpenseTagCode() query="$query", args=[$toCode, $fromCode], updatedCount=$updatedCount',
    );
    _log('replaceExpenseTagCode', '소비기록 태그 코드 일괄 치환 완료(SQLite)');
  }

  /// Web 환경에서 shared_preferences로 저장된 지출내역을 불러온다.
  Future<List<ExpenseEntry>> _loadAllExpensesFromPreferences() async {
    _log('_loadAllExpensesFromPreferences', 'shared_preferences 지출내역 로드 시작');
    logger.d(
      '$_logPrefix _loadAllExpensesFromPreferences() started. key=$_webStorageKey',
    );
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_webStorageKey);
    if (rawValue == null || rawValue.isEmpty) {
      _log('_loadAllExpensesFromPreferences', '저장된 지출내역 없음');
      logger.d(
        '$_logPrefix _loadAllExpensesFromPreferences() no saved entries found.',
      );
      return <ExpenseEntry>[];
    }

    final decoded = jsonDecode(rawValue) as List<dynamic>;
    final entries = decoded
        .map(
          (dynamic item) => ExpenseEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    entries.sort(
      (ExpenseEntry left, ExpenseEntry right) =>
          right.spentAt.compareTo(left.spentAt),
    );
    logger.d(
      '$_logPrefix _loadAllExpensesFromPreferences() completed. count=${entries.length}',
    );
    _log('_loadAllExpensesFromPreferences', 'shared_preferences 지출내역 로드 완료');
    return entries;
  }

  /// Web 환경에서 shared_preferences로 지출내역 전체를 저장한다.
  Future<void> _saveAllExpensesToPreferences(List<ExpenseEntry> entries) async {
    _log('_saveAllExpensesToPreferences', 'shared_preferences 지출내역 저장 시작');
    logger.d(
      '$_logPrefix _saveAllExpensesToPreferences() started. inputCount=${entries.length}, key=$_webStorageKey',
    );
    final preferences = await SharedPreferences.getInstance();
    final sortedEntries = <ExpenseEntry>[...entries]
      ..sort(
        (ExpenseEntry left, ExpenseEntry right) =>
            right.spentAt.compareTo(left.spentAt),
      );
    await preferences.setString(
      _webStorageKey,
      jsonEncode(
        sortedEntries.map((ExpenseEntry entry) => entry.toJson()).toList(),
      ),
    );
    logger.d(
      '$_logPrefix _saveAllExpensesToPreferences() completed. savedCount=${sortedEntries.length}',
    );
    _log('_saveAllExpensesToPreferences', 'shared_preferences 지출내역 저장 완료');
  }

  /// 지출내역 모델을 DB 저장용 행으로 변환한다.
  Map<String, Object?> _toRow(ExpenseEntry entry) {
    _log('_toRow', '지출내역 모델을 DB 행으로 변환');
    logger.d('$_logPrefix _toRow() called. id=${entry.id}');
    return <String, Object?>{
      'id': entry.id,
      'spentAt': entry.spentAt.toIso8601String(),
      'categoryCode': entry.categoryCode,
      'subcategoryCode': entry.subcategoryCode,
      'paymentMethodCode': entry.paymentMethodCode,
      'description': entry.description,
      'amount': entry.amount,
      'note': entry.note,
    };
  }

  /// DB 행을 지출내역 모델로 변환한다.
  ExpenseEntry _fromRow(Map<String, Object?> row) {
    _log('_fromRow', 'DB 행을 지출내역 모델로 변환');
    logger.d('$_logPrefix _fromRow() called. id=${row['id']}');
    return ExpenseEntry.create(
      id: row['id']! as String,
      spentAt: DateTime.parse(row['spentAt']! as String),
      categoryCode: row['categoryCode']! as String,
      subcategoryCode: row['subcategoryCode']! as String,
      paymentMethodCode: row['paymentMethodCode']! as String,
      description: row['description']! as String,
      amount: row['amount']! as int,
      note: row['note']! as String,
    );
  }
}
