import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/features/analysis/calculators/deep_analysis_calculator.dart';
import 'package:household_ledger/features/analysis/models/deep_analysis_report.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'ledger_provider.dart';

typedef DeepAnalysisSnapshot = ({
  DeepAnalysisInput input,
  Map<String, String> labels,
});
typedef DeepAnalysisLoader =
    Future<DeepAnalysisSnapshot> Function(DateTime month, DateTime today);

/// Fresh reads on explicit generation avoid retaining stale cached reports after
/// edits/imports. No reads occur merely by entering the page.
final deepAnalysisLoaderProvider = Provider<DeepAnalysisLoader>(
  (ref) => (month, today) async {
    final start = DateTime(month.year, month.month - 12);
    final end = DateTime(month.year, month.month + 1);
    final (expenses, fixed, ledger) = await (
      ref
          .read(expenseDatabaseServiceProvider)
          .loadExpensesByRange(start: start, endExclusive: end),
      ref
          .read(fixedExpenseDatabaseServiceProvider)
          .loadFixedExpensesByRange(start: start, endExclusive: end),
      ref.read(ledgerProvider.future),
    ).wait;
    return (
      input: (
        month: month,
        today: today,
        expenses: expenses,
        fixedExpenses: fixed,
      ),
      labels: {
        for (final tag in ledger.tagsByType(MetadataTagType.category))
          tag.code: tag.label,
      },
    );
  },
);
final deepAnalysisRunnerProvider =
    Provider<Future<DeepAnalysisReport> Function(DeepAnalysisInput)>(
      (ref) =>
          (input) => compute(
            calculateDeepAnalysis,
            input,
            debugLabel: 'deep-analysis',
          ),
    );
final deepAnalysisClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// A generated report is a snapshot, never relabelled by the pending month picker.
class DeepAnalysisGeneration {
  const DeepAnalysisGeneration({
    this.report,
    this.labels = const {},
    this.calculating = false,
  });
  final DeepAnalysisReport? report;
  final Map<String, String> labels;
  final bool calculating;
}

final deepAnalysisProvider =
    AsyncNotifierProvider.autoDispose<
      DeepAnalysisNotifier,
      DeepAnalysisGeneration
    >(DeepAnalysisNotifier.new);

class DeepAnalysisNotifier extends AsyncNotifier<DeepAnalysisGeneration> {
  int _run = 0;
  @override
  DeepAnalysisGeneration build() => const DeepAnalysisGeneration();

  Future<void> generate(DateTime selected) async {
    final run = ++_run;
    final month = DateTime(selected.year, selected.month);
    final today = ref.read(deepAnalysisClockProvider)();
    final loader = ref.read(deepAnalysisLoaderProvider);
    final runner = ref.read(deepAnalysisRunnerProvider);
    state = const AsyncLoading();
    try {
      final snapshot = await loader(month, today);
      if (!ref.mounted || run != _run) return;
      state = const AsyncData(DeepAnalysisGeneration(calculating: true));
      final report = await runner(snapshot.input);
      if (!ref.mounted || run != _run) return;
      state = AsyncData(
        DeepAnalysisGeneration(
          report: report,
          labels: Map.unmodifiable(snapshot.labels),
        ),
      );
    } catch (error, stack) {
      if (ref.mounted && run == _run) state = AsyncError(error, stack);
    }
  }
}
