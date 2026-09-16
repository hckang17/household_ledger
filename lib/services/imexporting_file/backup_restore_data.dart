import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/trip.dart';

/// 전체 복원과 복구본이 공유하는 저장 데이터. 설정은 원문/키 부재까지 보존한다.
class BackupRestoreData {
  BackupRestoreData({
    required this.expenses,
    required this.fixedExpenses,
    required this.incomes,
    required this.trips,
    required this.preferences,
  });

  final List<ExpenseEntry> expenses;
  final List<FixedExpense> fixedExpenses;
  final List<IncomeEntry> incomes;
  final List<Trip> trips;
  final Map<String, Object?> preferences;

  Map<String, dynamic> toJson() => {
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'fixedExpenses': fixedExpenses.map((e) => e.toJson()).toList(),
    'incomes': incomes
        .map(
          (e) => <String, Object?>{
            'id': e.id,
            'earnedAt': e.earnedAt.toIso8601String(),
            'amount': e.amount,
            'description': e.description,
          },
        )
        .toList(),
    'trips': trips.map((e) => e.toJson()).toList(),
    'preferences': preferences,
  };

  factory BackupRestoreData.fromJson(
    Map<String, dynamic> json,
  ) => BackupRestoreData(
    expenses: (json['expenses'] as List)
        .map((e) => ExpenseEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    fixedExpenses: (json['fixedExpenses'] as List)
        .map((e) => FixedExpense.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    incomes: (json['incomes'] as List)
        .map(
          (e) => IncomeEntry(
            id: e['id'] as int?,
            earnedAt: DateTime.parse(e['earnedAt'] as String),
            amount: e['amount'] as int,
            description: e['description'] as String,
          ),
        )
        .toList(),
    trips: (json['trips'] as List)
        .map((e) => Trip.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    preferences: Map<String, Object?>.from(json['preferences'] as Map),
  );

  /// 입력 ID 충돌은 SQLite replace가 실행되기 전에 거절한다.
  void validate() {
    void unique(Iterable<Object?> values) {
      final ids = values.where((e) => e != null).toList();
      if (ids.any((e) => e is String && e.trim().isEmpty) ||
          ids.toSet().length != ids.length) {
        throw const FormatException('Invalid or duplicate identifier');
      }
    }

    unique(expenses.map((e) => e.id));
    unique(fixedExpenses.map((e) => e.id));
    unique(incomes.map((e) => e.id));
    unique(trips.map((e) => e.id));
    final tripIds = trips.map((e) => e.id).toSet();
    if (expenses.any(
      (e) =>
          e.tripId != null &&
          (e.subcategoryCode != 't' || !tripIds.contains(e.tripId)),
    )) {
      throw const FormatException('Invalid trip reference');
    }
  }

  /// 구버전의 ID 없는 수입도 Web/SQLite에서 각각 독립된 행으로 저장한다.
  BackupRestoreData withIncomeIds() {
    var next = incomes.fold<int>(
      0,
      (max, e) => (e.id ?? 0) > max ? e.id! : max,
    );
    return BackupRestoreData(
      expenses: expenses,
      fixedExpenses: fixedExpenses,
      incomes: incomes
          .map((e) => e.id == null ? e.copyWith(id: ++next) : e)
          .toList(),
      trips: trips,
      preferences: preferences,
    );
  }
}
