import 'package:flutter/material.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_dialog.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';
import 'package:household_ledger/services/generating_png_service.dart';

// ── Public dialog functions ──────────────────────────────────────────────────

/// 공통 확인(주로 삭제 등) 다이얼로그를 표시한다.
Future<bool> showLedgerConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return BootstrapDialog(
        title: title,
        icon: Icons.warning_amber_rounded,
        content: Text(
          message,
          style: Theme.of(dialogContext).textTheme.bodyMedium,
        ),
        actions: <Widget>[
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC3545),
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// 새 태그 입력 다이얼로그를 표시한다.
Future<MetadataTag?> showTagEditorDialog({
  required BuildContext context,
  required MetadataTagType type,
  required String title,
  required String saveLabel,
  required String cancelLabel,
  String initialCode = '',
  String initialLabel = '',
}) async {
  String code = initialCode;
  String label = initialLabel;

  final result = await showDialog<MetadataTag>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              initialValue: initialCode,
              decoration: const InputDecoration(labelText: 'Code'),
              onChanged: (String value) {
                code = value;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: initialLabel,
              decoration: const InputDecoration(labelText: 'Label'),
              onChanged: (String value) {
                label = value;
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () {
              final trimmedCode = code.trim();
              final trimmedLabel = label.trim();
              if (trimmedCode.isEmpty || trimmedLabel.isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(
                MetadataTag(type: type, code: trimmedCode, label: trimmedLabel),
              );
            },
            child: Text(saveLabel),
          ),
        ],
      );
    },
  );
  return result;
}

/// 태그 삭제 시 대체 태그를 선택하는 다이얼로그를 표시한다.
Future<String?> showReplacementTagDialog({
  required BuildContext context,
  required String title,
  required String saveLabel,
  required String cancelLabel,
  required List<MetadataTag> candidates,
}) async {
  if (candidates.isEmpty) {
    return null;
  }

  String selectedCode = candidates.first.code;
  final result = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DropdownButtonFormField<String>(
              initialValue: selectedCode,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: candidates
                  .map(
                    (MetadataTag tag) => DropdownMenuItem<String>(
                      value: tag.code,
                      child: Text('${tag.code} · ${tag.label}'),
                    ),
                  )
                  .toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  selectedCode = value;
                });
              },
            );
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(selectedCode),
            child: Text(saveLabel),
          ),
        ],
      );
    },
  );
  return result;
}

/// 소비 기록 상세 정보를 영수증 스타일 다이얼로그로 표시한다.
Future<void> showExpenseDetailDialog({
  required BuildContext context,
  required ExpenseEntry entry,
  required List<MetadataTag> categoryTags,
  required List<MetadataTag> subcategoryTags,
  required List<MetadataTag> paymentTags,
  required Map<String, String> strings,
  required String currency,
}) async {
  final rows = <MapEntry<String, String>>[
    MapEntry(strings['dateLabel'] ?? '날짜', entry.formattedDate),
    MapEntry(
      strings['categoryLabel'] ?? '구분',
      _resolveTagLabel(categoryTags, entry.categoryCode),
    ),
    MapEntry(
      strings['subcategoryLabel'] ?? '소구분',
      _resolveTagLabel(subcategoryTags, entry.subcategoryCode),
    ),
    MapEntry(
      strings['paymentMethodLabel'] ?? '지불수단',
      _resolveTagLabel(paymentTags, entry.paymentMethodCode),
    ),
    if (entry.note.isNotEmpty)
      MapEntry(strings['noteLabel'] ?? '비고', entry.note),
  ];

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _ReceiptDialog(
        shopName: strings['appTitle'] ?? '가계부',
        receiptType: strings['expenseRecordTitle'] ?? '소비내역',
        itemDescription: entry.description,
        rows: rows,
        totalLabel: strings['amountLabel'] ?? '금액',
        totalAmount: '${entry.amount.toCurrency()}$currency',
        totalColor: entry.amount < 0
            ? const Color(0xFF0D6EFD)
            : const Color(0xFFDC3545),
        closeLabel: strings['closeLabel'] ?? '닫기',
        shareLabel: strings['reportShareFile'] ?? '공유',
        footerMessage: strings['receiptFooterMessage'] ?? '기록해주셔서 감사합니다.',
      );
    },
  );
}

