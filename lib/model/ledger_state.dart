import 'package:household_ledger/model/app_settings.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/user_profile.dart';

/// 앱 전체 가계부 상태를 표현한다.
class LedgerState {
  /// 전체 가계부 상태를 생성한다.
  const LedgerState({
    required this.settings,
    required this.userProfile,
    required this.metadataTags,
    required this.expenses,
    required this.fixedExpenses,
  });

  /// 앱 전역 설정을 보관한다.
  final AppSettings settings;

  /// 사용자 프로필을 보관한다.
  final UserProfile userProfile;

  /// 사용자 정의 태그 목록을 보관한다.
  final List<MetadataTag> metadataTags;

  /// 소비 기록 목록을 보관한다.
  final List<ExpenseEntry> expenses;

  /// 고정지출 목록을 보관한다.
  final List<FixedExpense> fixedExpenses;

  /// 기본 상태를 생성한다.
  factory LedgerState.initial() {
    return LedgerState(
      settings: AppSettings.initial(),
      userProfile: UserProfile.empty(),
      metadataTags: const <MetadataTag>[
        MetadataTag(type: MetadataTagType.category, code: 'F', label: '외식비'),
        MetadataTag(type: MetadataTagType.category, code: 'T', label: '교통비'),
        MetadataTag(type: MetadataTagType.category, code: 'L', label: '생활비'),
        MetadataTag(type: MetadataTagType.subcategory, code: '_', label: '없음'),
        MetadataTag(type: MetadataTagType.subcategory, code: 'f', label: '여행중'),
        MetadataTag(
          type: MetadataTagType.paymentMethod,
          code: '_s',
          label: '신용카드',
        ),
        MetadataTag(
          type: MetadataTagType.paymentMethod,
          code: '_c',
          label: '현금',
        ),
      ],
      expenses: const <ExpenseEntry>[],
      fixedExpenses: const <FixedExpense>[],
    );
  }

  /// 설정 완료 여부를 반환한다.
  bool get isInitialized =>
      settings.onboardingCompleted && userProfile.isConfigured;

  /// 선택한 월의 총 지출액을 계산한다.
  int monthlyExpenseTotal(DateTime month) {
    return expenses
        .where(
          (ExpenseEntry entry) =>
              entry.spentAt.year == month.year &&
              entry.spentAt.month == month.month,
        )
        .fold<int>(0, (int total, ExpenseEntry entry) => total + entry.amount);
  }

  /// 선택한 월의 고정지출 합계를 계산한다.
  int fixedExpenseTotalForMonth(DateTime month) {
    return fixedExpenses
        .where(
          (FixedExpense item) =>
              item.appliedAt.year == month.year &&
              item.appliedAt.month == month.month,
        )
        .fold<int>(0, (int total, FixedExpense item) => total + item.amount);
  }

  /// 전체 고정지출 합계를 계산한다.
  int get fixedExpenseTotal {
    return fixedExpenses.fold<int>(
      0,
      (int total, FixedExpense item) => total + item.amount,
    );
  }

  /// 선택한 월의 남은 예산을 계산한다.
  int remainingBudget(DateTime month) {
    return settings.monthlyBudget -
        monthlyExpenseTotal(month) -
        fixedExpenseTotalForMonth(month);
  }

  /// 현재 상태의 수정본을 생성한다.
  LedgerState copyWith({
    AppSettings? settings,
    UserProfile? userProfile,
    List<MetadataTag>? metadataTags,
    List<ExpenseEntry>? expenses,
    List<FixedExpense>? fixedExpenses,
  }) {
    return LedgerState(
      settings: settings ?? this.settings,
      userProfile: userProfile ?? this.userProfile,
      metadataTags: metadataTags ?? this.metadataTags,
      expenses: expenses ?? this.expenses,
      fixedExpenses: fixedExpenses ?? this.fixedExpenses,
    );
  }

