import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
// WidgetRef is used because this service is called only from widget contexts.

/// 튜토리얼용 임시 더미 데이터를 삽입·삭제하는 서비스다.
///
/// note 필드에 [_mockTag]를 기록해 식별한다.
class MockDataService {
  static const String mockTag = '__tutorial_mock__';

  /// 이번에 삽입한 더미 데이터의 ID 목록.
  final List<String> _insertedIds = [];

  /// 튜토리얼용 더미 지출 내역을 삽입한다.
  ///
  /// - 이번달: 교통비 3,000원
  /// - 지난달: 교통비 5,000원
  Future<void> insertMockData(WidgetRef ref) async {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 10);
    final lastMonth = DateTime(now.year, now.month - 1, 10);

    final entries = <ExpenseEntry>[
      ExpenseEntry.create(
        spentAt: thisMonth,
        categoryCode: 'T',
        subcategoryCode: '_',
        paymentMethodCode: '_c',
        description: '교통비',
        amount: 3000,
        note: mockTag,
      ),
      ExpenseEntry.create(
        spentAt: lastMonth,
        categoryCode: 'T',
        subcategoryCode: '_',
        paymentMethodCode: '_c',
        description: '교통비',
        amount: 5000,
        note: mockTag,
      ),
    ];

    _insertedIds.clear();
    for (final entry in entries) {
      _insertedIds.add(entry.id);
      await ref.read(ledgerProvider.notifier).addExpense(entry);
    }

    ref.invalidate(monthlyExpensesProvider);
    ref.invalidate(rangeExpensesProvider);
  }

  /// 삽입했던 더미 지출 내역을 모두 삭제한다.
  Future<void> cleanupMockData(WidgetRef ref) async {
    for (final id in _insertedIds) {
      await ref.read(ledgerProvider.notifier).deleteExpense(id);
    }
    _insertedIds.clear();

    ref.invalidate(monthlyExpensesProvider);
    ref.invalidate(rangeExpensesProvider);
  }
}

/// 앱 수명 동안 단일 인스턴스를 공유한다.
final mockDataServiceProvider = Provider<MockDataService>((ref) {
  return MockDataService();
});