/// 고정지출 상세 정보를 영수증 스타일 다이얼로그로 표시한다.
Future<void> showFixedExpenseDetailDialog({
  required BuildContext context,
  required FixedExpense entry,
  required List<MetadataTag> categoryTags,
  required List<MetadataTag> paymentTags,
  required Map<String, String> strings,
  required String currency,
  required String appliedMonthText,
}) async {
  final rows = <MapEntry<String, String>>[
    MapEntry(strings['selectMonth'] ?? '적용 월', appliedMonthText),
    MapEntry(
      strings['categoryLabel'] ?? '구분',
      _resolveTagLabel(categoryTags, entry.categoryCode),
    ),
    MapEntry(
      strings['paymentMethodLabel'] ?? '지불수단',
      _resolveTagLabel(paymentTags, entry.paymentMethodCode),
    ),
    if (entry.note.isNotEmpty)
      MapEntry(strings['noteLabel'] ?? '비고', entry.note),
  ];

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _ReceiptDialog(
        shopName: strings['appTitle'] ?? '가계부',
        receiptType: strings['fixedExpenseTitle'] ?? '고정지출',
        itemDescription: entry.description,
        rows: rows,
        totalLabel: strings['amountLabel'] ?? '금액',
        totalAmount: '${entry.amount.toCurrency()}$currency',
        totalColor: const Color(0xFFDC3545),
        closeLabel: strings['closeLabel'] ?? '닫기',
        shareLabel: strings['reportShareFile'] ?? '공유',
        footerMessage: strings['receiptFooterMessage'] ?? '기록해주셔서 감사합니다.',
      );
    },
  );
}

// ── Private helper ───────────────────────────────────────────────────────────

String _resolveTagLabel(List<MetadataTag> tags, String code) {
  try {
    return tags.firstWhere((MetadataTag tag) => tag.code == code).label;
  } catch (_) {
    return '';
  }
}

// ── Receipt dialog ───────────────────────────────────────────────────────────

/// 영수증 질감의 상세 다이얼로그.
/// 상단/하단에 톱니 모양 절취선을 그리고 크림색 용지 위에 내용을 배치한다.
class _ReceiptDialog extends StatefulWidget {
  const _ReceiptDialog({
    required this.shopName,
    required this.receiptType,
    required this.itemDescription,
    required this.rows,
    required this.totalLabel,
    required this.totalAmount,
    required this.totalColor,
    required this.closeLabel,
    required this.shareLabel,
    required this.footerMessage,
  });

  final String shopName;
  final String receiptType;
  final String itemDescription;
  final List<MapEntry<String, String>> rows;
  final String totalLabel;
  final String totalAmount;
  final Color totalColor;
  final String closeLabel;
  final String shareLabel;
  final String footerMessage;

  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  // ── 용지 색상 팔레트 ──────────────────────────────────────────────────────
  static const Color _kPaper = Color(0xFFFCFAF5);
  static const Color _kInk = Color(0xFF1C1C1A);
  static const Color _kMuted = Color(0xFF7A7870);

