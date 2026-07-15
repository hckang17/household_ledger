import 'dart:ui' show PlatformDispatcher;

import 'package:household_ledger/model/app_settings.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/push_notification_settings.dart';
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
    this.prevPeriodExpenses = const <ExpenseEntry>[],
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

  /// 전월동기 지출내역을 보관한다 (런타임 전용, 영속화 불필요).
  final List<ExpenseEntry> prevPeriodExpenses;

  /// 기본 상태를 생성한다.
  ///
  /// 기기 언어가 일본어(ja)이면 일본어 레이블을, 그 외에는 한국어 레이블을 사용한다.
  /// 사용자가 직접 추가하는 태그는 현지화 대상이 아니며, 초기 디폴트 태그에만 적용된다.
  factory LedgerState.initial() {
    String deviceLang = 'ko';
    try {
      deviceLang = PlatformDispatcher.instance.locale.languageCode;
    } catch (_) {}
    final bool isJa = deviceLang == 'ja';

    return LedgerState(
      settings: AppSettings.initial(),
      userProfile: UserProfile.empty(),
      metadataTags: <MetadataTag>[
        // 소비구분 (category) — 코드 알파벳순
        MetadataTag(
          type: MetadataTagType.category,
          code: 'C',
          label: isJa ? 'カフェ' : '카페',
        ),
        MetadataTag(
          type: MetadataTagType.category,
          code: 'D',
          label: isJa ? '日用品＆衣料' : '일용품&의류',
        ),
        MetadataTag(
          type: MetadataTagType.category,
          code: 'F',
          label: isJa ? '外食費' : '외식비',
        ),
        MetadataTag(
          type: MetadataTagType.category,
          code: 'G',
          label: isJa ? '食料品' : '식료품',
        ),
        MetadataTag(
          type: MetadataTagType.category,
          code: 'H',
          label: isJa ? 'ヒーリング＆趣味' : '힐링&취미',
        ),
        MetadataTag(
          type: MetadataTagType.category,
          code: 'L',
          label: isJa ? '生活費' : '생활비',
        ),
        MetadataTag(
          type: MetadataTagType.category,
          code: 'S',
          label: isJa ? 'スポーツ' : '스포츠',
        ),
        MetadataTag(
          type: MetadataTagType.category,
          code: 'T',
          label: isJa ? '交通費' : '교통비',
        ),
        // 소비 소구분 (subcategory)
        MetadataTag(
          type: MetadataTagType.subcategory,
          code: '_',
          label: isJa ? '普段' : '평상시',
        ),
        MetadataTag(
          type: MetadataTagType.subcategory,
          code: 't',
          label: isJa ? '旅行' : '여행',
        ),
        // 외식 식사 유형 (diningOccasion)
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
        // 소비수단 (paymentMethod)
        MetadataTag(
          type: MetadataTagType.paymentMethod,
          code: '_c',
          label: isJa ? '現金' : '현금',
        ),
        MetadataTag(
          type: MetadataTagType.paymentMethod,
          code: '_s',
          label: isJa ? 'クレジットカード' : '신용카드',
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
    List<ExpenseEntry>? prevPeriodExpenses,
  }) {
    return LedgerState(
      settings: settings ?? this.settings,
      userProfile: userProfile ?? this.userProfile,
      metadataTags: metadataTags ?? this.metadataTags,
      expenses: expenses ?? this.expenses,
      fixedExpenses: fixedExpenses ?? this.fixedExpenses,
      prevPeriodExpenses: prevPeriodExpenses ?? this.prevPeriodExpenses,
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

  /// 알림 설정을 변경한 새 상태를 생성한다.
  LedgerState changePushNotifications(PushNotificationSettings value) {
    return copyWith(settings: settings.copyWith(pushNotifications: value));
  }

  /// 시스템 기본 태그를 복원하고 현재 언어팩의 레이블을 적용한다.
  LedgerState localizeSystemMetadataTags(Map<String, String> strings) {
    final defaults = localizedSystemMetadataTags(strings);
    final defaultByIdentity = <String, MetadataTag>{
      for (final tag in defaults) '${tag.type.code}:${tag.code}': tag,
    };
    final seen = <String>{};
    final nextTags = <MetadataTag>[];
    for (final tag in metadataTags) {
      final identity = '${tag.type.code}:${tag.code}';
      final defaultTag = defaultByIdentity[identity];
      if (defaultTag == null) {
        nextTags.add(tag);
      } else if (seen.add(identity)) {
        nextTags.add(defaultTag);
      }
    }

    for (final entry in defaultByIdentity.entries) {
      if (!seen.contains(entry.key)) nextTags.add(entry.value);
    }
    return copyWith(metadataTags: nextTags);
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
    final labelValidation = MetadataTagLabelValidator.validate(
      type: tag.type,
      label: tag.label,
      tags: metadataTags,
      currentCode: tag.code,
    );
    if (labelValidation != MetadataTagLabelValidation.valid) {
      return this;
    }
    if (tag.isSystemDefault &&
        metadataTags.any(
          (MetadataTag current) =>
              current.type == tag.type && current.code == tag.code,
        )) {
      return this;
    }
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
    if (systemMetadataTagLocalizationKeys[type]?.containsKey(targetCode) ??
        false) {
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
        case MetadataTagType.diningOccasion:
          return entry.diningOccasionCode == targetCode
              ? entry.copyWith(diningOccasionCode: replacementCode)
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
        case MetadataTagType.diningOccasion:
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
    final settings = AppSettings.fromJson(
      json['settings'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final metadataTags =
        ((json['metadataTags'] as List<dynamic>?) ?? <dynamic>[])
            .map(
              (dynamic item) =>
                  MetadataTag.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    if (!metadataTags.any(
      (MetadataTag tag) => tag.type == MetadataTagType.diningOccasion,
    )) {
      final isJa = settings.localeCode == 'jp' || settings.localeCode == 'ja';
      metadataTags.addAll(<MetadataTag>[
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
    return LedgerState(
      settings: settings,
      userProfile: UserProfile.fromJson(
        json['userProfile'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      metadataTags: metadataTags,
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
