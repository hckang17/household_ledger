import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/services/database/fixed_expense_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final fixedExpenseCarryoverControllerProvider =
    Provider<FixedExpenseCarryoverController>((Ref ref) {
      return FixedExpenseCarryoverController(
        database: ref.read(fixedExpenseDatabaseServiceProvider),
      );
    });

/// 빈 월에 지난달 고정지출을 제안하고 복사하는 흐름을 관리한다.
class FixedExpenseCarryoverController {
  FixedExpenseCarryoverController({required this.database});

  final FixedExpenseDatabaseService database;

  static const String _suppressedMonthsKey =
      'household_ledger_fixed_expense_carryover_suppressed_months';

  /// 숨김 처리되지 않은 빈 월이면 제안 가능한 지난달 항목 수를 반환한다.
  Future<int> findOfferCount(DateTime targetMonth) async {
    final target = DateTime(targetMonth.year, targetMonth.month, 1);
    final preferences = await SharedPreferences.getInstance();
    final monthKey = _monthKey(target);
    final suppressedMonths =
        preferences.getStringList(_suppressedMonthsKey) ?? <String>[];
    if (suppressedMonths.contains(monthKey)) return 0;

    final current = await database.loadFixedExpensesByMonth(target);
    if (current.isNotEmpty) return 0;

    final previous = await database.loadFixedExpensesByMonth(
      DateTime(target.year, target.month - 1, 1),
    );
    return previous.length;
  }

  /// 사용자가 거절하며 선택한 대상 월에는 제안을 다시 표시하지 않는다.
  Future<void> suppressForMonth(DateTime targetMonth) async {
    final preferences = await SharedPreferences.getInstance();
    final monthKey = _monthKey(targetMonth);
    final suppressedMonths =
        preferences.getStringList(_suppressedMonthsKey) ?? <String>[];
    if (suppressedMonths.contains(monthKey)) return;
    await preferences.setStringList(_suppressedMonthsKey, <String>[
      ...suppressedMonths,
      monthKey,
    ]);
  }

  /// 지난달 항목을 대상 월로 복사한다. 금액은 모두 0으로 초기화한다.
  Future<List<FixedExpense>> copyPreviousMonth(DateTime targetMonth) async {
    final target = DateTime(targetMonth.year, targetMonth.month, 1);
    if ((await database.loadFixedExpensesByMonth(target)).isNotEmpty) {
      return const <FixedExpense>[];
    }

    final previous = await database.loadFixedExpensesByMonth(
      DateTime(target.year, target.month - 1, 1),
    );
    final copied = previous
        .map(
          (FixedExpense item) => item.copyWith(
            id: 'carryover-${_monthKey(target)}-${item.id}',
            appliedAt: target,
            amount: 0,
          ),
        )
        .toList(growable: false);
    await database.upsertFixedExpenses(copied);
    return copied;
  }

  static String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';
}
