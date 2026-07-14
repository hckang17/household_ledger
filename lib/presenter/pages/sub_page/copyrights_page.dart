// """ MVVM 계층: View / Sub Feature Page """
// """ 역할: 업데이트 안내, 제작자 연락처, 저작권 및 라이선스 정보 제공 """

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/localization_provider.dart';

/// 제작자 및 오픈소스 크레딧을 표시한다.
class CopyrightsPage extends ConsumerWidget {
  const CopyrightsPage({super.key});

  static const String _contactEmail = 'hckang17@naver.com';

  String _text(Map<String, String> strings, String key, String fallback) =>
      strings[key] ?? fallback;

  Future<void> _copyEmail(
    BuildContext context,
    Map<String, String> strings,
  ) async {
    await Clipboard.setData(const ClipboardData(text: _contactEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_text(strings, 'emailCopiedMessage', '이메일 주소를 복사했습니다.')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(localizedStringsProvider);

    return BootstrapPage(
      title: _text(strings, 'creatorCreditsTitle', '만든 사람'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: <Widget>[
            _CreditSection(
              icon: Icons.new_releases_outlined,
              title: _text(strings, 'whatsNewTitle', "What's New!"),
              child: Text(
                _text(strings, 'whatsNewPlaceholder', '업데이트 내역을 표시합니다.'),
              ),
            ),
            const SizedBox(height: 16),
            _CreditSection(
              icon: Icons.mark_email_read_outlined,
              title: _text(strings, 'feedbackTitle', '버그 제보 및 건의사항'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _text(
                      strings,
                      'feedbackDescription',
                      '아래 이메일을 누르면 주소가 복사됩니다.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _copyEmail(context, strings),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.copy_rounded, size: 18),
                          SizedBox(width: 8),
                          SelectableText(
                            _contactEmail,
                            style: TextStyle(
                              color: Color(0xFF0D6EFD),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _CreditSection(
              icon: Icons.copyright_rounded,
              title: _text(strings, 'copyrightTitle', '저작권 및 라이선스'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _text(
                      strings,
                      'copyrightNotice',
                      '© 2026 hckang17. All rights reserved.',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _text(
                      strings,
                      'openSourceNotice',
                      '이 앱은 Flutter 및 오픈소스 소프트웨어를 사용합니다. '
                          'PDF 문서의 한글·일본어 표시에 SIL Open Font License 1.1로 '
                          '배포되는 Noto Sans KR/JP를 사용합니다.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: 'Household Ledger',
                      applicationLegalese: _text(
                        strings,
                        'copyrightNotice',
                        '© 2026 hckang17. All rights reserved.',
                      ),
                    ),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: Text(
                      _text(
                        strings,
                        'openSourceLicensesButton',
                        '오픈소스 라이선스 보기',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditSection extends StatelessWidget {
  const _CreditSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: const Color(0xFF0D6EFD), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF486581),
              height: 1.5,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
