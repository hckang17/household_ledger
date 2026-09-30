import 'package:flutter/material.dart';
import 'package:household_ledger/services/imexporting_file/data_im_export_service.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_dialog.dart';

/// 파싱이 끝난 동일 결과의 건수를 확인한 뒤 전체 교체를 승인한다.
Future<bool> showImportPreviewDialog(
  BuildContext context,
  Map<String, String> strings,
  ImportResult result,
) async {
  final summary = strings['importPreviewCounts']!
      .replaceAll('{expenses}', '${result.expenses.length}')
      .replaceAll('{fixed}', '${result.fixedExpenses.length}')
      .replaceAll('{incomes}', '${result.incomes.length}')
      .replaceAll('{trips}', '${result.trips.length}')
      .replaceAll('{tags}', '${result.ledgerState!.metadataTags.length}');
  return await showDialog<bool>(
        context: context,
        builder: (context) => BootstrapDialog(
          icon: Icons.restore_rounded,
          title: strings['importConfirmTitle']!,
          content: Text(
            '$summary\n\n${strings['importPreviewReplaceMessage']}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings['cancel']!),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings['importButton']!),
            ),
          ],
        ),
      ) ??
      false;
}
