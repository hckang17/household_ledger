import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 월 선택 다이얼로그를 표시하고 선택 결과를 반환한다.
///
/// 좌우 화살표로 이전·다음 달을 탐색하며, 현재 달 이후로는 이동하지 못한다.
/// 선택 취소 시 null을 반환한다.
///
/// 사용 예:
/// ```dart
/// final picked = await showMonthSelectorDialog(
///   context: context,
///   initialMonth: _selectedMonth,
///   strings: strings,
/// );
/// if (picked != null) setState(() => _selectedMonth = picked);
/// ```
Future<DateTime?> showMonthSelectorDialog({
  required BuildContext context,
  required DateTime initialMonth,
  required Map<String, String> strings,
  /// 현재 달 이후 선택 허용 여부. false(기본)이면 미래 달 비활성화.
  bool allowFuture = false,
}) async {
  final DateTime now = DateTime.now();
  DateTime picked = DateTime(initialMonth.year, initialMonth.month);

  return showDialog<DateTime>(
    context: context,
    builder: (BuildContext ctx) => StatefulBuilder(
      builder: (BuildContext ctx2, StateSetter setS) {
        final bool atFutureLimit = !allowFuture &&
            (picked.year > now.year ||
                (picked.year == now.year && picked.month >= now.month));

        return AlertDialog(
          title: Text(
            strings['selectMonth'] ?? '달 선택',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setS(
                  () => picked = DateTime(picked.year, picked.month - 1),
                ),
              ),
              Text(
                DateFormat('yyyy.MM').format(picked),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: atFutureLimit
                    ? null
                    : () => setS(
                        () => picked = DateTime(picked.year, picked.month + 1),
                      ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(strings['cancel'] ?? '취소'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(DateTime(picked.year, picked.month)),
              child: Text(strings['apply'] ?? '적용'),
            ),
          ],
        );
      },
    ),
  );
}
