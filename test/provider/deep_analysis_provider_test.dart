import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/provider/deep_analysis_provider.dart';
import 'package:household_ledger/features/analysis/calculators/deep_analysis_calculator.dart';

DeepAnalysisSnapshot snapshot(DateTime month) => (
  input: (
    month: month,
    today: DateTime(2026, 10, 21),
    expenses: [],
    fixedExpenses: [],
  ),
  labels: {},
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('entry is inert, fresh generation, failure and retry', () async {
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        deepAnalysisLoaderProvider.overrideWithValue((m, t) async {
          reads++;
          if (reads == 1) throw StateError('failed');
          return snapshot(m);
        }),
        deepAnalysisRunnerProvider.overrideWithValue(
          (i) async => calculateDeepAnalysis(i),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(deepAnalysisProvider, (_, _) {});
    addTearDown(sub.close);
    expect(reads, 0);
    expect(container.read(deepAnalysisProvider).requireValue.report, isNull);
    final notifier = container.read(deepAnalysisProvider.notifier);
    await notifier.generate(DateTime(2026, 9));
    expect(container.read(deepAnalysisProvider).hasError, isTrue);
    await notifier.generate(DateTime(2026, 9));
    expect(reads, 2);
    expect(
      container.read(deepAnalysisProvider).requireValue.report!.month,
      DateTime(2026, 9),
    );
  });
  test('late request cannot overwrite a newer report', () async {
    final old = Completer<DeepAnalysisSnapshot>();
    final container = ProviderContainer(
      overrides: [
        deepAnalysisLoaderProvider.overrideWithValue(
          (m, t) => m.month == 8 ? old.future : Future.value(snapshot(m)),
        ),
        deepAnalysisRunnerProvider.overrideWithValue(
          (i) async => calculateDeepAnalysis(i),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(deepAnalysisProvider, (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(deepAnalysisProvider.notifier);
    final pending = notifier.generate(DateTime(2026, 8));
    await notifier.generate(DateTime(2026, 9));
    old.complete(snapshot(DateTime(2026, 8)));
    await pending;
    expect(
      container.read(deepAnalysisProvider).requireValue.report!.month,
      DateTime(2026, 9),
    );
  });
  test('native worker transfers snapshot models', () async {
    final container = ProviderContainer(
      overrides: [
        deepAnalysisLoaderProvider.overrideWithValue(
          (m, t) async => snapshot(m),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(deepAnalysisProvider, (_, _) {});
    addTearDown(sub.close);
    await container
        .read(deepAnalysisProvider.notifier)
        .generate(DateTime(2026, 9));
    expect(container.read(deepAnalysisProvider).requireValue.report!.total, 0);
  });
}
