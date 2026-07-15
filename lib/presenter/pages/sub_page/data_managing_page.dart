// """ MVVM 계층: View / Sub Feature Page """
// """ 역할: 저장된 가계부 데이터의 검색·필터·일괄 관리를 제공 """

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/controllers/tutorial_showcase_controller.dart';
import 'package:household_ledger/model/data_search_filter.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/extensions/currency_extension.dart';
import 'package:household_ledger/presenter/widgets/common/expense_editor_sheet.dart';
import 'package:household_ledger/presenter/widgets/common/ledger_dialogs.dart';
import 'package:household_ledger/provider/data_manage_provider.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/services/mock_data_service.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';

/// 데이터 관리 페이지 — 검색 조건으로 데이터를 조회하고 일괄 삭제/태그 변경을 제공한다.
class DataManagingPage extends ConsumerStatefulWidget {
  const DataManagingPage({super.key});

  @override
  ConsumerState<DataManagingPage> createState() => _DataManagingPageState();
}

class _DataManagingPageState extends ConsumerState<DataManagingPage> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final GlobalKey _filterCardKey = GlobalKey();
  final TutorialShowcaseController _showcase = TutorialShowcaseController();

  // ── 검색 로딩 인디케이터용 상태 ──────────────────────────────────────────────
  double _searchProgress = 0.0;
  int _searchMsgIndex = 0;
  bool _isPostSearchRendering = false;
  int _postSearchToken = 0; // 완료 대기 콜백이 중복 실행되는 것을 방지한다.
  int _renderTotal = 0; // 검색 완료 후 처리중 N/N에 사용
  int _renderCompleted = 0;
  Timer? _searchRotateTimer;
  Timer? _searchProgressTimer;

  void _startSearchLoading() {
    _postSearchToken++; // 진행 중인 완료 대기를 무효화한다.
    _searchProgressTimer?.cancel();
    _searchRotateTimer?.cancel();
    setState(() {
      _searchProgress = 0.0;
      _searchMsgIndex = Random().nextInt(3);
      _isPostSearchRendering = false;
    });
    _searchProgressTimer = Timer.periodic(const Duration(milliseconds: 80), (
      _,
    ) {
      if (!mounted) return;
      setState(() {
        _searchProgress = (_searchProgress + 0.01).clamp(0.0, 0.9);
      });
    });
    _searchRotateTimer = Timer.periodic(const Duration(milliseconds: 1200), (
      _,
    ) {
      if (!mounted) return;
      setState(() {
        int next;
        do {
          next = Random().nextInt(3);
        } while (next == _searchMsgIndex);
        _searchMsgIndex = next;
      });
    });
  }

  // 검색 완료: 처리중 N/N 카운트 애니메이션 후 1.5초 뒤 결과 표시
  void _completeSearchLoading(int resultCount) {
    _searchProgressTimer?.cancel();
    _searchProgressTimer = null;
    if (!mounted) return;
    final int myToken = ++_postSearchToken;
    setState(() {
      _searchProgress = 1.0;
      _isPostSearchRendering = true;
      _renderTotal = resultCount;
      _renderCompleted = 0;
    });
    // 처리중 카운트를 0 → resultCount 로 20단계에 걸쳐 약 1.1초 동안 애니메이션
    if (resultCount > 0) {
      final int stepSize = (resultCount / 20).ceil().clamp(1, resultCount);
      const stepDuration = Duration(milliseconds: 55);
      void tick(int step) {
        if (!mounted || _postSearchToken != myToken) return;
        final int next = (step * stepSize).clamp(0, resultCount);
        setState(() => _renderCompleted = next);
        if (next < resultCount) {
          Future.delayed(stepDuration, () => tick(step + 1));
        } else {
          setState(() => _renderCompleted = resultCount);
        }
      }

      Future.delayed(stepDuration, () => tick(1));
    }
    // 1500ms 후 로딩 카드 숨김 → 결과 표시
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || _postSearchToken != myToken) return;
      setState(() {
        _isPostSearchRendering = false;
        _renderTotal = 0;
        _renderCompleted = 0;
      });
      _searchRotateTimer?.cancel();
      _searchRotateTimer = null;
    });
  }

  @override
  void dispose() {
    _searchProgressTimer?.cancel();
    _searchRotateTimer?.cancel();
    _descController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _maybeStartShowcase() {
    final state = ref.read(tutorialProvider);
    _showcase.startIfReady(
      enabled: state.isActive && state.phase == TutorialPhase.dataManage,
      keys: <GlobalKey>[_filterCardKey],
      isMounted: () => mounted,
    );
  }

  void _onShowcaseComplete(int? index, GlobalKey key) {
    if (key == _filterCardKey) {
      ref.read(tutorialProvider.notifier).setPhase(TutorialPhase.settings);
      Navigator.of(context).pushNamed(AppRouter.settingsRoute);
    }
  }

  Future<void> _handleBackDuringTutorial() async {
    _showcase.dismiss();
    final strings = ref.read(localizedStringsProvider);
    final confirmed = await showTutorialExitConfirmation(
      context: context,
      strings: strings,
    );
    if (confirmed && mounted) {
      await ref.read(mockDataServiceProvider).cleanupMockData(ref);
      await ref.read(tutorialProvider.notifier).exitTutorial();
    } else if (mounted) {
      _showcase.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeStartShowcase();
      });
    }
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
    if (picked == null) {
      return;
    }
    ref
        .read(dataManageProvider.notifier)
        .setFilter(
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
    if (picked == null) {
      return;
    }
    ref
        .read(dataManageProvider.notifier)
        .setFilter(
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
    if (picked == null) {
      return;
    }
    ref
        .read(dataManageProvider.notifier)
        .setFilter(
          filter.copyWith(
            endDate: DateTime(picked.year, picked.month, picked.day),
          ),
        );
  }

  Future<void> _confirmDelete(Map<String, String> strings, int count) async {
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
              _s(
                strings,
                'dataManageDeleteConfirmMessage',
                '{count}건을 삭제합니다.',
              ).replaceAll('{count}', count.toString()),
            ),
            const SizedBox(height: 8),
            Text(
              _s(strings, 'dataManageDeleteWarning', '삭제한 데이터는 복구할 수 없습니다.'),
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
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(dataManageProvider.notifier).deleteSelected();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _s(
            strings,
            'dataManageDeleteSuccess',
            '{count}건이 삭제되었습니다.',
          ).replaceAll('{count}', count.toString()),
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
    if (manageState.searchedTableType == DataTableType.income) {
      return;
    }

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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                        child: Text(t.label),
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
                        child: Text(t.label),
                      ),
                    ),
                  ],
                  onChanged: (String? v) =>
                      setModal(() => selectedCategory = v),
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
                              builder: (BuildContext dialogCtx) => AlertDialog(
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
                            if (confirmed != true) {
                              return;
                            }
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
          label: Text(
            _s(strings, 'dataManageTableExpense', '소비기록'),
            style: TextStyle(fontSize: 12),
          ),
        ),
        ButtonSegment<DataTableType?>(
          value: DataTableType.fixedExpense,
          label: Text(
            _s(strings, 'dataManageTableFixed', '고정지출'),
            style: TextStyle(fontSize: 12),
          ),
        ),
        ButtonSegment<DataTableType?>(
          value: DataTableType.income,
          label: Text(
            _s(strings, 'dataManageTableIncome', '수입'),
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
      selected: <DataTableType?>{filter.tableType},
      emptySelectionAllowed: true,
      onSelectionChanged: (Set<DataTableType?> selected) {
        final DataTableType? picked = selected.isEmpty ? null : selected.first;
        ref
            .read(dataManageProvider.notifier)
            .setFilter(
              filter.copyWith(
                tableType: picked,
                clearTableType: picked == null,
                clearPaymentMethod: true,
                clearCategory: true,
                clearDiningOccasion: true,
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
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<DateRangeType>(
            style: SegmentedButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: <ButtonSegment<DateRangeType>>[
              ButtonSegment<DateRangeType>(
                value: DateRangeType.all,
                label: Text(
                  _s(strings, 'dataManageAllPeriod', '전체'),
                  style: TextStyle(fontSize: 12),
                ),
              ),
              ButtonSegment<DateRangeType>(
                value: DateRangeType.month,
                label: Text(
                  _s(strings, 'dataManageMonthPeriod', '특정 달'),
                  style: TextStyle(fontSize: 12),
                ),
              ),
              ButtonSegment<DateRangeType>(
                value: DateRangeType.period,
                label: Text(
                  _s(strings, 'dataManageRangePeriod', '기간 지정'),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            selected: <DateRangeType>{filter.dateRangeType},
            onSelectionChanged: (Set<DateRangeType> selection) {
              ref
                  .read(dataManageProvider.notifier)
                  .setFilter(filter.copyWith(dateRangeType: selection.first));
            },
          ),
        ),
        if (filter.dateRangeType == DateRangeType.month)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
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
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                    ),
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
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                    ),
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
    List<MetadataTag> diningOccasionTags,
    bool isIncome,
    bool isExpense,
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
                    child: Text(t.label),
                  ),
                ),
              ],
              onChanged: (String? v) {
                ref
                    .read(dataManageProvider.notifier)
                    .setFilter(
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
                    child: Text(t.label),
                  ),
                ),
              ],
              onChanged: (String? v) {
                final DataSearchFilter nextFilter = v == null
                    ? filter.copyWith(
                        clearCategory: true,
                        clearDiningOccasion: true,
                      )
                    : filter.copyWith(
                        categoryCode: v,
                        clearDiningOccasion: v != 'F',
                      );
                ref.read(dataManageProvider.notifier).setFilter(nextFilter);
              },
            ),
            if (isExpense && filter.categoryCode == 'F') ...<Widget>[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey<String?>('dining_${filter.diningOccasionCode}'),
                initialValue: filter.diningOccasionCode,
                decoration: InputDecoration(
                  labelText: _s(strings, 'diningOccasionLabel', '식사 유형 (선택)'),
                  isDense: true,
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(_s(strings, 'dataManageAll', '전체')),
                  ),
                  ...diningOccasionTags.map(
                    (MetadataTag t) => DropdownMenuItem<String>(
                      value: t.code,
                      child: Text(t.label),
                    ),
                  ),
                ],
                onChanged: (String? value) {
                  ref
                      .read(dataManageProvider.notifier)
                      .setFilter(
                        value == null
                            ? filter.copyWith(clearDiningOccasion: true)
                            : filter.copyWith(diningOccasionCode: value),
                      );
                },
              ),
            ],
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              labelText: _s(strings, 'descriptionLabel', '내용'),
              isDense: true,
            ),
            onChanged: (String v) {
              ref
                  .read(dataManageProvider.notifier)
                  .setFilter(filter.copyWith(descriptionQuery: v));
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
                ref
                    .read(dataManageProvider.notifier)
                    .setFilter(filter.copyWith(noteQuery: v));
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

  Widget _buildSearchLoadingCard(
    Map<String, String> strings,
    List<String> searchMessages,
  ) {
    if (_isPostSearchRendering) {
      // 검색 완료 후: 처리중 N/N건 (operation progress 스타일)
      final double progress = _renderTotal == 0
          ? 1.0
          : _renderCompleted / _renderTotal;
      return BootstrapSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${_s(strings, 'dataManageOperating', '처리중')} '
              '$_renderCompleted / $_renderTotal${_s(strings, 'dataManageResultCount', '건')}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFDDE5ED),
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF829AB1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 검색 중: 회전 메시지 + 시뮬레이션 진행바
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Text(
                    searchMessages[_searchMsgIndex],
                    key: ValueKey<int>(_searchMsgIndex),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF486581),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _searchProgress,
              minHeight: 6,
              backgroundColor: const Color(0xFFDDE5ED),
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(_searchProgress * 100).round()}%',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF829AB1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                        strings,
                        categoryTags,
                        paymentTags,
                        s,
                      )
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

  // ── Result section ─────────────────────────────────────────────────────────

  List<Widget> _buildResultSlivers(
    Map<String, String> strings,
    DataManageState s,
    List<MetadataTag> categoryTags,
    List<MetadataTag> subcategoryTags,
    List<MetadataTag> diningOccasionTags,
    List<MetadataTag> paymentTags,
    String currency,
  ) {
    if (s.resultCount == 0) {
      return <Widget>[
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(_s(strings, 'dataManageEmptyResult', '검색 결과가 없습니다.')),
            ),
          ),
        ),
      ];
    }

    // 항목 위젯 빌더 — 짝수 인덱스는 실제 항목, 홀수 인덱스는 구분선
    Widget Function(BuildContext, int) makeBuilder(int itemCount) {
      return (BuildContext ctx, int index) {
        if (index.isOdd) return const SizedBox(height: 6);
        final int i = index ~/ 2;
        switch (s.searchedTableType!) {
          case DataTableType.expense:
            final ExpenseEntry e = s.expenses[i];
            final bool selected = s.isSelected(e.id);
            return GestureDetector(
              onTap: () => showExpenseDetailDialog(
                context: context,
                entry: e,
                categoryTags: categoryTags,
                subcategoryTags: subcategoryTags,
                diningOccasionTags: diningOccasionTags,
                paymentTags: paymentTags,
                strings: strings,
                currency: currency,
              ),
              child: BootstrapSectionCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => showExpenseEditorSheet(
                        context: context,
                        ref: ref,
                        entry: e,
                        initialDate: e.spentAt,
                      ),
                    ),
                  ],
                ),
              ),
            );

          case DataTableType.fixedExpense:
            final e = s.fixedExpenses[i];
            final bool selected = s.isSelected(e.id);
            return BootstrapSectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(e.description, overflow: TextOverflow.ellipsis),
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

          case DataTableType.income:
            final e = s.incomes[i];
            final String sid = e.id?.toString() ?? '';
            final bool selected = sid.isNotEmpty && s.isSelected(sid);
            return BootstrapSectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    child: Text(e.description, overflow: TextOverflow.ellipsis),
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
        }
      };
    }

    final int itemCount = s.resultCount;
    // 구분선 포함 총 child 수: itemCount * 2 - 1
    final int childCount = itemCount * 2 - 1;

    return <Widget>[
      SliverList(
        delegate: SliverChildBuilderDelegate(
          makeBuilder(itemCount),
          childCount: childCount,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Map<String, String> strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    final DataManageState manageState = ref.watch(dataManageProvider);
    final DataSearchFilter filter = manageState.filter;
    final isTutorial = ref.watch(
      tutorialProvider.select(
        (s) => s.isActive && s.phase == TutorialPhase.dataManage,
      ),
    );

    if (ledger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 검색 시작/완료 감지 → 로딩 애니메이션 타이머 제어
    // addPostFrameCallback 없이 직접 호출해야 start→complete 실행 순서가 보장된다.
    ref.listen<DataManageState>(dataManageProvider, (prev, next) {
      final wasSearching = prev?.isSearching ?? false;
      if (!wasSearching && next.isSearching) {
        _startSearchLoading();
      } else if (wasSearching && !next.isSearching) {
        _completeSearchLoading(next.resultCount);
      }
    });

    final List<MetadataTag> categoryTags = ledger.tagsByType(
      MetadataTagType.category,
    );
    final List<MetadataTag> subcategoryTags = ledger.tagsByType(
      MetadataTagType.subcategory,
    );
    final List<MetadataTag> diningOccasionTags = ledger.tagsByType(
      MetadataTagType.diningOccasion,
    );
    final List<MetadataTag> paymentTags = ledger.tagsByType(
      MetadataTagType.paymentMethod,
    );
    final String currency = strings['currencyUnit'] ?? '';
    final bool isIncome = filter.tableType == DataTableType.income;
    final bool isExpense = filter.tableType == DataTableType.expense;

    Widget buildInner(BuildContext showcaseCtx) {
      _showcase.bind(showcaseCtx);
      _maybeStartShowcase();

      final page = PopScope(
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
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Showcase(
                  key: _filterCardKey,
                  title: strings['tutDataManageFilterTitle'] ?? '데이터 검색',
                  description:
                      strings['tutDataManageFilterDesc'] ??
                      '소비수단, 기간, 카테고리 등 조건으로 기록을 조회하고\n일괄 삭제 또는 태그 변경을 할 수 있어요.',
                  tooltipPosition: TooltipPosition.bottom,
                  child: _buildFilterCard(
                    strings,
                    filter,
                    categoryTags,
                    paymentTags,
                    diningOccasionTags,
                    isIncome,
                    isExpense,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (manageState.isSearching || _isPostSearchRendering)
                SliverToBoxAdapter(
                  child: _buildSearchLoadingCard(strings, <String>[
                    strings['dataManageSearching1'] ?? 'DB에서 검색중입니다...',
                    strings['dataManageSearching2'] ?? '데이터를 불러오고 있어요...',
                    strings['dataManageSearching3'] ?? '화면을 그리고 있어요...',
                  ]),
                ),
              if (manageState.isOperating)
                SliverToBoxAdapter(
                  child: _buildOperationProgress(strings, manageState),
                ),
              if (manageState.hasResults &&
                  !manageState.isOperating &&
                  !manageState.isSearching &&
                  !_isPostSearchRendering) ...<Widget>[
                SliverToBoxAdapter(
                  child: _buildActionBar(
                    strings,
                    manageState,
                    categoryTags,
                    paymentTags,
                  ),
                ),
                ..._buildResultSlivers(
                  strings,
                  manageState,
                  categoryTags,
                  subcategoryTags,
                  diningOccasionTags,
                  paymentTags,
                  currency,
                ),
              ],
            ],
          ),
        ),
      );

      if (isTutorial) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBackDuringTutorial();
          },
          child: page,
        );
      }
      return page;
    }

    return ShowCaseWidget(
      onComplete: _onShowcaseComplete,
      enableAutoScroll: true,
      builder: buildInner,
    );
  }
}
