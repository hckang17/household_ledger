import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/provider/ledger_provider.dart';

/// 전월동기 비교 연산 결과를 담는 불변 데이터 클래스이다.
class ComparisonResult {
  const ComparisonResult({
    required this.diff,
    required this.diffPercent,
    required this.moreSpent,
    required this.catDiffs,
  });

  /// 현월 총액 − 전월 총액 (양수: 더 사용, 음수: 덜 사용)
  final int diff;

  /// |diff| / prevTotal × 100
  final double diffPercent;

  /// diff > 0
  final bool moreSpent;

  /// 카테고리코드 → 증감액 (절댓값 내림차순, 증감 없는 카테고리 제외)
  final List<MapEntry<String, int>> catDiffs;

  /// catDiffs 중 지출이 늘어난 카테고리만
  List<MapEntry<String, int>> get gainers =>
      catDiffs.where((MapEntry<String, int> e) => e.value > 0).toList();
}

/// 현월과 전월동기 지출 데이터를 비교해 [ComparisonResult]를 제공한다.
///
/// 전월 데이터가 없으면 null을 반환한다.
final comparisonProvider = Provider<ComparisonResult?>((Ref ref) {
  final ledger = ref.watch(ledgerProvider).asData?.value;
  if (ledger == null) return null;

  final List<ExpenseEntry> prevExpenses = ledger.prevPeriodExpenses;
  if (prevExpenses.isEmpty) return null;

  final List<ExpenseEntry> currentExpenses = ledger.expenses;

  final int currentTotal =
      currentExpenses.fold(0, (int s, ExpenseEntry e) => s + e.amount);
  final int prevTotal =
      prevExpenses.fold(0, (int s, ExpenseEntry e) => s + e.amount);
  final int diff = currentTotal - prevTotal;
  final double diffPercent =
      prevTotal > 0 ? (diff.abs() / prevTotal * 100) : 0.0;

  // 카테고리별 집계
  final Map<String, int> curCat = <String, int>{};
  for (final ExpenseEntry e in currentExpenses) {
    curCat.update(
      e.categoryCode,
      (int v) => v + e.amount,
      ifAbsent: () => e.amount,
    );
  }
  final Map<String, int> preCat = <String, int>{};
  for (final ExpenseEntry e in prevExpenses) {
    preCat.update(
      e.categoryCode,
      (int v) => v + e.amount,
      ifAbsent: () => e.amount,
    );
  }

  final Set<String> allCodes = <String>{...curCat.keys, ...preCat.keys};
  final List<MapEntry<String, int>> catDiffs = allCodes
      .map(
        (String code) => MapEntry<String, int>(
          code,
          (curCat[code] ?? 0) - (preCat[code] ?? 0),
        ),
      )
      .where((MapEntry<String, int> e) => e.value != 0)
      .toList()
    ..sort(
      (MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.abs().compareTo(a.value.abs()),
    );

  return ComparisonResult(
    diff: diff,
    diffPercent: diffPercent,
    moreSpent: diff > 0,
    catDiffs: catDiffs,
  );
});
