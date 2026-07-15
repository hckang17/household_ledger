// 가계부 데이터를 .csv 파일로 내보내거나, .csv 파일에서 가계부 데이터를 불러오는 기능을 담당하는 서비스입니다.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:household_ledger/model/app_settings.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/user_profile.dart';
import 'package:household_ledger/services/tutorial_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// import 결과를 담는 값 객체다.
class ImportResult {
  /// import 결과를 생성한다.
  const ImportResult({
    required this.success,
    this.errorKey,
    this.expenses = const <ExpenseEntry>[],
    this.fixedExpenses = const <FixedExpense>[],
    this.incomes = const <IncomeEntry>[],
    this.ledgerState,
  });

  /// 성공 여부를 보관한다.
  final bool success;

  /// 실패 시 로컬라이제이션 키를 보관한다.
  final String? errorKey;

  /// 복원된 지출내역을 보관한다.
  final List<ExpenseEntry> expenses;

  /// 복원된 고정지출을 보관한다.
  final List<FixedExpense> fixedExpenses;

  /// 복원된 소득내역을 보관한다.
  final List<IncomeEntry> incomes;

  /// 복원된 앱 상태(설정, 태그 포함)를 보관한다.
  final LedgerState? ledgerState;
}

/// 가계부 데이터를 CSV로 직렬화/역직렬화하는 서비스다.
class DataImExportService {
  static const String _sectionMetadata = '[METADATA]';
  static const String _sectionExpenses = '[EXPENSES]';
  static const String _sectionFixedExpenses = '[FIXED_EXPENSES]';
  static const String _sectionIncomes = '[INCOMES]';
  static const String _sectionSettings = '[SETTINGS]';
  static const String _sectionTags = '[TAGS]';
  static const String _csvVersion = '2.0';
  static const String _salt = 'household_ledger_v1_salt';

