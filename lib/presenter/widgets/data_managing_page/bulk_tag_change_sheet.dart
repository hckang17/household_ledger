import 'package:flutter/material.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/common/metadata_tag_icon_label.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/data_managing_page/bulk_expense_classification_fields.dart';

/// 데이터 관리 일괄 변경 시트에서 확정한 변경값이다.
class BulkTagChangeSelection {
  const BulkTagChangeSelection({
    this.paymentMethodCode,
    this.categoryCode,
    this.expenseClassification = const BulkExpenseClassificationChange(),
  });

  final String? paymentMethodCode;
  final String? categoryCode;
  final BulkExpenseClassificationChange expenseClassification;
}

/// 소비수단·소비구분·소비 소구분·여행 연결 일괄 변경 시트를 표시한다.
Future<BulkTagChangeSelection?> showBulkTagChangeSheet({
  required BuildContext context,
  required Map<String, String> strings,
  required List<MetadataTag> categoryTags,
  required List<MetadataTag> subcategoryTags,
  required List<MetadataTag> paymentTags,
  required List<Trip> trips,
  required int selectedCount,
  required bool isExpense,
  String? activeTripId,
}) {
  String? selectedPayment;
  String? selectedCategory;
  var expenseClassification = const BulkExpenseClassificationChange();

  String text(String key, String fallback) => strings[key] ?? fallback;

  return showModalBottomSheet<BulkTagChangeSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        final hasChanges =
            selectedPayment != null ||
            selectedCategory != null ||
            expenseClassification.hasChanges;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  text('dataManageChangeTagTitle', '태그 일괄 변경'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$selectedCount${text('dataManageSelectedCount', '건 선택됨')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: selectedPayment,
                  decoration: InputDecoration(
                    labelText: text('paymentMethodLabel', '소비수단'),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(text('dataManageNoChange', '변경 안함')),
                    ),
                    ...paymentTags.map(
                      (MetadataTag tag) => DropdownMenuItem<String>(
                        value: tag.code,
                        child: Text(tag.label),
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    setModalState(() => selectedPayment = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                    labelText: text('categoryLabel', '소비구분'),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(text('dataManageNoChange', '변경 안함')),
                    ),
                    ...categoryTags.map(
                      (MetadataTag tag) => DropdownMenuItem<String>(
                        value: tag.code,
                        child: MetadataTagIconLabel(tag: tag),
                      ),
                    ),
                  ],
                  onChanged: (String? value) {
                    setModalState(() => selectedCategory = value);
                  },
                ),
                if (isExpense) ...<Widget>[
                  const SizedBox(height: 12),
                  BulkExpenseClassificationFields(
                    subcategoryTags: subcategoryTags,
                    trips: trips,
                    activeTripId: activeTripId,
                    strings: strings,
                    onChanged: (BulkExpenseClassificationChange value) {
                      setModalState(() => expenseClassification = value);
                    },
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: hasChanges
                        ? () => Navigator.of(sheetContext).pop(
                            BulkTagChangeSelection(
                              paymentMethodCode: selectedPayment,
                              categoryCode: selectedCategory,
                              expenseClassification: expenseClassification,
                            ),
                          )
                        : null,
                    child: Text(text('dataManageChangeTagApply', '변경 적용')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
