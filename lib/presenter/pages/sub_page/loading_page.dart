// """ MVVM 계층: View / App Flow Page """
// """ 역할: 앱 데이터 로딩과 주기능 화면 워밍업 진행 상태 표시 """

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/pages/expense_page/analysis_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/expense_record_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/fixed_expense_page.dart';
import 'package:household_ledger/presenter/pages/expense_page/income_page.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/router/app_router.dart';

/// 앱 초기 로딩 중 표시되는 화면이다.
///
/// [ledgerProvider]가 데이터 로드를 완료하면 각 탭 페이지를 [Offstage]로 순차
/// 빌드(워밍업)하면서 약 3초 후 홈 화면으로 이동한다.
/// - 단계 0 : DB 로드 중 (0 % → 100 %)
/// - 단계 1–4 : 수입 / 분석 / 지출기록 / 고정지출 화면을 600 ms 간격으로 빌드
class LoadingPage extends ConsumerStatefulWidget {
  /// 로딩 화면을 생성한다.
  const LoadingPage({super.key});

  @override
  ConsumerState<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends ConsumerState<LoadingPage> {
  // ── 메시지 회전 ───────────────────────────────────────────────────────────
  int _msgIndex = 0;
  Timer? _rotateTimer;

  // ── DB 로드 진척도 ────────────────────────────────────────────────────────
  double _progress = 0.0;
  Timer? _progressTimer;

  // ── 탭 워밍업 단계 (0 = 로드 중, 1~4 = 각 탭 빌드 중) ───────────────────
  int _preloadStage = 0;

  // ── 내비게이션 중복 방지 ──────────────────────────────────────────────────
  bool _loadingDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _msgIndex = Random().nextInt(3);

    _rotateTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted || _preloadStage > 0) return; // 워밍업 중엔 고정 메시지 사용
      setState(() {
        int next;
        do {
          next = Random().nextInt(3);
        } while (next == _msgIndex);
        _msgIndex = next;
      });
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted || _loadingDone) return;
      setState(() {
        _progress = (_progress + 0.008).clamp(0.0, 0.9);
      });
    });
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  /// DB 로드 완료 후 탭을 순차 워밍업하며 3 초 뒤 홈으로 이동한다.
  void _scheduleNavigation() {
    if (_loadingDone || _navigated) return;
    _loadingDone = true;

    _progressTimer?.cancel();
    setState(() => _progress = 1.0);

    // 600 ms 간격으로 각 탭 빌드 — 총 2400 ms 워밍업 후 100 ms 여유 뒤 이동
    const gap = Duration(milliseconds: 600);
    for (int stage = 1; stage <= 4; stage++) {
      final int s = stage;
      Future.delayed(gap * s, () {
        if (!mounted || _navigated) return;
        setState(() => _preloadStage = s);
      });
    }

    Future.delayed(const Duration(milliseconds: 3100), () {
      if (!mounted || _navigated) return;
      _navigated = true;
      _rotateTimer?.cancel();
      Navigator.of(context).pushReplacementNamed(AppRouter.homeRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);

    // DB 로드 완료 감지 (상태 변화)
    ref.listen<AsyncValue<dynamic>>(ledgerProvider, (prev, next) {
      if (next.hasValue && !_loadingDone) _scheduleNavigation();
    });

    // 이미 로드 완료 상태인 경우 다음 프레임에서 처리
    if (ref.watch(ledgerProvider).hasValue && !_loadingDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loadingDone) _scheduleNavigation();
      });
    }

    // 단계별 표시 메시지
    final List<String> loadingMessages = <String>[
      strings['loadingIndicatorText1'] ?? '... 화면을 그리고 있어요',
      strings['loadingIndicatorText2'] ?? '... 가계부 기록을 꺼내고 있어요',
      strings['loadingIndicatorText3'] ?? '... 기록을 분석중이에요',
    ];
    final String currentMessage = switch (_preloadStage) {
      1 => strings['loadingWarmup1'] ?? '... 수입 화면 준비중',
      2 => strings['loadingWarmup2'] ?? '... 분석 화면 준비중',
      3 => strings['loadingWarmup3'] ?? '... 지출 화면 준비중',
      4 => strings['loadingWarmup4'] ?? '... 고정지출 화면 준비중',
      _ => loadingMessages[_msgIndex],
    };
    // 워밍업 단계마다 고유 key → AnimatedSwitcher 페이드 트리거
    final Object msgKey = _preloadStage > 0
        ? 'stage_$_preloadStage'
        : _msgIndex;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Stack(
        children: <Widget>[
          // ── 탭 워밍업 : Offstage로 위젯 트리에 포함하되 화면에 표시하지 않음 ──
          if (_preloadStage >= 1) const Offstage(child: IncomePage()),
          if (_preloadStage >= 2) const Offstage(child: AnalysisPage()),
          if (_preloadStage >= 3) const Offstage(child: ExpenseRecordPage()),
          if (_preloadStage >= 4) const Offstage(child: FixedExpensePage()),

          // ── 로딩 UI ────────────────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 32),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Text(
                      currentMessage,
                      key: ValueKey<Object>(msgKey),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF486581),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFDDE5ED),
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(_progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF829AB1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
