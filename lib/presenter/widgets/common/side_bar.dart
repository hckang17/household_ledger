// """ MVVM 계층: View / Common Widget """
// """ 역할: 앱 전역 우측 내비게이션 사이드바와 열기 버튼 제공 """

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/tutorial_provider.dart';
import 'package:household_ledger/router/app_router.dart';
import 'package:household_ledger/services/tutorial_service.dart';

/// 현재 화면의 우측 사이드바를 여는 앱바 버튼이다.
class SideBarButton extends ConsumerWidget {
  const SideBarButton({super.key, this.onPressed});

  /// 튜토리얼 등 별도 동작이 필요할 때 기본 Drawer 열기 동작을 대체한다.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, String> strings = ref.watch(localizedStringsProvider);
    return Builder(
      builder: (BuildContext buttonContext) => IconButton(
        onPressed:
            onPressed ?? () => Scaffold.of(buttonContext).openEndDrawer(),
        icon: const Icon(Icons.menu_open_rounded),
        tooltip: strings['sideBarOpen'] ?? '메뉴 열기',
      ),
    );
  }
}

/// Bootstrap 스타일의 앱 전역 우측 내비게이션 Drawer다.
class RightSideBar extends ConsumerWidget {
  const RightSideBar({super.key});

  String _text(Map<String, String> strings, String key, String fallback) =>
      strings[key] ?? fallback;

  void _navigate(BuildContext context, String routeName) {
    final NavigatorState navigator = Navigator.of(context);
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    navigator.pop();
    if (currentRoute != routeName) navigator.pushNamed(routeName);
  }

  void _showComingSoon(BuildContext context, Map<String, String> strings) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_text(strings, 'sideBarComingSoon', '아직 준비 중인 기능입니다.')),
        ),
      );
  }

  Future<void> _restartTutorial(BuildContext context, WidgetRef ref) async {
    final NavigatorState navigator = Navigator.of(context);
    navigator.pop();
    await TutorialService().resetTutorial();
    ref.read(tutorialProvider.notifier).startTutorial();
    navigator.pushNamed(AppRouter.setupRoute);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, String> strings = ref.watch(localizedStringsProvider);
    final double screenWidth = MediaQuery.sizeOf(context).width;

    return Drawer(
      width: screenWidth < 420 ? screenWidth * 0.9 : 380,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
      ),
      child: ColoredBox(
        color: const Color(0xFFF8F9FA),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D6EFD),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(14)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _text(strings, 'sideBarTitle', '빠른 메뉴'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _SideBarTopAction(
                            icon: Icons.person_outline_rounded,
                            label: _text(strings, 'sideBarMyPage', '마이페이지'),
                            status: _text(
                              strings,
                              'sideBarNotImplemented',
                              '미구현',
                            ),
                            onTap: () => _showComingSoon(context, strings),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SideBarTopAction(
                            icon: Icons.notifications_none_rounded,
                            label: _text(strings, 'sideBarNotifications', '알림'),
                            status: _text(
                              strings,
                              'sideBarNotImplemented',
                              '미구현',
                            ),
                            onTap: () => _showComingSoon(context, strings),
                          ),
                        ),
                      ],
                    ),
                    _SideBarSection(
                      title: _text(strings, 'sideBarSettingsGroup', '설정'),
                      children: <Widget>[
                        _SideBarItem(
                          icon: Icons.sell_outlined,
                          label: _text(
                            strings,
                            'sideBarMetadataEdit',
                            '메타데이터 수정',
                          ),
                          onTap: () =>
                              _navigate(context, AppRouter.settingsRoute),
                        ),
                        _SideBarItem(
                          icon: Icons.notifications_active_outlined,
                          label: _text(
                            strings,
                            'sideBarNotificationSettings',
                            '알림 설정',
                          ),
                          onTap: () =>
                              _navigate(context, AppRouter.settingsRoute),
                        ),
                      ],
                    ),
                    _SideBarSection(
                      title: _text(strings, 'sideBarDataGroup', '데이터 관련'),
                      children: <Widget>[
                        _SideBarItem(
                          icon: Icons.manage_search_rounded,
                          label: _text(
                            strings,
                            'sideBarDataManage',
                            '데이터 검색 및 관리',
                          ),
                          onTap: () =>
                              _navigate(context, AppRouter.dataManageRoute),
                        ),
                        _SideBarItem(
                          icon: Icons.upload_file_outlined,
                          label: _text(strings, 'sideBarDataExport', '데이터 출력'),
                          onTap: () =>
                              _navigate(context, AppRouter.exportDataRoute),
                        ),
                        _SideBarItem(
                          icon: Icons.download_outlined,
                          label: _text(strings, 'sideBarDataImport', '데이터 입력'),
                          onTap: () =>
                              _navigate(context, AppRouter.importDataRoute),
                        ),
                      ],
                    ),
                    _SideBarSection(
                      title: _text(strings, 'sideBarReportGroup', '보고서 출력'),
                      children: <Widget>[
                        _SideBarItem(
                          icon: Icons.picture_as_pdf_outlined,
                          label: _text(strings, 'sideBarPdfExport', 'PDF 출력'),
                          onTap: () => _navigate(
                            context,
                            AppRouter.generatingReportRoute,
                          ),
                        ),
                      ],
                    ),
                    _SideBarSection(
                      title: _text(strings, 'sideBarTutorialGroup', '튜토리얼'),
                      children: <Widget>[
                        _SideBarItem(
                          icon: Icons.replay_outlined,
                          label: _text(
                            strings,
                            'tutorialAgainButtonTitle',
                            '튜토리얼 다시보기',
                          ),
                          onTap: () => _restartTutorial(context, ref),
                        ),
                      ],
                    ),
                    _SideBarSection(
                      children: <Widget>[
                        _SideBarItem(
                          icon: Icons.workspace_premium_outlined,
                          label: _text(strings, 'sideBarLicense', '라이선스'),
                          onTap: () =>
                              _navigate(context, AppRouter.copyrightsRoute),
                        ),
                        _SideBarItem(
                          icon: Icons.description_outlined,
                          label: _text(strings, 'sideBarTerms', '이용약관'),
                          trailing: _text(
                            strings,
                            'sideBarNotImplemented',
                            '미구현',
                          ),
                          onTap: () => _showComingSoon(context, strings),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideBarSection extends StatelessWidget {
  const _SideBarSection({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1, color: Color(0xFFDEE2E6)),
        ),
        if (title != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(
              title!,
              style: const TextStyle(
                color: Color(0xFF6C757D),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
        ...children,
      ],
    );
  }
}

class _SideBarItem extends StatelessWidget {
  const _SideBarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDEE2E6)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 21, color: const Color(0xFF0D6EFD)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF212529),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null)
                  _SideBarBadge(label: trailing!)
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFFADB5BD),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideBarTopAction extends StatelessWidget {
  const _SideBarTopAction({
    required this.icon,
    required this.label,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFB6D4FE)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: <Widget>[
              Icon(icon, color: const Color(0xFF0D6EFD), size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF212529),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _SideBarBadge(label: status),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideBarBadge extends StatelessWidget {
  const _SideBarBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6C757D),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
