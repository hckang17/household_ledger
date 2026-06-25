/// 검색 대상 테이블 유형
enum DataTableType { expense, fixedExpense, income }

/// 검색 기간 유형
enum DateRangeType { all, month, period }

/// 데이터 검색 조건 (분석/소비기록 페이지에서도 재사용 가능)
class DataSearchFilter {
  const DataSearchFilter({
    this.tableType,
    this.dateRangeType = DateRangeType.all,
    this.selectedMonth,
    this.startDate,
    this.endDate,
    this.paymentMethodCode,
    this.categoryCode,
    this.descriptionQuery = '',
    this.noteQuery = '',
  });

  final DataTableType? tableType;
  final DateRangeType dateRangeType;
  final DateTime? selectedMonth;
  final DateTime? startDate;
  final DateTime? endDate;

  /// null = 전체
  final String? paymentMethodCode;

  /// null = 전체
  final String? categoryCode;

  final String descriptionQuery;
  final String noteQuery;

  DataSearchFilter copyWith({
    DataTableType? tableType,
    bool clearTableType = false,
    DateRangeType? dateRangeType,
    DateTime? selectedMonth,
    bool clearSelectedMonth = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? paymentMethodCode,
    bool clearPaymentMethod = false,
    String? categoryCode,
    bool clearCategory = false,
    String? descriptionQuery,
    String? noteQuery,
  }) {
    return DataSearchFilter(
      tableType: clearTableType ? null : (tableType ?? this.tableType),
      dateRangeType: dateRangeType ?? this.dateRangeType,
      selectedMonth: clearSelectedMonth
          ? null
          : (selectedMonth ?? this.selectedMonth),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      paymentMethodCode: clearPaymentMethod
          ? null
          : (paymentMethodCode ?? this.paymentMethodCode),
      categoryCode: clearCategory ? null : (categoryCode ?? this.categoryCode),
      descriptionQuery: descriptionQuery ?? this.descriptionQuery,
      noteQuery: noteQuery ?? this.noteQuery,
    );
  }
}