  /// RepaintBoundary 캡처 키 — 버튼 영역은 제외하고 영수증만 캡처한다.
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      await GeneratingPngService.captureAndShare(
        _repaintKey,
        filename: 'receipt_${widget.itemDescription}.png',
        subject: widget.itemDescription,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── 캡처 영역: 영수증 비주얼 전체 (버튼 제외) ─────────────────────
          RepaintBoundary(
            key: _repaintKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── 상단 톱니 절취선 ──────────────────────────────────────
                SizedBox(
                  height: 12,
                  child: ClipRect(
                    child: CustomPaint(painter: _ZigzagPainter(atTop: true)),
                  ),
                ),

                // ── 영수증 본문 ───────────────────────────────────────────
                Container(
                  color: _kPaper,
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                  child: _buildReceiptContent(),
                ),

                // ── 하단 톱니 절취선 ──────────────────────────────────────
                SizedBox(
                  height: 12,
                  child: ClipRect(
                    child: CustomPaint(painter: _ZigzagPainter(atTop: false)),
                  ),
                ),
              ],
            ),
          ),

          // ── 버튼 영역 (캡처 제외, 다이얼로그 오버레이 위에 표시) ──────────
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSharing ? null : _share,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.share_outlined, size: 16),
                    label: Text(widget.shareLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                    child: Text(widget.closeLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ── 헤더: 앱 이름 ──────────────────────────────────────────────────
        const SizedBox(height: 10),
        Center(
          child: Text(
            widget.shopName.toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _kInk,
              letterSpacing: 3.0,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            widget.receiptType,
            style: const TextStyle(
              fontSize: 11,
              color: _kMuted,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _DashedDivider(),
        const SizedBox(height: 12),

        // ── 항목 이름 ──────────────────────────────────────────────────────
        Text(
          widget.itemDescription,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kInk,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),

        // ── 상세 행들 ──────────────────────────────────────────────────────
        for (final MapEntry<String, String> row in widget.rows)
          _ReceiptRow(label: row.key, value: row.value),
        const SizedBox(height: 12),

        // ── 합계 구분선 ────────────────────────────────────────────────────
        const _DashedDivider(),
        const SizedBox(height: 12),

        // ── 합계 행 ────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              widget.totalLabel.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _kInk,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              widget.totalAmount,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: widget.totalColor,
                letterSpacing: 0.5,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _DashedDivider(),
        const SizedBox(height: 16),

        // ── 푸터 메시지 ────────────────────────────────────────────────────
        Center(
          child: Text(
            widget.footerMessage,
            style: const TextStyle(
              fontSize: 11,
              color: _kMuted,
              letterSpacing: 0.5,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ── Receipt row ──────────────────────────────────────────────────────────────

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A7870)),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashed divider ───────────────────────────────────────────────────────────

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(painter: _DashedLinePainter()),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCCBC5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const double dashLen = 4.0;
    const double gapLen = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashLen, 0), paint);
      x += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Zigzag edge painter ──────────────────────────────────────────────────────

/// 영수증 상단/하단 톱니 절취선을 그리는 Painter.
/// [atTop] 이 true 이면 위를 향한 톱니(상단), false 이면 아래를 향한 톱니(하단).
class _ZigzagPainter extends CustomPainter {
  const _ZigzagPainter({required this.atTop});

  final bool atTop;

  static const Color _kPaper = Color(0xFFFCFAF5);
  static const double _zigW = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kPaper
      ..style = PaintingStyle.fill;

    final path = Path();

    if (atTop) {
      // 톱니 봉우리가 위를 향함; 용지는 봉우리 아래를 채움
      path.moveTo(0, size.height);
      double x = 0;
      while (x < size.width) {
        path.lineTo(x + _zigW / 2, 0);
        path.lineTo(x + _zigW, size.height);
        x += _zigW;
      }
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      // 톱니 골짜기가 아래를 향함; 용지는 골짜기 위를 채움
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      double x = size.width;
      while (x > 0) {
        path.lineTo(x - _zigW / 2, size.height);
        x -= _zigW;
        path.lineTo(x, 0);
      }
      path.lineTo(0, 0);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Backward-compatible DetailRow ────────────────────────────────────────────

/// 레이블-값 쌍을 표시하는 행 위젯. 하위 호환용으로 유지한다.
class DetailRow extends StatelessWidget {
  const DetailRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
