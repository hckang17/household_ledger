import 'package:household_ledger/model/data_search_filter.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';

/// 데이터 검색/필터 로직 (분석, 소비기록 등에서 재사용 가능)
class DataSearchService {
  const DataSearchService._();

  static List<ExpenseEntry> filterExpenses(
    List<ExpenseEntry> all,
    DataSearchFilter filter,
  ) {
    return all.where((ExpenseEntry e) {
      if (!_matchDate(e.spentAt, filter)) {
        return false;
      }
      if (filter.paymentMethodCode != null &&
          e.paymentMethodCode != filter.paymentMethodCode) {
        return false;
      }
      if (filter.categoryCode != null &&
          e.categoryCode != filter.categoryCode) {
        return false;
      }
      if (filter.descriptionQuery.isNotEmpty &&
          !e.description.toLowerCase().contains(
            filter.descriptionQuery.toLowerCase(),
          )) {
        return false;
      }
      if (filter.noteQuery.isNotEmpty &&
          !e.note.toLowerCase().contains(filter.noteQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  static List<FixedExpense> filterFixedExpenses(
    List<FixedExpense> all,
    DataSearchFilter filter,
  ) {
    return all.where((FixedExpense e) {
      if (!_matchDate(e.appliedAt, filter)) {
        return false;
      }
      if (filter.paymentMethodCode != null &&
          e.paymentMethodCode != filter.paymentMethodCode) {
        return false;
      }
      if (filter.categoryCode != null &&
          e.categoryCode != filter.categoryCode) {
        return false;
      }
      if (filter.descriptionQuery.isNotEmpty &&
          !e.description.toLowerCase().contains(
            filter.descriptionQuery.toLowerCase(),
          )) {
        return false;
      }
      if (filter.noteQuery.isNotEmpty &&
          !e.note.toLowerCase().contains(filter.noteQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  static List<IncomeEntry> filterIncomes(
    List<IncomeEntry> all,
    DataSearchFilter filter,
  ) {
    return all.where((IncomeEntry e) {
      if (!_matchDate(e.earnedAt, filter)) {
        return false;
      }
      if (filter.descriptionQuery.isNotEmpty &&
          !e.description.toLowerCase().contains(
            filter.descriptionQuery.toLowerCase(),
          )) {
        return false;
      }
      return true;
    }).toList();
  }

  static bool _matchDate(DateTime date, DataSearchFilter filter) {
    switch (filter.dateRangeType) {
      case DateRangeType.all:
        return true;
      case DateRangeType.month:
        if (filter.selectedMonth == null) {
          return true;
        }
        return date.year == filter.selectedMonth!.year &&
            date.month == filter.selectedMonth!.month;
      case DateRangeType.period:
        final DateTime? start = filter.startDate;
        final DateTime? end = filter.endDate;
        if (start == null && end == null) {
          return true;
        }
        final DateTime d = DateTime(date.year, date.month, date.day);
        if (start != null &&
            d.isBefore(DateTime(start.year, start.month, start.day))) {
          return false;
        }
        if (end != null && d.isAfter(DateTime(end.year, end.month, end.day))) {
          return false;
        }
        return true;
    }
  }
}
