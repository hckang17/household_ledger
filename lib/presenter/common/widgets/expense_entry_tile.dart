import 'package:flutter/material.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/extension/currency_extension.dart';

/// 소비 기록 한 항목을 표시하는 재사용 가능한 타일 위젯이다.
///
/// 카테고리·내용·금액을 가로로 나열하고 수정/삭제 버튼을 포함한다.
/// 타일 전체를 탭하면 [onTap] 콜백이 호출된다.
class ExpenseEntryTile extends StatelessWidget {
  /// [ExpenseEntryTile]을 생성한다.
  const ExpenseEntryTile({
    super.key,
    required this.entry,
    required this.categoryLabel,
    required this.currency,
    required this.editTooltip,
    required this.deleteTooltip,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  /// 표시할 소비 항목 데이터
  final ExpenseEntry entry;

  /// 소비 구분 레이블 (카테고리 태그의 label 값)
  final String categoryLabel;

  /// 통화 단위 문자열 (예: ₩, ¥)
  final String currency;

  /// 수정 버튼 툴팁 텍스트
  final String editTooltip;

  /// 삭제 버튼 툴팁 텍스트
  final String deleteTooltip;

  /// 타일 탭 시 호출되는 콜백 (상세 보기)
  final VoidCallback onTap;

  /// 수정 버튼 탭 시 호출되는 콜백
  final VoidCallback onEdit;

  /// 삭제 버튼 탭 시 호출되는 콜백
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: BootstrapSectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(
                categoryLabel,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Text(
                entry.description,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(
                '${entry.amount.toCurrency()}$currency',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: entry.amount < 0
                      ? const Color(0xFF0D6EFD)
                      : const Color(0xFFDC3545),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: editTooltip,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: deleteTooltip,
            ),
          ],
        ),
      ),
    );
  }
}
