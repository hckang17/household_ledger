import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/widgets/deep_analysis_page/deep_analysis_dashboard.dart';
import 'package:household_ledger/provider/deep_analysis_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';

/// 데이터 공급의 로딩·오류·결과를 심층분석 화면에 연결한다.
class DeepAnalysisPage extends ConsumerWidget {
  const DeepAnalysisPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);
    return BootstrapPage(
      title: strings['deepAnalysisTitle'] ?? '',
      showSideBar: false,
      child: ref
          .watch(deepAnalysisProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings['deepLoadError'] ?? ''),
                  TextButton(
                    onPressed: () => ref.invalidate(deepAnalysisProvider),
                    child: Text(strings['deepRetry'] ?? ''),
                  ),
                ],
              ),
            ),
            data: (report) =>
                DeepAnalysisDashboard(report: report, strings: strings),
          ),
    );
  }
}
