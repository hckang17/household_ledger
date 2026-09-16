import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';

/// CSV 버전별 구조 계약. 정상적인 빈 목록과 헤더가 유실된 목록을 구분한다.
class BackupCsvValidation {
  static void validateTags(
    List<MetadataTag> tags,
    List<ExpenseEntry> expenses,
    List<FixedExpense> fixedExpenses,
  ) {
    final ids = tags.map((tag) => '${tag.type.name}:${tag.code}').toList();
    if (ids.toSet().length != ids.length ||
        tags.any(
          (tag) => tag.code.trim().isEmpty || tag.label.trim().isEmpty,
        )) {
      throw const FormatException('Invalid or duplicate tag');
    }
    bool known(MetadataTagType type, String code) =>
        systemMetadataTagLocalizationKeys[type]!.containsKey(code) ||
        tags.any((tag) => tag.type == type && tag.code == code);
    for (final expense in expenses) {
      if (!known(MetadataTagType.category, expense.categoryCode) ||
          !known(MetadataTagType.subcategory, expense.subcategoryCode) ||
          !known(MetadataTagType.paymentMethod, expense.paymentMethodCode) ||
          (expense.diningOccasionCode != null &&
              !known(
                MetadataTagType.diningOccasion,
                expense.diningOccasionCode!,
              ))) {
        throw const FormatException('Unknown expense tag');
      }
    }
    for (final expense in fixedExpenses) {
      if (!known(MetadataTagType.category, expense.categoryCode) ||
          !known(MetadataTagType.paymentMethod, expense.paymentMethodCode)) {
        throw const FormatException('Unknown fixed expense tag');
      }
    }
  }

  static void validate(
    Map<String, List<String>> sections,
    int version,
    List<String> Function(String) parseRow,
  ) {
    const headers = <String, List<String>>{
      '[EXPENSES]': [
        'id',
        'spentAt',
        'categoryCode',
        'subcategoryCode',
        'paymentMethodCode',
        'description',
        'amount',
        'note',
      ],
      '[FIXED_EXPENSES]': [
        'id',
        'appliedAt',
        'categoryCode',
        'paymentMethodCode',
        'description',
        'amount',
        'note',
      ],
      '[INCOMES]': ['id', 'earnedAt', 'amount', 'description'],
      '[TRIPS]': [
        'id',
        'name',
        'startDate',
        'endDate',
        'budget',
        'note',
        'createdAt',
        'updatedAt',
        'archivedAt',
      ],
      '[SETTINGS]': ['key', 'value'],
      '[TAGS]': ['type', 'code', 'label'],
    };
    for (final entry in headers.entries) {
      final rows = sections[entry.key];
      // Older backups can omit sections introduced after their writer version.
      if (rows == null && version < 3 && entry.key != '[EXPENSES]') continue;
      if (rows == null || rows.isEmpty) {
        throw const FormatException('Missing section header');
      }
      final header = parseRow(rows.first);
      if (header.toSet().length != header.length ||
          !entry.value.every(header.contains) ||
          (version >= 3 &&
              entry.key == '[EXPENSES]' &&
              !header.contains('tripId'))) {
        throw const FormatException('Invalid section header');
      }
      // These readers use positional fields; do not reinterpret a shuffled header.
      if ([
        '[FIXED_EXPENSES]',
        '[INCOMES]',
        '[SETTINGS]',
        '[TAGS]',
      ].contains(entry.key)) {
        for (var i = 0; i < entry.value.length; i++) {
          if (header[i] != entry.value[i]) {
            throw const FormatException('Invalid field order');
          }
        }
      }
      for (final row in rows.skip(1)) {
        final fields = parseRow(row);
        if (fields.length != header.length) {
          throw const FormatException('Incomplete record');
        }
        for (var i = 0; i < header.length; i++) {
          if ([
            'spentAt',
            'appliedAt',
            'earnedAt',
            'startDate',
            'endDate',
            'createdAt',
            'updatedAt',
            'archivedAt',
          ].contains(header[i])) {
            if (header[i] == 'archivedAt' && fields[i].isEmpty) continue;
            validateDate(fields[i]);
          }
          if (header[i] == 'id' &&
              entry.key != '[INCOMES]' &&
              fields[i].trim().isEmpty) {
            throw const FormatException('Empty identifier');
          }
        }
      }
    }
    if (version >= 3) {
      final keys = sections['[SETTINGS]']!
          .skip(1)
          .map(parseRow)
          .map((f) => f.first)
          .toSet();
      if (![
        'localeCode',
        'currencyUnit',
        'monthlyBudget',
      ].every(keys.contains)) {
        throw const FormatException('Incomplete settings');
      }
    }
  }

  /// DateTime.parse normalizes February 30; backups must reject such dates.
  static void validateDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:T|$)').firstMatch(value);
    if (match == null) throw const FormatException('Invalid date');
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateTime(year, month + 1, 0).day) {
      throw const FormatException('Invalid calendar date');
    }
    DateTime.parse(value);
    final time = RegExp(r'T(\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(value);
    if (time != null &&
        (int.parse(time[1]!) > 23 ||
            int.parse(time[2]!) > 59 ||
            int.parse(time[3] ?? '0') > 59)) {
      throw const FormatException('Invalid clock time');
    }
  }
}
