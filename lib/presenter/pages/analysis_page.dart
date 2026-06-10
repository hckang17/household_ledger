import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:intl/intl.dart';

/// 지출 분석 화면이다.
class AnalysisPage extends ConsumerStatefulWidget {
  /// 지출 분석 화면을 생성한다.
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  bool _isMonthlySummaryExpanded = true; // 월간 요약 카드의 확장 상태(디폴트)
  bool _isMonthlySubcategorySummaryExpanded = true; // 월별 소구분 요약 카드의 확장 상태(디폴트)
  bool _isMonthlyPaymentSummaryExpanded = true; // 월별 소비수단 요약 카드의 확장 상태(디폴트)
  late DateTime _selectedMonth;
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  String _text(Map<String, String> strings, String key, String fallback) {
    return strings[key] ?? fallback;
  }

  String _currencyUnit(Map<String, String> strings) {
    return strings['currencyUnit'] ?? '원';
  }

  String _intlLocaleCode(String localeCode) {
    switch (localeCode) {
      case 'jp':
        return 'ja';
      case 'ko':
        return 'ko';
      case 'en':
        return 'en'; // 영어는 미대응
      default:
        return 'ko'; // 디폴트는 한국어.
    }
  }

  String _formatCurrency(Map<String, String> strings, int amount) {
    return '${amount.toCurrency()} ${_currencyUnit(strings)}';
  }

  String _formatMonth(String localeCode, DateTime month) {
    return DateFormat.yMMMM(_intlLocaleCode(localeCode)).format(month);
  }

  String _formatRange(String localeCode, DateTimeRange range) {
    final formatter = DateFormat('yyyy.MM.dd', _intlLocaleCode(localeCode));
    return '${formatter.format(range.start)} - ${formatter.format(range.end)}';
  }

  bool _isSameYearMonth(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month;
  }