  String _generateSignature(String email, String passkey) {
    final input = '$email|$passkey|$_salt';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// 이메일과 인증 키가 파일의 서명과 일치하는지 검증한다.
  bool verifySignature(String email, String passkey, String storedSignature) {
    return _generateSignature(email, passkey) == storedSignature;
  }

  String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _csvRow(List<String> fields) {
    return fields.map(_escapeCsv).join(',');
  }

  /// 전체 데이터를 CSV 문자열로 직렬화한다.
  String buildCsvContent({
    required List<ExpenseEntry> expenses,
    required List<FixedExpense> fixedExpenses,
    required List<IncomeEntry> incomes,
    required LedgerState ledgerState,
    required String email,
    required String passkey,
    required String timestamp,
    bool tutorialCompleted = false,
    int tutorialVersion = 1,
  }) {
    final buffer = StringBuffer();
    final signature = _generateSignature(email, passkey);

    buffer.writeln(_sectionMetadata);
    buffer.writeln(_csvRow(['version', _csvVersion]));
    buffer.writeln(_csvRow(['exportedAt', timestamp]));
    buffer.writeln(_csvRow(['email', email]));
    buffer.writeln(_csvRow(['signature', signature]));
    buffer.writeln();

    buffer.writeln(_sectionExpenses);
    buffer.writeln(
      'id,spentAt,categoryCode,subcategoryCode,diningOccasionCode,paymentMethodCode,description,amount,note',
    );
    for (final e in expenses) {
      buffer.writeln(
        _csvRow([
          e.id,
          e.spentAt.toIso8601String(),
          e.categoryCode,
          e.subcategoryCode,
          e.diningOccasionCode ?? '',
          e.paymentMethodCode,
          e.description,
          e.amount.toString(),
          e.note,
        ]),
      );
    }
    buffer.writeln();

    buffer.writeln(_sectionFixedExpenses);
    buffer.writeln(
      'id,appliedAt,categoryCode,paymentMethodCode,description,amount,note',
    );
    for (final e in fixedExpenses) {
      buffer.writeln(
        _csvRow([
          e.id,
          e.appliedAt.toIso8601String(),
          e.categoryCode,
          e.paymentMethodCode,
          e.description,
          e.amount.toString(),
          e.note,
        ]),
      );
    }
    buffer.writeln();

    buffer.writeln(_sectionIncomes);
    buffer.writeln('id,earnedAt,amount,description');
    for (final e in incomes) {
      buffer.writeln(
        _csvRow([
          e.id?.toString() ?? '',
          e.earnedAt.toIso8601String(),
          e.amount.toString(),
          e.description,
        ]),
      );
    }
    buffer.writeln();

    buffer.writeln(_sectionSettings);
    buffer.writeln('key,value');
    buffer.writeln(_csvRow(['localeCode', ledgerState.settings.localeCode]));
    buffer.writeln(
      _csvRow(['currencyUnit', ledgerState.settings.currencyUnit]),
    );
    buffer.writeln(
      _csvRow(['monthlyBudget', ledgerState.settings.monthlyBudget.toString()]),
    );
    buffer.writeln(_csvRow(['userName', ledgerState.userProfile.name]));
    buffer.writeln(
      _csvRow(['userAge', ledgerState.userProfile.age.toString()]),
    );
    buffer.writeln(
      _csvRow(['tutorial_completed', tutorialCompleted.toString()]),
    );
    buffer.writeln(_csvRow(['tutorial_version', tutorialVersion.toString()]));
    buffer.writeln();

    buffer.writeln(_sectionTags);
    buffer.writeln('type,code,label');
    for (final tag in ledgerState.metadataTags) {
      buffer.writeln(_csvRow([tag.type.name, tag.code, tag.label]));
    }

    return buffer.toString();
  }

  static const String _exportFolderName = 'HouseLedger';

  /// Android 외부 저장소(또는 앱 문서 폴더) 아래에 HouseLedger 폴더를 만들고 CSV를 저장한다.
  /// 저장된 파일의 절대 경로를 반환한다.
  Future<String> exportData({
    required List<ExpenseEntry> expenses,
    required List<FixedExpense> fixedExpenses,
    required List<IncomeEntry> incomes,
    required LedgerState ledgerState,
    required String email,
    required String passkey,
    required String timestamp,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web export is not supported in this version.');
    }

    final tutorialValues = await TutorialService().exportValues();
    final tutorialCompleted = tutorialValues['tutorial_completed'] == 'true';
    final tutorialVersion =
        int.tryParse(tutorialValues['tutorial_version'] ?? '1') ?? 1;

    final csvContent = buildCsvContent(
      expenses: expenses,
      fixedExpenses: fixedExpenses,
      incomes: incomes,
      ledgerState: ledgerState,
      email: email,
      passkey: passkey,
      timestamp: timestamp,
      tutorialCompleted: tutorialCompleted,
      tutorialVersion: tutorialVersion,
    );

    // UTF-8 BOM을 추가해 스프레드시트에서 한글·일본어가 올바르게 표시되도록 한다.
    final contentWithBom = '﻿$csvContent';

    final saveDir = await _resolveSaveDirectory();
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final fileName = 'houseledger_$timestamp.csv';
    final file = File('${saveDir.path}/$fileName');
    await file.writeAsString(contentWithBom, encoding: utf8);
    return file.path;
  }

  /// 저장된 파일을 OS 공유 시트로 공유한다.
  Future<void> shareFile(String filePath) async {
    await Share.shareXFiles([XFile(filePath, mimeType: 'text/csv')]);
  }

  /// 플랫폼별 저장 디렉터리를 결정한다.
  /// Android: /storage/emulated/0/Android/data/{package}/files/HouseLedger
  /// iOS/기타: {DocumentsDir}/HouseLedger
  Future<Directory> _resolveSaveDirectory() async {
    if (Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        return Directory('${extDir.path}/$_exportFolderName');
      }
    }
    final docDir = await getApplicationDocumentsDirectory();
    return Directory('${docDir.path}/$_exportFolderName');
  }

