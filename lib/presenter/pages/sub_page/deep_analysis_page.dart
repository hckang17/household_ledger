import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/widgets/common/month_selector_dialog.dart';
import 'package:household_ledger/presenter/widgets/deep_analysis_page/deep_analysis_dashboard.dart';
import 'package:household_ledger/provider/deep_analysis_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';

/// Month selection is inert until generation is explicitly requested.
class DeepAnalysisPage extends ConsumerStatefulWidget {
  const DeepAnalysisPage({super.key});
  @override
  ConsumerState<DeepAnalysisPage> createState() => _DeepAnalysisPageState();
}

class _DeepAnalysisPageState extends ConsumerState<DeepAnalysisPage> {
  late DateTime month;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    final now = ref.read(deepAnalysisClockProvider)();
    month = DateTime(now.year, now.month);
  }

  void generate() {
    setState(() => generation++);
    ref.read(deepAnalysisProvider.notifier).generate(month);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(localizedStringsProvider);
    final state = ref.watch(deepAnalysisProvider);
    final data = state.asData?.value;
    final busy = state.isLoading || (data?.calculating ?? false);
    return BootstrapPage(
      title: s['deepAnalysisTitle'] ?? '',
      showSideBar: false,
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final picked = await showMonthSelectorDialog(
                          context: context,
                          initialMonth: month,
                          strings: s,
                        );
                        if (picked != null && mounted) {
                          setState(() => month = picked);
                        }
                      },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '${s['selectMonth']} · ${month.year}.${month.month.toString().padLeft(2, '0')}',
                ),
              ),
              FilledButton(
                onPressed: busy ? null : generate,
                child: Text(s['deepGenerate']!),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: busy
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          s[data?.calculating == true
                              ? 'deepCalculating'
                              : 'deepReading']!,
                        ),
                      ],
                    ),
                  )
                : state.hasError
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s['deepLoadError']!),
                        TextButton(
                          onPressed: generate,
                          child: Text(s['deepRetry']!),
                        ),
                      ],
                    ),
                  )
                : data?.report == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(s['deepGenerateHint']!),
                    ),
                  )
                : DeepAnalysisDashboard(
                    key: ValueKey(generation),
                    report: data!.report!,
                    strings: s,
                    categoryLabels: data.labels,
                  ),
          ),
        ],
      ),
    );
  }
}