  /// 초기 설정을 반영한 새 상태를 생성한다.
  LedgerState completeSetup({
    required UserProfile profile,
    required int monthlyBudget,
    required String localeCode,
    String? currencyUnit,
  }) {
    return copyWith(
      userProfile: profile,
      settings: settings.copyWith(
        onboardingCompleted: true,
        monthlyBudget: monthlyBudget,
        localeCode: localeCode,
        currencyUnit: currencyUnit,
      ),
    );
  }

  /// 앱 언어를 변경한 새 상태를 생성한다.
  LedgerState changeLocale(String localeCode) {
    return copyWith(settings: settings.copyWith(localeCode: localeCode));
  }

  /// 통화 단위를 변경한 새 상태를 생성한다.
  LedgerState changeCurrencyUnit(String currencyUnit) {
    return copyWith(settings: settings.copyWith(currencyUnit: currencyUnit));
  }

  /// 월 예산을 변경한 새 상태를 생성한다.
  LedgerState changeMonthlyBudget(int budget) {
    return copyWith(settings: settings.copyWith(monthlyBudget: budget));
  }

  /// 사용자 프로필을 변경한 새 상태를 생성한다.
  LedgerState updateUserProfile({required String name, required int age}) {
    return copyWith(
      userProfile: userProfile.copyWith(name: name.trim(), age: age),
    );
  }

  /// 지출 기록을 추가한 새 상태를 생성한다.
  LedgerState addExpense(ExpenseEntry entry) {
    final nextExpenses = <ExpenseEntry>[...expenses, entry]
      ..sort(
        (ExpenseEntry left, ExpenseEntry right) =>
            right.spentAt.compareTo(left.spentAt),
      );
    return copyWith(expenses: nextExpenses);
  }

  /// 지출 기록을 수정한 새 상태를 생성한다.
  LedgerState updateExpense(ExpenseEntry entry) {
    final nextExpenses =
        expenses
            .map(
              (ExpenseEntry current) =>
                  current.id == entry.id ? entry : current,
            )
            .toList()
          ..sort(
            (ExpenseEntry left, ExpenseEntry right) =>
                right.spentAt.compareTo(left.spentAt),
          );
    return copyWith(expenses: nextExpenses);
  }

  /// 지출 기록을 삭제한 새 상태를 생성한다.
  LedgerState deleteExpense(String id) {
    return copyWith(
      expenses: expenses.where((ExpenseEntry entry) => entry.id != id).toList(),
    );
  }

  /// 고정지출을 추가한 새 상태를 생성한다.
  LedgerState addFixedExpense(FixedExpense item) {
    final nextItems = <FixedExpense>[...fixedExpenses, item]
      ..sort((FixedExpense left, FixedExpense right) {
        final byDate = right.appliedAt.compareTo(left.appliedAt);
        if (byDate != 0) {
          return byDate;
        }
        return right.id.compareTo(left.id);
      });
    return copyWith(fixedExpenses: nextItems);
  }

  /// 고정지출을 수정한 새 상태를 생성한다.
  LedgerState updateFixedExpense(FixedExpense item) {
    final nextItems =
        fixedExpenses
            .map(
              (FixedExpense current) => current.id == item.id ? item : current,
            )
            .toList()
          ..sort((FixedExpense left, FixedExpense right) {
            final byDate = right.appliedAt.compareTo(left.appliedAt);
            if (byDate != 0) {
              return byDate;
            }
            return right.id.compareTo(left.id);
          });
    return copyWith(fixedExpenses: nextItems);
  }

  /// 고정지출을 삭제한 새 상태를 생성한다.
  LedgerState deleteFixedExpense(String id) {
    return copyWith(
      fixedExpenses: fixedExpenses
          .where((FixedExpense item) => item.id != id)
          .toList(),
    );
  }

  /// 새 메타데이터 태그를 추가한 새 상태를 생성한다.
  LedgerState addMetadataTag(MetadataTag tag) {
    final filtered = metadataTags.where(
      (MetadataTag current) =>
          !(current.type == tag.type && current.code == tag.code),
    );
    return copyWith(metadataTags: <MetadataTag>[...filtered, tag]);
  }