  /// 파일 선택 다이얼로그를 열고 선택된 CSV 파일 경로를 반환한다.
  Future<String?> pickImportFile() async {
    const csvTypeGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final file = await openFile(acceptedTypeGroups: [csvTypeGroup]);
    return file?.path;
  }

  /// CSV 파일 내용을 파싱해 가계부 데이터를 복원한다. 서명 불일치 시 실패를 반환한다.
  Future<ImportResult> importFromCsv({
    required String csvContent,
    required String email,
    required String passkey,
  }) async {
    try {
      // BOM 제거
      final content = csvContent.startsWith('﻿')
          ? csvContent.substring(1)
          : csvContent;

      final sections = _parseSections(content);

      final metaMap = _parseKeyValue(sections[_sectionMetadata] ?? <String>[]);
      final storedSignature = metaMap['signature'] ?? '';

      if (!verifySignature(email, passkey, storedSignature)) {
        return const ImportResult(
          success: false,
          errorKey: 'invalidSignatureMessage',
        );
      }

      final expenses = _parseExpenses(sections[_sectionExpenses] ?? <String>[]);
      final fixedExpenses = _parseFixedExpenses(
        sections[_sectionFixedExpenses] ?? <String>[],
      );
      final incomes = _parseIncomes(sections[_sectionIncomes] ?? <String>[]);
      final settingsMap = _parseKeyValue(
        sections[_sectionSettings] ?? <String>[],
      );
      final tags = _parseTags(sections[_sectionTags] ?? <String>[]);

      final settings = AppSettings(
        localeCode: settingsMap['localeCode'] ?? 'ko',
        currencyUnit: settingsMap['currencyUnit'] ?? '₩',
        monthlyBudget: int.tryParse(settingsMap['monthlyBudget'] ?? '') ?? 0,
        onboardingCompleted: true,
      );
      final profile = UserProfile(
        name: settingsMap['userName'] ?? '',
        age: int.tryParse(settingsMap['userAge'] ?? '') ?? 0,
      );

      if (!tags.any(
        (MetadataTag tag) => tag.type == MetadataTagType.diningOccasion,
      )) {
        final isJa = settings.localeCode == 'jp' || settings.localeCode == 'ja';
        tags.addAll(<MetadataTag>[
          MetadataTag(
            type: MetadataTagType.diningOccasion,
            code: 'breakfast',
            label: isJa ? '朝食' : '아침',
          ),
          MetadataTag(
            type: MetadataTagType.diningOccasion,
            code: 'brunch',
            label: isJa ? 'ブランチ' : '브런치',
          ),
          MetadataTag(
            type: MetadataTagType.diningOccasion,
            code: 'lunch',
            label: isJa ? '昼食' : '점심',
          ),
          MetadataTag(
            type: MetadataTagType.diningOccasion,
            code: 'snack',
            label: isJa ? '間食' : '간식',
          ),
          MetadataTag(
            type: MetadataTagType.diningOccasion,
            code: 'dinner',
            label: isJa ? '夕食' : '저녁',
          ),
          MetadataTag(
            type: MetadataTagType.diningOccasion,
            code: 'lateNight',
            label: isJa ? '夜食' : '야식',
          ),
          MetadataTag(
            type: MetadataTagType.diningOccasion,
            code: 'company',
            label: isJa ? '会食' : '회식',
          ),
        ]);
      }

      if (settingsMap.containsKey('tutorial_completed')) {
        await TutorialService().restoreFromCsv(
          completed: settingsMap['tutorial_completed'] == 'true',
          version: int.tryParse(settingsMap['tutorial_version'] ?? '1') ?? 1,
        );
      }

      final ledgerState = LedgerState.initial().copyWith(
        settings: settings,
        userProfile: profile,
        metadataTags: tags.isNotEmpty ? tags : null,
      );

      return ImportResult(
        success: true,
        expenses: expenses,
        fixedExpenses: fixedExpenses,
        incomes: incomes,
        ledgerState: ledgerState,
      );
    } catch (_) {
      return const ImportResult(
        success: false,
        errorKey: 'invalidFileFormatMessage',
      );
    }
  }

