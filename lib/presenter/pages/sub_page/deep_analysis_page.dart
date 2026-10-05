import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/localization_provider.dart';

/// 심층 분석 진입 흐름을 확인하기 위한 빈 화면이다.
/// 실제 집계나 광고 요청은 기능 구현 시 별도로 연결한다.
class DeepAnalysisPage extends ConsumerWidget {
  const DeepAnalysisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);
    return BootstrapPage(
      title: strings['deepAnalysisTitle'] ?? '',
      showSideBar: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.insights_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                strings['deepAnalysisComingSoon'] ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
