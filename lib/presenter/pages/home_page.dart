import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/presenter/common/widgets/expense_editor_sheet.dart';
import 'package:household_ledger/presenter/common/widgets/expense_entry_tile.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';

/// 전월동기 비교 메시지 한 항목이다.
class _CompMsg {
  const _CompMsg({
    required this.text,
    this.boldText,
    required this.color,
    this.categoryText,
  });
  final String text;
  final String? boldText;     // 금액 — bold + [color]
  final Color color;          // 도트 색 및 boldText 색
  final String? categoryText; // 카테고리명 — 초록색
}

/// 메인 대시보드 화면이다.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// 전월동기 비교 메시지 페이지 인덱스 (슬라이딩 윈도우 방식으로 순환)
  int _compMsgPage = 0;
  Timer? _compTimer;

  @override
  void initState() {
    super.initState();
    _compTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _compMsgPage++);
    });
  }

  @override
  void dispose() {
    _compTimer?.cancel();
    super.dispose();
  }

  void _push(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  String _resolveTagLabel(List<MetadataTag> tags, String code) {
    try {
      return tags.firstWhere((MetadataTag t) => t.code == code).label;
    } catch (_) {
      return code;
    }
  }

  Future<void> _deleteExpense(
    BuildContext context,
    Map<String, String> strings,
    ExpenseEntry entry,
    String currency,
  ) async {
    final summary =
        '${entry.description} : ${entry.amount.toCurrency()}$currency\n'
        '${strings['deleteAlertCaution'] ?? ''}';
    final confirmed = await showLedgerConfirmDialog(
      context: context,
      title: strings['confirmDelete'] ?? '삭제 확인',
      message: '$summary ${strings['confirmDeleteQuestion'] ?? ''}',
      confirmLabel: strings['delete'] ?? '삭제',
      cancelLabel: strings['cancel'] ?? '취소',
    );
    if (!confirmed) return;
    await ref.read(ledgerProvider.notifier).deleteExpense(entry.id);
    ref.invalidate(monthlyExpensesProvider);
    ref.invalidate(rangeExpensesProvider);
  }

  // ─── 전월동기 비교 카드 ──────────────────────────────────────────

  static const Color _categoryGreen = Color(0xFF198754);

  /// _CompMsg의 텍스트를 InlineSpan 목록으로 변환한다.
  ///
  /// - boldText  → FontWeight.w800 + msg.color
  /// - categoryText → FontWeight.w700 + _categoryGreen
  ///
  /// 두 하이라이트 구간을 위치 순서대로 정렬하여 단일 패스로 span을 생성한다.
  /// _compBullet과 _measureBulletHeight 양쪽에서 공유한다.
  List<InlineSpan> _buildMsgSpans(_CompMsg msg) {
    // (start, end, TextStyle) 형태의 하이라이트 목록
    final List<(int, int, TextStyle)> hl = <(int, int, TextStyle)>[];

    void addHighlight(String? sub, TextStyle style) {
      if (sub == null || sub.isEmpty) return;
      final int idx = msg.text.indexOf(sub);
      if (idx >= 0) hl.add((idx, idx + sub.length, style));
    }

    addHighlight(
      msg.boldText,
      TextStyle(fontWeight: FontWeight.w800, color: msg.color),
    );
    addHighlight(
      msg.categoryText,
      const TextStyle(fontWeight: FontWeight.w700, color: _categoryGreen),
    );

    if (hl.isEmpty) return <InlineSpan>[TextSpan(text: msg.text)];

    hl.sort((a, b) => a.$1.compareTo(b.$1));

    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final (int start, int end, TextStyle style) in hl) {
      if (start > cursor) {
        spans.add(TextSpan(text: msg.text.substring(cursor, start)));
      }
      spans.add(TextSpan(text: msg.text.substring(start, end), style: style));
      cursor = end;
    }
    if (cursor < msg.text.length) {
      spans.add(TextSpan(text: msg.text.substring(cursor)));
    }
    return spans;
  }

  /// _CompMsg의 실제 렌더 높이를 TextPainter로 측정한다.
  double _measureBulletHeight(_CompMsg msg, double textWidth) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.5),
        children: _buildMsgSpans(msg),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textWidth);
    return tp.height;
  }

  /// 불릿 항목을 빌드한다 (_CompMsg 기반).
  Widget _compBullet(_CompMsg msg) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: msg.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, height: 1.5),
              children: _buildMsgSpans(msg),
            ),
          ),
        ),
      ],
    );
  }

  /// 전월동기 비교 카드를 빌드한다.
  ///
  /// 구조:
  ///   [1] 총액 비교 불릿 (고정)
  ///   [2] 카테고리별 증감 불릿 — 모든 카테고리를 4초마다 AnimatedSwitcher로 순환
  ///   [3] 절감 권유 불릿 (case a + topGainer 있을 때만, 고정)
  Widget _buildComparisonCard(
    BuildContext context,
    Map<String, String> strings,
    int currentTotal,
    int prevTotal,
    List<ExpenseEntry> currentExpenses,
    List<ExpenseEntry> prevExpenses,
    List<MetadataTag> categoryTags,
    String currency,
  ) {
    final int diff = currentTotal - prevTotal;
    final bool moreSpent = diff > 0;
    final double diffPercent = prevTotal > 0
        ? (diff.abs() / prevTotal * 100)
        : 0.0;

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

    // 카테고리별 증감 목록 (절댓값 내림차순)
    final Set<String> allCodes = <String>{...curCat.keys, ...preCat.keys};
    final List<MapEntry<String, int>> catDiffs =
        allCodes
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


    // [2] 카테고리별 증감 메시지 목록 (모든 카테고리)
    final List<_CompMsg> categoryMsgs = catDiffs.map((MapEntry<String, int> e) {
      final bool catMore = e.value > 0;
      final String catAmt = '${e.value.abs().toCurrency()}$currency';
      final String label = _resolveTagLabel(categoryTags, e.key);
      if (catMore) {
        return _CompMsg(
          text:
              (strings['homeCompMoreCategoryMsg'] ??
                      '지난달 보다 {category}에서 {amount} 더 지출이 많아요.')
                  .replaceAll('{category}', label)
                  .replaceAll('{amount}', catAmt),
          boldText: catAmt,
          color: const Color(0xFFDC3545),
          categoryText: label,
        );
      } else {
        return _CompMsg(
          text:
              (strings['homeCompLessCategoryAmountMsg'] ??
                      '지난달 보다 {category}에서 {amount} 지출이 줄었어요.')
                  .replaceAll('{category}', label)
                  .replaceAll('{amount}', catAmt),
          boldText: catAmt,
          color: const Color(0xFF0D6EFD),
          categoryText: label,
        );
      }
    }).toList();

    final Color accentColor = moreSpent
        ? const Color(0xFFDC3545)
        : const Color(0xFF0D6EFD);
    final String amountText = '${diff.abs().toCurrency()}$currency';
    final String percentText = diffPercent.toStringAsFixed(1);

    final String headerLine = moreSpent
        ? (strings['homeCompMorePercent'] ?? '{percent}% 더 사용하셨네요!').replaceAll(
            '{percent}',
            percentText,
          )
        : (strings['homeCompLessPercent'] ?? '{percent}% 덜 사용하셨네요!').replaceAll(
            '{percent}',
            percentText,
          );

    // [1] 총액 고정 메시지
    final _CompMsg msg1 = moreSpent
        ? _CompMsg(
            text:
                (strings['homeCompMoreAmountMsg'] ??
                        '지난달 보다 {amount} 더 사용하셨어요.')
                    .replaceAll('{amount}', amountText),
            boldText: amountText,
            color: accentColor,
          )
        : _CompMsg(
            text:
                (strings['homeCompLessAmountMsg'] ??
                        '지난달 보다 {amount} 덜 사용하고 있어요!! 이대로 관리해볼까요?')
                    .replaceAll('{amount}', amountText),
            boldText: amountText,
            color: accentColor,
          );

    // [3] 절감 권유 순환 메시지 목록
    // 지출이 늘어난 카테고리 각각에 어드바이스 1개씩, 3가지 템플릿을 순환 사용한다.
    final List<_CompMsg> msg3Msgs = <_CompMsg>[];
    if (moreSpent) {
      final List<String> adviceKeys = <String>[
        'homeCompMoreAdviceMsg',
        'homeCompMoreAdviceMsg2',
        'homeCompMoreAdviceMsg3',
      ];
      // catDiffs는 이미 절댓값 내림차순 정렬 + 증가 카테고리만 필터
      final List<MapEntry<String, int>> gainers =
          catDiffs.where((MapEntry<String, int> e) => e.value > 0).toList();
      for (int i = 0; i < gainers.length; i++) {
        final String label = _resolveTagLabel(categoryTags, gainers[i].key);
        final String template =
            strings[adviceKeys[i % adviceKeys.length]] ??
            '{category}의 소비를 줄여볼까요?';
        msg3Msgs.add(_CompMsg(
          text: template.replaceAll('{category}', label),
          color: Colors.orange.shade700,
          categoryText: label,
        ));
      }
    }

    // [2][3] 공통 순환 인덱스 (같은 타이머)
    final int numCat = categoryMsgs.length;
    final int catPage = numCat == 0 ? 0 : _compMsgPage % numCat;
    final int numMsg3 = msg3Msgs.length;
    final int msg3Page = numMsg3 == 0 ? 0 : _compMsgPage % numMsg3;

    return BootstrapSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 헤더
          Row(
            children: <Widget>[
              Icon(
                moreSpent
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 6),
              Text(
                strings['homeCompPrevPeriodTitle'] ?? '지난달 동기 대비',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            headerLine,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 6),

          // [1] 총액 고정 불릿
          _compBullet(msg1),

          // [2] 카테고리별 순환 불릿 (카테고리 있을 때만)
          // LayoutBuilder로 가용 너비를 파악 → TextPainter로 모든 메시지의
          // 렌더 높이를 미리 계산 → AnimatedSwitcher를 최대 높이로 고정한다.
          if (numCat > 0) ...<Widget>[
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (BuildContext ctx, BoxConstraints bc) {
                // 불릿 Row 안 텍스트 가용 너비 (도트 5 + 간격 8 = 13 제외)
                final double textWidth = bc.maxWidth - 13.0;
                // 모든 카테고리 메시지를 실제 span 구조로 측정해 최대 높이 확정
                const double lineH = 13.0 * 1.5; // 한 줄 높이
                double maxH = lineH;
                for (final _CompMsg msg in categoryMsgs) {
                  final double h = _measureBulletHeight(msg, textWidth);
                  if (h > maxH) maxH = h;
                }
                // TextPainter는 폰트 디센더/서브픽셀 오차를 완전히 반영하지
                // 못할 수 있으므로 한 줄 높이의 절반을 여유분으로 추가한다.
                final double fixedH = maxH + lineH * 0.5;

                return SizedBox(
                  height: fixedH,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (Widget child, Animation<double> anim) {
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 0.15),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: anim,
                                  curve: Curves.easeOut,
                                ),
                              ),
                          child: child,
                        ),
                      );
                    },
                    child: SizedBox(
                      key: ValueKey<int>(catPage),
                      width: double.infinity,
                      height: fixedH,
                      child: _compBullet(categoryMsgs[catPage]),
                    ),
                  ),
                );
              },
            ),
          ],

          // [3] 절감 권유 순환 불릿 (case a만, [2]와 동일한 AnimatedSwitcher 구조)
          if (msg3Msgs.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (BuildContext ctx, BoxConstraints bc) {
                final double textWidth = bc.maxWidth - 13.0;
                const double lineH = 13.0 * 1.5;
                double maxH = lineH;
                for (final _CompMsg msg in msg3Msgs) {
                  final double h = _measureBulletHeight(msg, textWidth);
                  if (h > maxH) maxH = h;
                }
                final double fixedH = maxH + lineH * 0.5;

                return SizedBox(
                  height: fixedH,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (Widget child, Animation<double> anim) {
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.15),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: SizedBox(
                      key: ValueKey<int>(msg3Page),
                      width: double.infinity,
                      height: fixedH,
                      child: _compBullet(msg3Msgs[msg3Page]),
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final ledger = ref.watch(ledgerProvider).asData?.value;
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final monthlyExpense = ledger?.monthlyExpenseTotal(month) ?? 0;
    final monthlyIncomes = ref
        .watch(monthlyIncomesProvider(month))
        .asData
        ?.value;
    final monthlyIncomeTotal = (monthlyIncomes ?? const <IncomeEntry>[])
        .fold<int>(0, (int total, IncomeEntry entry) => total + entry.amount);
    final monthlyBudget = ledger == null
        ? 0
        : (monthlyIncomeTotal > 0
              ? monthlyIncomeTotal
              : ledger.settings.monthlyBudget);
    final monthlyFixedExpense = ledger?.fixedExpenseTotalForMonth(month) ?? 0;
    final remainingBudget = ledger == null
        ? 0
        : monthlyBudget - monthlyExpense - monthlyFixedExpense;
    final greeting = ledger == null
        ? ''
        : (strings['homepageGreeting'] ?? '{name}').replaceAll(
            '{name}',
            ledger.userProfile.name,
          );

    // 전월동기 비교 데이터
    final List<ExpenseEntry> prevExpenses =
        ledger?.prevPeriodExpenses ?? const <ExpenseEntry>[];
    final int prevTotal = prevExpenses.fold(
      0,
      (int s, ExpenseEntry e) => s + e.amount,
    );
    final bool hasPrevData = prevExpenses.isNotEmpty;

    final recentExpensesAsync = ref.watch(monthlyExpensesProvider(month));
    final currency = strings['currencyUnit'] ?? '';
    final categoryTags =
        ledger?.tagsByType(MetadataTagType.category) ?? const <MetadataTag>[];
    final subcategoryTags =
        ledger?.tagsByType(MetadataTagType.subcategory) ??
        const <MetadataTag>[];
    final paymentTags =
        ledger?.tagsByType(MetadataTagType.paymentMethod) ??
        const <MetadataTag>[];

    return BootstrapPage(
      title: strings['homeTitle'] ?? '',
      actions: <Widget>[
        IconButton(
          onPressed: () => _push(context, AppRouter.dataManageRoute),
          icon: const Icon(Icons.manage_search_rounded),
          tooltip: strings['dataManageTitle'] ?? '데이터 관리',
        ),
        IconButton(
          onPressed: () => _push(context, AppRouter.settingsRoute),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BootstrapSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: BootstrapSummaryTile(
                          label: strings['totalSpent'] ?? '',
                          value:
                              '${monthlyExpense.toCurrency()} ${strings['currencyUnit'] ?? ''}',
                          color: const Color(0xFFDC3545),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BootstrapSummaryTile(
                          label: strings['remainingBudget'] ?? '',
                          value:
                              '${remainingBudget.toCurrency()} ${strings['currencyUnit'] ?? ''}',
                          color: const Color(0xFF198754),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            /// 전월동기 비교 카드 (선결조건: 전월 데이터 존재)
            if (hasPrevData) ...<Widget>[
              _buildComparisonCard(
                context,
                strings,
                monthlyExpense,
                prevTotal,
                ledger!.expenses,
                prevExpenses,
                categoryTags,
                currency,
              ),
              const SizedBox(height: 10),
            ],

            /// 빠른 지출 기록 버튼
            BootstrapActionButton(
              label: strings['quickExpense'] ?? '',
              icon: Icons.add_circle_outline_rounded,
              onPressed: () => showExpenseEditorSheet(
                context: context,
                ref: ref,
                initialDate: DateTime.now(),
              ),
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: const Color(0xFF102A43),
            ),

            const SizedBox(height: 10),

            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    strings['homeRecentExpensesTitle'] ?? '최근 소비 기록',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _push(context, AppRouter.expenseRecordRoute),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(strings['homeViewAll'] ?? '더보기'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            recentExpensesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, _) => const SizedBox.shrink(),
              data: (List<ExpenseEntry> entries) {
                if (ledger == null || entries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(strings['emptyData'] ?? '데이터가 없습니다.'),
                    ),
                  );
                }

                final sorted = entries.toList()
                  ..sort(
                    (ExpenseEntry a, ExpenseEntry b) =>
                        b.spentAt.compareTo(a.spentAt),
                  );
                final recent = sorted.take(5).toList();

                final grouped = <DateTime, List<ExpenseEntry>>{};
                for (final ExpenseEntry e in recent) {
                  final day = DateTime(
                    e.spentAt.year,
                    e.spentAt.month,
                    e.spentAt.day,
                  );
                  grouped.putIfAbsent(day, () => <ExpenseEntry>[]).add(e);
                }
                final groupedList = grouped.entries.toList()
                  ..sort(
                    (
                      MapEntry<DateTime, List<ExpenseEntry>> a,
                      MapEntry<DateTime, List<ExpenseEntry>> b,
                    ) => b.key.compareTo(a.key),
                  );

                final daySectionTemplate =
                    strings['expenseRecordDaySectionLabel'] ??
                    '{month}월 {day}일';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final MapEntry<DateTime, List<ExpenseEntry>> section
                        in groupedList) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 4,
                          top: 4,
                          bottom: 8,
                        ),
                        child: Text(
                          daySectionTemplate
                              .replaceAll(
                                '{month}',
                                section.key.month.toString().padLeft(2, '0'),
                              )
                              .replaceAll(
                                '{day}',
                                section.key.day.toString().padLeft(2, '0'),
                              ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1F3A5F),
                              ),
                        ),
                      ),
                      for (final ExpenseEntry entry in section.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ExpenseEntryTile(
                            entry: entry,
                            categoryLabel: _resolveTagLabel(
                              categoryTags,
                              entry.categoryCode,
                            ),
                            currency: currency,
                            editTooltip: strings['edit'] ?? '수정',
                            deleteTooltip: strings['delete'] ?? '삭제',
                            onTap: () => showExpenseDetailDialog(
                              context: context,
                              entry: entry,
                              categoryTags: categoryTags,
                              subcategoryTags: subcategoryTags,
                              paymentTags: paymentTags,
                              strings: strings,
                              currency: currency,
                            ),
                            onEdit: () => showExpenseEditorSheet(
                              context: context,
                              ref: ref,
                              entry: entry,
                              initialDate: entry.spentAt,
                            ),
                            onDelete: () => _deleteExpense(
                              context,
                              strings,
                              entry,
                              currency,
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