  Map<String, List<String>> _parseSections(String content) {
    final result = <String, List<String>>{};
    String? current;

    for (var line in content.split('\n')) {
      line = line.trimRight();
      if (line.startsWith('[') && line.endsWith(']')) {
        current = line;
        result[current] = <String>[];
      } else if (current != null && line.isNotEmpty) {
        result[current]!.add(line);
      }
    }
    return result;
  }

  Map<String, String> _parseKeyValue(List<String> rows) {
    final result = <String, String>{};
    for (final row in rows) {
      final fields = _parseCsvRow(row);
      if (fields.length >= 2) {
        result[fields[0]] = fields[1];
      }
    }
    return result;
  }

  List<ExpenseEntry> _parseExpenses(List<String> rows) {
    if (rows.isEmpty) {
      return <ExpenseEntry>[];
    }
    final result = <ExpenseEntry>[];
    final header = _parseCsvRow(rows.first);
    final indexes = <String, int>{
      for (var i = 0; i < header.length; i++) header[i]: i,
    };
    String field(List<String> fields, String name) {
      final index = indexes[name];
      if (index == null || index >= fields.length) return '';
      return fields[index];
    }

    for (final row in rows.skip(1)) {
      final f = _parseCsvRow(row);
      if (f.length < 8) {
        continue;
      }
      try {
        result.add(
          ExpenseEntry.create(
            id: field(f, 'id'),
            spentAt: DateTime.parse(field(f, 'spentAt')),
            categoryCode: field(f, 'categoryCode'),
            subcategoryCode: field(f, 'subcategoryCode'),
            diningOccasionCode: field(f, 'diningOccasionCode'),
            paymentMethodCode: field(f, 'paymentMethodCode'),
            description: field(f, 'description'),
            amount: int.parse(field(f, 'amount')),
            note: field(f, 'note'),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  List<FixedExpense> _parseFixedExpenses(List<String> rows) {
    if (rows.isEmpty) {
      return <FixedExpense>[];
    }
    final result = <FixedExpense>[];
    for (final row in rows.skip(1)) {
      final f = _parseCsvRow(row);
      if (f.length < 7) {
        continue;
      }
      try {
        result.add(
          FixedExpense.create(
            id: f[0],
            appliedAt: DateTime.parse(f[1]),
            categoryCode: f[2],
            paymentMethodCode: f[3],
            description: f[4],
            amount: int.parse(f[5]),
            note: f[6],
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  List<IncomeEntry> _parseIncomes(List<String> rows) {
    if (rows.isEmpty) {
      return <IncomeEntry>[];
    }
    final result = <IncomeEntry>[];
    for (final row in rows.skip(1)) {
      final f = _parseCsvRow(row);
      if (f.length < 4) {
        continue;
      }
      try {
        result.add(
          IncomeEntry.create(
            id: int.tryParse(f[0]),
            earnedAt: DateTime.parse(f[1]),
            amount: int.parse(f[2]),
            description: f[3],
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  List<MetadataTag> _parseTags(List<String> rows) {
    if (rows.isEmpty) {
      return <MetadataTag>[];
    }
    final result = <MetadataTag>[];
    for (final row in rows.skip(1)) {
      final f = _parseCsvRow(row);
      if (f.length < 3) {
        continue;
      }
      try {
        final type = MetadataTagType.values.firstWhere(
          (MetadataTagType t) => t.name == f[0],
          orElse: () => MetadataTagType.category,
        );
        result.add(MetadataTag(type: type, code: f[1], label: f[2]));
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  /// RFC 4180 준수 CSV 행 파서다.
  List<String> _parseCsvRow(String row) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < row.length; i++) {
      final char = row[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < row.length && row[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          fields.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
    }
    fields.add(buffer.toString());
    return fields;
  }
}