  /// 카테고리별 지출 합계를 계산한다.
  Map<String, int> _sumByCategory(Iterable<ExpenseEntry> expenses) {
    final result = <String, int>{};
    for (final entry in expenses) {
      result.update(
        entry.categoryCode,
        (int value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }

    return result;
  }

  /// 소비수단별 지출 합계를 계산한다.
  Map<String, int> _sumByPaymentMethod(Iterable<ExpenseEntry> expenses) {
    final result = <String, int>{};
    for (final entry in expenses) {
      result.update(
        entry.paymentMethodCode,
        (int value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }

    return result;
  }

  /// 소비 소구분별 지출 합계를 계산한다.
  Map<String, int> _sumBySubcategory(Iterable<ExpenseEntry> expenses) {
    final result = <String, int>{};
    for (final entry in expenses) {
      result.update(
        entry.subcategoryCode,
        (int value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }

    return result;
  }

  /// 그룹별 건수를 계산한다.
  Map<String, int> _countByGroup(
    Iterable<ExpenseEntry> expenses,
    String Function(ExpenseEntry entry) selector,
  ) {
    final result = <String, int>{};
    for (final entry in expenses) {
      final key = selector(entry);
      result.update(key, (int value) => value + 1, ifAbsent: () => 1);
    }

    return result;
  }

  int _sumAmount(Iterable<ExpenseEntry> expenses) {
    return expenses.fold<int>(
      0,
      (int total, ExpenseEntry entry) => total + entry.amount,
    );
  }

  /// 코드에 해당하는 태그 라벨을 반환한다.
  String _resolveTagLabel(List<MetadataTag> tags, String code) {
    for (final tag in tags) {
      if (tag.code == code) {
        return tag.label;
      }
    }

    return code;
  }

  MapEntry<String, int>? _topCategory(Map<String, int> summary) {
    if (summary.isEmpty) {
      return null;
    }

    final sortedEntries = summary.entries.toList()
      ..sort(
        (MapEntry<String, int> left, MapEntry<String, int> right) =>
            right.value.compareTo(left.value),
      );
    return sortedEntries.first;
  }

  /// 월 선택 모달을 보여주고, 선택된 월로 상태를 업데이트 하는 메서드
  Future<void> _pickMonth(
    BuildContext context,
    Map<String, String> strings,
  ) async {
    final now = DateTime.now();
    var selectedYear = _selectedMonth.year;
    var selectedMonth = _selectedMonth.month;
    final pickedMonth = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _text(strings, 'selectMonth', '달 선택'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedYear,
                            decoration: InputDecoration(
                              labelText: _text(strings, 'yearLabel', '연도'),
                            ),
                            items: List<DropdownMenuItem<int>>.generate(11, (
                              int index,
                            ) {
                              final year = now.year - 5 + index;
                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text('$year'),
                              );
                            }),
                            onChanged: (int? value) {
                              if (value == null) {
                                return;
                              }

                              setModalState(() {
                                selectedYear = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedMonth,
                            decoration: InputDecoration(
                              labelText: _text(strings, 'monthLabel', '월'),
                            ),
                            items: List<DropdownMenuItem<int>>.generate(12, (
                              int index,
                            ) {
                              final month = index + 1;
                              return DropdownMenuItem<int>(
                                value: month,
                                child: Text('$month'),
                              );
                            }),
                            onChanged: (int? value) {
                              if (value == null) {
                                return;
                              }

                              setModalState(() {
                                selectedMonth = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(_text(strings, 'cancel', '취소')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).pop(DateTime(selectedYear, selectedMonth));
                          },
                          child: Text(_text(strings, 'apply', '적용')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (pickedMonth == null) {
      return;
    }

    setState(() {
      _selectedMonth = DateTime(pickedMonth.year, pickedMonth.month);
    });
  }

  /// 날짜 범위 선택 모달을 보여주고, 선택된 범위로 상태를 업데이트 하는 메서드
  Future<void> _pickDateRange(
    BuildContext context,
    Map<String, String> strings,
    String localeCode,
  ) async {
    final now = DateTime.now();
    final pickedRange = await showDateRangePicker(
      context: context,
      locale: Locale(_intlLocaleCode(localeCode)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      currentDate: now,
      initialDateRange: _selectedRange,
      helpText: _text(strings, 'selectDateRange', '캘린더 기간 선택'),
      cancelText: _text(strings, 'cancel', '취소'),
      saveText: _text(strings, 'apply', '적용'),
    );
    if (pickedRange == null) {
      return;
    }

    setState(() {
      _selectedRange = DateTimeRange(
        start: DateTime(
          pickedRange.start.year,
          pickedRange.start.month,
          pickedRange.start.day,
        ),
        end: DateTime(
          pickedRange.end.year,
          pickedRange.end.month,
          pickedRange.end.day,
        ),
      );
    });
  }

  Widget _buildSummarySection({
    required BuildContext context,
    required Map<String, String> strings,
    required String title,
    required String subtitle,
    required bool expanded,
    required VoidCallback onToggle,
    required List<MetadataTag> tags,
    required Map<String, int> summary,
    required Map<String, int> countSummary,
    required int totalAmount,
    required String topLabel,
    required String emptyMessage,
  }) {
    final sortedEntries = summary.entries.toList()
      ..sort(
        (MapEntry<String, int> left, MapEntry<String, int> right) =>
            right.value.compareTo(left.value),
      );
    final topCategory = _topCategory(summary);

    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          /// 요약 카드의 헤더 영역이다.
          /// 섹션 제목, 부제목, 펼치기/접기 버튼으로 구성된다.
          Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: onToggle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggle,
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ),
            ],
          ),

          /// 확장된 경우에만 상세 내용을 보여준다. [월간요약]
          if (expanded) const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: !expanded
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      /// 현재 선택된 조건의 총 지출 금액을 강조해서 보여주는 영역이다.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F9FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _text(strings, 'totalSpent', '총 지출금액'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              _formatCurrency(strings, totalAmount),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      /// 카테고리별 합계를 세로 목록으로 보여준다.
                      if (sortedEntries.isEmpty)
                        Text(emptyMessage)
                      else
                        ...sortedEntries.map((MapEntry<String, int> item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(_resolveTagLabel(tags, item.key)),
                                ),
                                Text(
                                  '${_formatCurrency(strings, item.value)} (${countSummary[item.key] ?? 0}${_text(strings, 'entryCountUnit', '건')})',
                                ),
                              ],
                            ),
                          );
                        }),

                      /// 가장 많이 지출한 카테고리를 별도로 다시 요약해서 보여준다.
                      if (topCategory != null) ...<Widget>[
                        const Divider(height: 24),
                        Text(
                          _text(strings, 'detailedSummary', '상세 요약'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(child: Text(topLabel)),
                            Text(
                              '${_resolveTagLabel(tags, topCategory.key)} (${_formatCurrency(strings, topCategory.value)} / ${countSummary[topCategory.key] ?? 0}${_text(strings, 'entryCountUnit', '건')})',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final localeCode = ledger.settings.localeCode;
    final categoryTags = ledger.tagsByType(MetadataTagType.category);
    final subcategoryTags = ledger.tagsByType(MetadataTagType.subcategory);
    final paymentTags = ledger.tagsByType(MetadataTagType.paymentMethod);
    final monthlyExpensesAsync = ref.watch(
      monthlyExpensesProvider(_selectedMonth),
    );
    if (monthlyExpensesAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (monthlyExpensesAsync.hasError) {
      return Scaffold(
        body: Center(child: Text(monthlyExpensesAsync.error.toString())),
      );
    }
    final monthlyExpenses =
        monthlyExpensesAsync.asData?.value ?? const <ExpenseEntry>[];

    final rangeQuery = _selectedRange == null
        ? null
        : ExpenseRangeQuery(
            start: DateTime(
              _selectedRange!.start.year,
              _selectedRange!.start.month,
              _selectedRange!.start.day,
            ),
            endInclusive: DateTime(
              _selectedRange!.end.year,
              _selectedRange!.end.month,
              _selectedRange!.end.day,
            ),
          );
    final rangeExpensesAsync = rangeQuery == null
        ? const AsyncData<List<ExpenseEntry>>(<ExpenseEntry>[])
        : ref.watch(rangeExpensesProvider(rangeQuery));
    if (rangeExpensesAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (rangeExpensesAsync.hasError) {
      return Scaffold(
        body: Center(child: Text(rangeExpensesAsync.error.toString())),
      );
    }
    final rangeExpenses =
        rangeExpensesAsync.asData?.value ?? const <ExpenseEntry>[];

    final monthlySummary = _sumByCategory(monthlyExpenses);
    final monthlySubcategorySummary = _sumBySubcategory(monthlyExpenses);
    final monthlyPaymentSummary = _sumByPaymentMethod(monthlyExpenses);
    final monthlyCategoryCountSummary = _countByGroup(
      monthlyExpenses,
      (ExpenseEntry entry) => entry.categoryCode,
    );
    final monthlySubcategoryCountSummary = _countByGroup(
      monthlyExpenses,
      (ExpenseEntry entry) => entry.subcategoryCode,
    );
    final monthlyPaymentCountSummary = _countByGroup(
      monthlyExpenses,
      (ExpenseEntry entry) => entry.paymentMethodCode,
    );
    final rangeSummary = _sumByCategory(rangeExpenses);
    final rangeSubcategorySummary = _sumBySubcategory(rangeExpenses);
    final rangePaymentSummary = _sumByPaymentMethod(rangeExpenses);
    final rangeCategoryCountSummary = _countByGroup(
      rangeExpenses,
      (ExpenseEntry entry) => entry.categoryCode,
    );
    final rangeSubcategoryCountSummary = _countByGroup(
      rangeExpenses,
      (ExpenseEntry entry) => entry.subcategoryCode,
    );
    final rangePaymentCountSummary = _countByGroup(
      rangeExpenses,
      (ExpenseEntry entry) => entry.paymentMethodCode,
    );
    final nowMonth = DateTime.now();
    final isDefaultThisMonth =
        _selectedRange == null && _isSameYearMonth(_selectedMonth, nowMonth);
    final isPeriodView = !isDefaultThisMonth;
    final usingRange = _selectedRange != null;
    final activeCategorySummary = usingRange ? rangeSummary : monthlySummary;
    final activePaymentSummary = usingRange
        ? rangePaymentSummary
        : monthlyPaymentSummary;
    final activeSubcategorySummary = usingRange
        ? rangeSubcategorySummary
        : monthlySubcategorySummary;
    final activeCategoryCountSummary = usingRange
        ? rangeCategoryCountSummary
        : monthlyCategoryCountSummary;
    final activeSubcategoryCountSummary = usingRange
        ? rangeSubcategoryCountSummary
        : monthlySubcategoryCountSummary;
    final activePaymentCountSummary = usingRange
        ? rangePaymentCountSummary
        : monthlyPaymentCountSummary;
    final activeExpenses = usingRange ? rangeExpenses : monthlyExpenses;
    final activeSubtitle = usingRange
        ? _formatRange(localeCode, _selectedRange!)
        : _formatMonth(localeCode, _selectedMonth);
    final activeEmptyMessage = usingRange
        ? _text(strings, 'emptySelectedPeriodData', '선택된 기간내 소비 내역이 없습니다')
        : _text(strings, 'emptyData', '아직 입력된 데이터가 없습니다.');

    /// 공통 부트스트랩 페이지를 작성한다.
    return BootstrapPage(
      title: strings['analysis'] ?? '',
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            /// 상단 요약 카드 영역이다.
            /// 이번 달 총 지출과 고정 지출 합계를 나란히 보여준다.

            // BootstrapSectionCard(
            //   child: Row(
            //     children: <Widget>[
            //       Expanded(
            //         child: BootstrapSummaryTile(
            //           label: strings['totalSpent'] ?? '',
            //           value: _formatCurrency(
            //             strings,
            //             ledger.monthlyExpenseTotal(_selectedMonth),
            //           ),
            //           color: const Color(0xFFDC3545),
            //         ),
            //       ),
            //       const SizedBox(width: 12),
            //       Expanded(
            //         child: BootstrapSummaryTile(
            //           label: strings['fixedExpenseTotal'] ?? '',
            //           value: _formatCurrency(strings, ledger.fixedExpenseTotal),
            //           color: const Color(0xFF0D6EFD),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            // const SizedBox(height: 16),

            /// 분석 기준을 바꾸는 필터 영역이다.

            /// 월 선택, 기간 선택, 선택 초기화 버튼을 배치한다.
            BootstrapSectionCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    _text(strings, 'analysisPeriodSelectionTitle', '달 선택'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => _pickMonth(context, strings),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          '${_text(strings, 'selectMonth', '달 선택')} : ${_formatMonth(localeCode, _selectedMonth)}',
                        ),
                      ),

                      /// 날짜 범위 선택 버튼과 선택 초기화 버튼을 배치한다.
                      OutlinedButton.icon(
                        // 버튼 스타일 통일 (넓이 max) 및 패딩 조정
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onPressed:
                            () => // 날짜 범위 선택 모달을 보여주고, 선택된 범위로 상태를 업데이트 하는 메서드
                                _pickDateRange(context, strings, localeCode),
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          _selectedRange == null
                              ? _text(strings, 'selectDateRange', '캘린더 기간 선택')
                              : _formatRange(localeCode, _selectedRange!),
                        ),
                      ),
                      if (_selectedRange != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedRange = null;
                            });
                          },
                          child: Text(
                            _text(strings, 'clearSelection', '선택 초기화'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            /// 선택한 월의 지출을 카테고리별로 요약하는 섹션이다.
            _buildSummarySection(
              context: context,
              strings: strings,
              title: isPeriodView
                  ? _text(strings, 'rangeSummary', '기간 선택 요약')
                  : _text(strings, 'monthlySummary', '월별 요약'),
              subtitle: activeSubtitle,
              expanded: _isMonthlySummaryExpanded,
              onToggle: () {
                setState(() {
                  _isMonthlySummaryExpanded = !_isMonthlySummaryExpanded;
                });
              },
              tags: categoryTags,
              summary: activeCategorySummary,
              countSummary: activeCategoryCountSummary,
              totalAmount: _sumAmount(activeExpenses),
              topLabel: _text(strings, 'mostUsedCategory', '제일 많이 쓰는 카테고리'),
              emptyMessage: activeEmptyMessage,
            ),
            const SizedBox(height: 16),

            /// 기본은 월별, 월 변경/기간 선택 시 기간 기준으로 소비 소구분을 요약한다.
            _buildSummarySection(
              context: context,
              strings: strings,
              title: isPeriodView
                  ? _text(strings, 'rangeSubcategorySummary', '기간별 소비 소구분 요약')
                  : _text(strings, 'monthlySubcategorySummary', '월별 소비 소구분 요약'),
              subtitle: activeSubtitle,
              expanded: _isMonthlySubcategorySummaryExpanded,
              onToggle: () {
                setState(() {
                  _isMonthlySubcategorySummaryExpanded =
                      !_isMonthlySubcategorySummaryExpanded;
                });
              },
              tags: subcategoryTags,
              summary: activeSubcategorySummary,
              countSummary: activeSubcategoryCountSummary,
              totalAmount: _sumAmount(activeExpenses),
              topLabel: _text(
                strings,
                'mostUsedSubcategory',
                '제일 많이 쓰는 소비 소구분',
              ),
              emptyMessage: activeEmptyMessage,
            ),
            const SizedBox(height: 16),

            /// 기본은 월별, 월 변경/기간 선택 시 기간 기준으로 소비수단을 요약한다.
            _buildSummarySection(
              context: context,
              strings: strings,
              title: isPeriodView
                  ? _text(strings, 'rangePaymentSummary', '기간별 소비수단 요약')
                  : _text(strings, 'monthlyPaymentSummary', '월별 소비수단 요약'),
              subtitle: activeSubtitle,
              expanded: _isMonthlyPaymentSummaryExpanded,
              onToggle: () {
                setState(() {
                  _isMonthlyPaymentSummaryExpanded =
                      !_isMonthlyPaymentSummaryExpanded;
                });
              },
              tags: paymentTags,
              summary: activePaymentSummary,
              countSummary: activePaymentCountSummary,
              totalAmount: _sumAmount(activeExpenses),
              topLabel: _text(
                strings,
                'mostUsedPaymentMethod',
                '제일 많이 사용한 소비수단',
              ),
              emptyMessage: activeEmptyMessage,
            ),
          ],
        ),
      ),
    );
  }
}
