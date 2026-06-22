import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/data_search_filter.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/provider/data_manage_provider.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:intl/intl.dart';

/// 데이터 관리 페이지 — 검색 조건으로 데이터를 조회하고 일괄 삭제/태그 변경을 제공한다.
class DataManagingPage extends ConsumerStatefulWidget {
  const DataManagingPage({super.key});

  @override
  ConsumerState<DataManagingPage> createState() => _DataManagingPageState();
}

class _DataManagingPageState extends ConsumerState<DataManagingPage> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _s(Map<String, String> strings, String key, String fallback) {
    return strings[key] ?? fallback;
  }

  String _tagLabel(List<MetadataTag> tags, String code) {
    try {
      return tags.firstWhere((MetadataTag t) => t.code == code).label;
    } catch (_) {
      return code;
    }
  }

  String _formatDate(DateTime d) => DateFormat('MM.dd').format(d);
  String _formatMonth(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}';

  Future<void> _pickMonth(DataSearchFilter filter) async {
    final DateTime initial = filter.selectedMonth ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) { return; }
    ref.read(dataManageProvider.notifier).setFilter(
      filter.copyWith(selectedMonth: DateTime(picked.year, picked.month)),
    );
  }

  Future<void> _pickStartDate(DataSearchFilter filter) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: filter.startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) { return; }
    ref.read(dataManageProvider.notifier).setFilter(
      filter.copyWith(
        startDate: DateTime(picked.year, picked.month, picked.day),
      ),
    );
  }

  Future<void> _pickEndDate(DataSearchFilter filter) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: filter.endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) { return; }
    ref.read(dataManageProvider.notifier).setFilter(
      filter.copyWith(
        endDate: DateTime(picked.year, picked.month, picked.day),
      ),
    );
  }

  Future<void> _confirmDelete(
    Map<String, String> strings,
    int count,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFDC3545),
          size: 36,
        ),
        title: Text(_s(strings, 'dataManageDeleteConfirmTitle', '선택 항목 삭제')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _s(strings, 'dataManageDeleteConfirmMessage', '{count}건을 삭제합니다.')
                  .replaceAll('{count}', count.toString()),
            ),
            const SizedBox(height: 8),
            Text(
              _s(
                strings,
                'dataManageDeleteWarning',
                '삭제한 데이터는 복구할 수 없습니다.',
              ),
              style: const TextStyle(
                color: Color(0xFFDC3545),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_s(strings, 'cancel', '취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC3545),
            ),
            child: Text(_s(strings, 'delete', '삭제')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) { return; }
    await ref.read(dataManageProvider.notifier).deleteSelected();
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _s(strings, 'dataManageDeleteSuccess', '{count}건이 삭제되었습니다.')
              .replaceAll('{count}', count.toString()),
        ),
        backgroundColor: const Color(0xFF198754),
      ),
    );
  }

  Future<void> _showTagChangeSheet(
    Map<String, String> strings,
    List<MetadataTag> categoryTags,
    List<MetadataTag> paymentTags,
    DataManageState manageState,
  ) async {
    if (manageState.searchedTableType == DataTableType.income) { return; }

    String? selectedPayment;
    String? selectedCategory;

    final int selCount = manageState.selectedIds.length;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetCtx) => StatefulBuilder(
        builder: (BuildContext _, StateSetter setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _s(strings, 'dataManageChangeTagTitle', '태그 일괄 변경'),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$selCount${_s(strings, 'dataManageSelectedCount', '건 선택됨')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: selectedPayment,
                  decoration: InputDecoration(
                    labelText: _s(strings, 'paymentMethodLabel', '소비수단'),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(_s(strings, 'dataManageNoChange', '변경 안함')),
                    ),
                    ...paymentTags.map(
                      (MetadataTag t) => DropdownMenuItem<String>(
                        value: t.code,
                        child: Text('${t.code} · ${t.label}'),
                      ),
                    ),
                  ],
                  onChanged: (String? v) => setModal(() => selectedPayment = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: _s(strings, 'categoryLabel', '소비구분'),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(_s(strings, 'dataManageNoChange', '변경 안함')),
                    ),
                    ...categoryTags.map(
                      (MetadataTag t) => DropdownMenuItem<String>(
                        value: t.code,
                        child: Text('${t.code} · ${t.label}'),
                      ),
                    ),
                  ],
                  onChanged: (String? v) => setModal(() => selectedCategory = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        (selectedPayment == null && selectedCategory == null)
                            ? null
                            : () async {
                                // 변경 확인 다이얼로그
                                final bool? confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext dialogCtx) =>
                                      AlertDialog(
                                    title: Text(
                                      _s(
                                        strings,
                                        'dataManageChangeConfirmTitle',
                                        '태그 변경 확인',
                                      ),
                                    ),
                                    content: Text(
                                      _s(
                                        strings,
                                        'dataManageChangeConfirmMessage',
                                        '{count}건의 태그를 변경하시겠습니까?',
                                      ).replaceAll('{count}', selCount.toString()),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, false),
                                        child: Text(_s(strings, 'cancel', '취소')),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, true),
                                        child: Text(
                                          _s(
                                            strings,
                                            'dataManageChangeTagApply',
                                            '변경 적용',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) { return; }
                                // 시트를 닫고 일괄 변경 실행
                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                }
                                await ref
                                    .read(dataManageProvider.notifier)
                                    .bulkChangeTags(
                                      paymentMethodCode: selectedPayment,
                                      categoryCode: selectedCategory,
                                    );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _s(
                                          strings,
                                          'dataManageChangeSuccess',
                                          '{count}건의 태그가 변경되었습니다.',
                                        ).replaceAll(
                                          '{count}',
                                          selCount.toString(),
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF198754),
                                    ),
                                  );
                                }
                              },
                    child: Text(
                      _s(strings, 'dataManageChangeTagApply', '변경 적용'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Filter section ─────────────────────────────────────────────────────────

  Widget _buildTableSelector(
    Map<String, String> strings,
    DataSearchFilter filter,
  ) {
    return SegmentedButton<DataTableType?>(
      segments: <ButtonSegment<DataTableType?>>[
        ButtonSegment<DataTableType?>(
          value: DataTableType.expense,
          label: Text(_s(strings, 'dataManageTableExpense', '소비기록')),
        ),
        ButtonSegment<DataTableType?>(
          value: DataTableType.fixedExpense,
          label: Text(_s(strings, 'dataManageTableFixed', '고정지출')),
        ),
        ButtonSegment<DataTableType?>(
          value: DataTableType.income,
          label: Text(_s(strings, 'dataManageTableIncome', '수입')),
        ),
      ],
      selected: <DataTableType?>{filter.tableType},
      emptySelectionAllowed: true,
      onSelectionChanged: (Set<DataTableType?> selected) {
        final DataTableType? picked =
            selected.isEmpty ? null : selected.first;
        ref.read(dataManageProvider.notifier).setFilter(
          filter.copyWith(
            tableType: picked,
            clearTableType: picked == null,
            clearPaymentMethod: true,
            clearCategory: true,
          ),
        );
      },
    );
  }

  Widget _buildDateRangeSelector(
    Map<String, String> strings,
    DataSearchFilter filter,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SegmentedButton<DateRangeType>(
          segments: <ButtonSegment<DateRangeType>>[
            ButtonSegment<DateRangeType>(
              value: DateRangeType.all,
              label: Text(_s(strings, 'dataManageAllPeriod', '전체')),
            ),
            ButtonSegment<DateRangeType>(
              value: DateRangeType.month,
              label: Text(_s(strings, 'dataManageMonthPeriod', '특정 달')),
            ),
            ButtonSegment<DateRangeType>(
              value: DateRangeType.period,
              label: Text(_s(strings, 'dataManageRangePeriod', '기간 지정')),
            ),
          ],
          selected: <DateRangeType>{filter.dateRangeType},
          onSelectionChanged: (Set<DateRangeType> selection) {
            ref.read(dataManageProvider.notifier).setFilter(
              filter.copyWith(dateRangeType: selection.first),
            );
          },
        ),
        if (filter.dateRangeType == DateRangeType.month)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => _pickMonth(filter),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: Text(
                filter.selectedMonth != null
                    ? _formatMonth(filter.selectedMonth!)
                    : _s(strings, 'dataManageSelectMonth', '달 선택'),
              ),
            ),
          ),
        if (filter.dateRangeType == DateRangeType.period)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickStartDate(filter),
                    child: Text(
                      filter.startDate != null
                          ? DateFormat('yyyy.MM.dd').format(filter.startDate!)
                          : _s(strings, 'dataManageStartDate', '시작일'),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('~'),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickEndDate(filter),
                    child: Text(
                      filter.endDate != null
                          ? DateFormat('yyyy.MM.dd').format(filter.endDate!)
                          : _s(strings, 'dataManageEndDate', '종료일'),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterCard(
    Map<String, String> strings,
    DataSearchFilter filter,
    List<MetadataTag> categoryTags,
    List<MetadataTag> paymentTags,
    bool isIncome,
  ) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _s(strings, 'dataManageFilterTitle', '검색 조건'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildTableSelector(strings, filter),
          const SizedBox(height: 12),
          _buildDateRangeSelector(strings, filter),
          if (!isIncome) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>('pm_${filter.paymentMethodCode}'),
              initialValue: filter.paymentMethodCode,
              decoration: InputDecoration(
                labelText: _s(strings, 'paymentMethodLabel', '소비수단'),
                isDense: true,
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(_s(strings, 'dataManageAll', '전체')),
                ),
                ...paymentTags.map(
                  (MetadataTag t) => DropdownMenuItem<String>(
                    value: t.code,
                    child: Text('${t.code} · ${t.label}'),
                  ),
                ),
              ],
              onChanged: (String? v) {
                ref.read(dataManageProvider.notifier).setFilter(
                  v == null
                      ? filter.copyWith(clearPaymentMethod: true)
                      : filter.copyWith(paymentMethodCode: v),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey<String?>('cat_${filter.categoryCode}'),
              initialValue: filter.categoryCode,
              decoration: InputDecoration(
                labelText: _s(strings, 'categoryLabel', '소비구분'),
                isDense: true,
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(_s(strings, 'dataManageAll', '전체')),
                ),
                ...categoryTags.map(
                  (MetadataTag t) => DropdownMenuItem<String>(
                    value: t.code,
                    child: Text('${t.code} · ${t.label}'),
                  ),
                ),
              ],
              onChanged: (String? v) {
                ref.read(dataManageProvider.notifier).setFilter(
                  v == null
                      ? filter.copyWith(clearCategory: true)
                      : filter.copyWith(categoryCode: v),
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: _s(strings, 'descriptionLabel', '내용'),
              isDense: true,
            ),
            onChanged: (String v) {
              ref.read(dataManageProvider.notifier).setFilter(
                filter.copyWith(descriptionQuery: v),
              );
            },
          ),
          if (!isIncome) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: _s(strings, 'noteLabel', '비고'),
                isDense: true,
              ),
              onChanged: (String v) {
                ref.read(dataManageProvider.notifier).setFilter(
                  filter.copyWith(noteQuery: v),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: filter.tableType == null
                ? null
                : () => ref.read(dataManageProvider.notifier).search(),
            icon: const Icon(Icons.search),
            label: Text(_s(strings, 'dataManageSearch', '검색')),
          ),
        ],
      ),
    );
  }

  // ── Result section ─────────────────────────────────────────────────────────

  Widget _buildOperationProgress(
    Map<String, String> strings,
    DataManageState s,
  ) {
    final double progress = s.operationTotal == 0
        ? 0
        : s.operationCompleted / s.operationTotal;
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${_s(strings, 'dataManageOperating', '처리중')} '
            '${s.operationCompleted} / ${s.operationTotal}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }

  Widget _buildActionBar(
    Map<String, String> strings,
    DataManageState s,
    List<MetadataTag> categoryTags,
    List<MetadataTag> paymentTags,
  ) {
    final bool canChangeTag =
        s.searchedTableType != DataTableType.income && s.hasSelection;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: <Widget>[
          Text(
            '${s.resultCount}${_s(strings, 'dataManageResultCount', '건')}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextButton(
                onPressed: s.isAllSelected
                    ? () =>
                        ref.read(dataManageProvider.notifier).clearSelection()
                    : () => ref.read(dataManageProvider.notifier).selectAll(),
                child: Text(
                  s.isAllSelected
                      ? _s(strings, 'dataManageUnselectAll', '전체해제')
                      : _s(strings, 'dataManageSelectAll', '전체선택'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: s.hasSelection
                    ? () => _confirmDelete(strings, s.selectedIds.length)
                    : null,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(_s(strings, 'dataManageDeleteSelected', '선택삭제')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC3545),
                  side: BorderSide(
                    color: s.hasSelection
                        ? const Color(0xFFDC3545)
                        : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: canChangeTag
                    ? () => _showTagChangeSheet(
                        strings, categoryTags, paymentTags, s)
                    : null,
                icon: const Icon(Icons.label_outline, size: 16),
                label: Text(_s(strings, 'dataManageChangeTag', '태그변경')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultList(
    Map<String, String> strings,
    DataManageState s,
    List<MetadataTag> categoryTags,
    List<MetadataTag> paymentTags,
    String currency,
  ) {
    if (s.resultCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(_s(strings, 'dataManageEmptyResult', '검색 결과가 없습니다.')),
        ),
      );
    }

    switch (s.searchedTableType!) {
      case DataTableType.expense:
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: s.expenses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (BuildContext ctx, int i) {
            final e = s.expenses[i];
            final bool selected = s.isSelected(e.id);
            return BootstrapSectionCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: <Widget>[
                  Checkbox(
                    value: selected,
                    onChanged: (_) => ref
                        .read(dataManageProvider.notifier)
                        .toggleSelection(e.id),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatDate(e.spentAt),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _tagLabel(categoryTags, e.categoryCode),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      e.description,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${e.amount.toCurrency()}$currency',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFFDC3545),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );

      case DataTableType.fixedExpense:
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: s.fixedExpenses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (BuildContext ctx, int i) {
            final e = s.fixedExpenses[i];
            final bool selected = s.isSelected(e.id);
            return BootstrapSectionCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: <Widget>[
                  Checkbox(
                    value: selected,
                    onChanged: (_) => ref
                        .read(dataManageProvider.notifier)
                        .toggleSelection(e.id),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatMonth(e.appliedAt),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _tagLabel(categoryTags, e.categoryCode),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      e.description,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${e.amount.toCurrency()}$currency',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFFDC3545),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );

      case DataTableType.income:
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: s.incomes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (BuildContext ctx, int i) {
            final e = s.incomes[i];
            final String sid = e.id?.toString() ?? '';
            final bool selected = sid.isNotEmpty && s.isSelected(sid);
            return BootstrapSectionCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: <Widget>[
                  Checkbox(
                    value: selected,
                    onChanged: sid.isEmpty
                        ? null
                        : (_) => ref
                            .read(dataManageProvider.notifier)
                            .toggleSelection(sid),
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatDate(e.earnedAt),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      e.description,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${e.amount.toCurrency()}$currency',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF198754),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Map<String, String> strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    final DataManageState manageState = ref.watch(dataManageProvider);
    final DataSearchFilter filter = manageState.filter;

    if (ledger == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<MetadataTag> categoryTags =
        ledger.tagsByType(MetadataTagType.category);
    final List<MetadataTag> paymentTags =
        ledger.tagsByType(MetadataTagType.paymentMethod);
    final String currency = strings['currencyUnit'] ?? '';
    final bool isIncome = filter.tableType == DataTableType.income;

    return PopScope(
      canPop: !manageState.isOperating,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _s(
                  strings,
                  'dataManageOperatingWarn',
                  '작업이 진행 중입니다. 완료 후 이동하세요.',
                ),
              ),
            ),
          );
        }
      },
      child: BootstrapPage(
        title: _s(strings, 'dataManageTitle', '데이터 관리'),
        actions: <Widget>[
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRouter.settingsRoute),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildFilterCard(
                strings,
                filter,
                categoryTags,
                paymentTags,
                isIncome,
              ),
              const SizedBox(height: 12),
              if (manageState.isSearching)
                const Center(child: CircularProgressIndicator()),
              if (manageState.isOperating)
                _buildOperationProgress(strings, manageState),
              if (manageState.hasResults && !manageState.isOperating) ...<Widget>[
                _buildActionBar(
                  strings,
                  manageState,
                  categoryTags,
                  paymentTags,
                ),
                _buildResultList(
                  strings,
                  manageState,
                  categoryTags,
                  paymentTags,
                  currency,
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