  /// 메타데이터 태그를 삭제하고 관련 데이터를 교체한 새 상태를 생성한다.
  LedgerState replaceAndDeleteTag({
    required MetadataTagType type,
    required String targetCode,
    required String replacementCode,
  }) {
    if (targetCode == replacementCode) {
      return this;
    }

    MetadataTag? replacementTag;
    for (final tag in metadataTags) {
      if (tag.type == type && tag.code == replacementCode) {
        replacementTag = tag;
        break;
      }
    }

    if (replacementTag == null) {
      return this;
    }

    final nextTags = metadataTags
        .where(
          (MetadataTag tag) => !(tag.type == type && tag.code == targetCode),
        )
        .map((MetadataTag tag) {
          if (tag.type == type && tag.code == replacementCode) {
            return replacementTag!;
          }

          return tag;
        })
        .toList();

    final nextExpenses = expenses.map((ExpenseEntry entry) {
      switch (type) {
        case MetadataTagType.category:
          return entry.categoryCode == targetCode
              ? entry.copyWith(categoryCode: replacementCode)
              : entry;
        case MetadataTagType.subcategory:
          return entry.subcategoryCode == targetCode
              ? entry.copyWith(subcategoryCode: replacementCode)
              : entry;
        case MetadataTagType.paymentMethod:
          return entry.paymentMethodCode == targetCode
              ? entry.copyWith(paymentMethodCode: replacementCode)
              : entry;
      }
    }).toList();

    final nextFixedExpenses = fixedExpenses.map((FixedExpense item) {
      switch (type) {
        case MetadataTagType.category:
          return item.categoryCode == targetCode
              ? item.copyWith(categoryCode: replacementCode)
              : item;
        case MetadataTagType.subcategory:
          return item;
        case MetadataTagType.paymentMethod:
          return item.paymentMethodCode == targetCode
              ? item.copyWith(paymentMethodCode: replacementCode)
              : item;
      }
    }).toList();

    return copyWith(
      metadataTags: nextTags,
      expenses: nextExpenses,
      fixedExpenses: nextFixedExpenses,
    );
  }

  /// 특정 종류에 해당하는 태그 목록을 반환한다.
  List<MetadataTag> tagsByType(MetadataTagType type) {
    final tags = metadataTags
        .where((MetadataTag tag) => tag.type == type)
        .toList();
    tags.sort(
      (MetadataTag left, MetadataTag right) => left.code.compareTo(right.code),
    );
    return tags;
  }

  /// 특정 날짜의 소비 기록 목록을 반환한다.
  List<ExpenseEntry> expensesByDate(DateTime date) {
    return expenses.where((ExpenseEntry entry) {
      return entry.spentAt.year == date.year &&
          entry.spentAt.month == date.month &&
          entry.spentAt.day == date.day;
    }).toList();
  }

  /// 상태를 JSON 구조로 변환한다.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'settings': settings.toJson(),
      'userProfile': userProfile.toJson(),
      'metadataTags': metadataTags
          .map((MetadataTag tag) => tag.toJson())
          .toList(),
      'expenses': expenses.map((ExpenseEntry entry) => entry.toJson()).toList(),
      'fixedExpenses': fixedExpenses
          .map((FixedExpense item) => item.toJson())
          .toList(),
    };
  }

  /// JSON 구조에서 상태를 복원한다.
  factory LedgerState.fromJson(Map<String, dynamic> json) {
    return LedgerState(
      settings: AppSettings.fromJson(
        json['settings'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      userProfile: UserProfile.fromJson(
        json['userProfile'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      metadataTags: ((json['metadataTags'] as List<dynamic>?) ?? <dynamic>[])
          .map(
            (dynamic item) =>
                MetadataTag.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      expenses: ((json['expenses'] as List<dynamic>?) ?? <dynamic>[])
          .map(
            (dynamic item) =>
                ExpenseEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      fixedExpenses: ((json['fixedExpenses'] as List<dynamic>?) ?? <dynamic>[])
          .map(
            (dynamic item) =>
                FixedExpense.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
