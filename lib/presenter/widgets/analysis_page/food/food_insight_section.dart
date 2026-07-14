// """ 계층: Presentation / Feature View Composer """
// """ 역할: 음식 분석 결과를 개별 카드에 전달하고 화면 표시 순서를 구성 """
// """ 주의: 수치 집계는 하지 않으며 비교 결과를 현지화 문장으로 변환 """

import 'package:flutter/material.dart';
import 'package:household_ledger/features/analysis/models/food_analysis_result.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/food/dining_detail_card.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/food/dining_overview_card.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/food/engel_index_card.dart';
import 'package:household_ledger/presenter/widgets/analysis_page/food/visit_frequency_card.dart';
import 'package:household_ledger/model/metadata_tag.dart';

// """ 음식 분석 카드 묶음의 진입 위젯 """
class FoodInsightSection extends StatelessWidget {
  const FoodInsightSection({
    required this.result,
    required this.diningOccasionTags,
    required this.strings,
    required this.currency,
    required this.onAddExpense,
    super.key,
  });

  final FoodAnalysisResult result;
  final List<MetadataTag> diningOccasionTags;
  final Map<String, String> strings;
  final String currency;
  final VoidCallback onAddExpense;

  String _text(String key, String fallback) => strings[key] ?? fallback;

  // """ 빈도 비교 결과의 현지화 """
  String _frequencyComparison(VisitAnalysisResult visit) {
    final current = visit.dailyAverage;
    final previous = visit.previousDailyAverage;
    if (previous == 0) {
      return _text('analysisNoPreviousFrequency', '전월동기 비교 데이터가 없습니다.');
    }
    final key = switch (visit.dailyComparison.direction) {
      AnalysisComparisonDirection.similar => 'analysisFrequencySimilar',
      AnalysisComparisonDirection.increase => 'analysisFrequencyMore',
      AnalysisComparisonDirection.decrease => 'analysisFrequencyLess',
      AnalysisComparisonDirection.unavailable => 'analysisNoPreviousFrequency',
    };
    final fallback = switch (visit.dailyComparison.direction) {
      AnalysisComparisonDirection.similar =>
        '전월동기 하루평균 {previous}회와 비슷한 수준이에요.',
      AnalysisComparisonDirection.increase =>
        '전월동기 하루평균 {previous}회보다 {difference}회 더 많아요!',
      AnalysisComparisonDirection.decrease =>
        '전월동기 하루평균 {previous}회보다 {difference}회 더 적어요!',
      AnalysisComparisonDirection.unavailable => '전월동기 비교 데이터가 없습니다.',
    };
    return _text(key, fallback)
        .replaceAll('{previous}', previous.toStringAsFixed(2))
        .replaceAll(
          '{difference}',
          (current - previous).abs().toStringAsFixed(2),
        );
  }

  // """ 횟수 비교 결과의 현지화 """
  String _countComparison(AnalysisMetricComparison comparison) {
    if (comparison.previous == 0) {
      return _text('analysisNoPreviousCount', '전월동기 비교 데이터가 없습니다.');
    }
    final key = switch (comparison.direction) {
      AnalysisComparisonDirection.similar => 'analysisCountSimilar',
      AnalysisComparisonDirection.increase => 'analysisCountMore',
      AnalysisComparisonDirection.decrease => 'analysisCountLess',
      AnalysisComparisonDirection.unavailable => 'analysisNoPreviousCount',
    };
    final fallback = switch (comparison.direction) {
      AnalysisComparisonDirection.similar => '전월동기 {previous}회와 같은 수준이에요.',
      AnalysisComparisonDirection.increase =>
        '전월동기 {previous}회보다 {difference}회 늘었어요!',
      AnalysisComparisonDirection.decrease =>
        '전월동기 {previous}회보다 {difference}회 줄었어요!',
      AnalysisComparisonDirection.unavailable => '전월동기 비교 데이터가 없습니다.',
    };
    return _text(key, fallback)
        .replaceAll('{previous}', '${comparison.previous.round()}')
        .replaceAll('{difference}', '${comparison.difference.abs().round()}');
  }

  @override
  Widget build(BuildContext context) {
    final occasions = result.diningOccasions;

    return Column(
      children: <Widget>[
        EngelIndexCard(
          engelIndex: result.engelIndex,
          hasCurrentData: result.hasFoodData,
          strings: strings,
          onAddExpense: onAddExpense,
        ),
        const SizedBox(height: 16),
        DiningOverviewCard(
          result: result.dining,
          comparisonText: _frequencyComparison(result.dining),
          strings: strings,
          currency: currency,
          onAddExpense: onAddExpense,
        ),
        const SizedBox(height: 16),
        DiningDetailCard(
          dining: result.dining,
          occasions: occasions,
          companyDining: result.companyDining,
          tags: diningOccasionTags,
          peakComparisonText: _countComparison(occasions.peakComparison),
          companyComparisonText: _countComparison(
            result.companyDining.countComparison,
          ),
          strings: strings,
          currency: currency,
          onAddExpense: onAddExpense,
        ),
        const SizedBox(height: 16),
        VisitFrequencyCard(
          icon: Icons.local_cafe_rounded,
          title: _text('analysisCafeVisitTitle', '카페 방문횟수'),
          result: result.cafe,
          dailyLabel: _text('analysisDailyVisitLabel', '하루평균 카페 방문'),
          averageLabel: _text('analysisAverageSpendLabel', '1회 평균 금액'),
          comparisonText: _frequencyComparison(result.cafe),
          currentLabel: _text('analysisCurrentPeriod', '현재'),
          previousLabel: _text('analysisPreviousPeriod', '전월동기'),
          valueSuffix: _text('analysisTimesPerDayUnit', '회/일'),
          currency: currency,
          color: const Color(0xFF795548),
          emptyText: _text(
            'analysisNoCurrentComparisonData',
            '비교할 데이터가 존재하지 않습니다. 데이터를 입력하러 갈까요?',
          ),
          addButtonLabel: _text('analysisAddExpenseAction', '소비내역 입력하기'),
          onAddExpense: onAddExpense,
        ),
        const SizedBox(height: 16),
        VisitFrequencyCard(
          icon: Icons.shopping_cart_rounded,
          title: _text('analysisGroceryVisitTitle', '장보기 횟수'),
          result: result.grocery,
          dailyLabel: _text('analysisDailyGroceryLabel', '하루평균 장보기'),
          averageLabel: _text('analysisAverageSpendLabel', '1회 평균 금액'),
          comparisonText: _frequencyComparison(result.grocery),
          currentLabel: _text('analysisCurrentPeriod', '현재'),
          previousLabel: _text('analysisPreviousPeriod', '전월동기'),
          valueSuffix: _text('analysisTimesPerDayUnit', '회/일'),
          currency: currency,
          color: const Color(0xFF198754),
          emptyText: _text(
            'analysisNoCurrentComparisonData',
            '비교할 데이터가 존재하지 않습니다. 데이터를 입력하러 갈까요?',
          ),
          addButtonLabel: _text('analysisAddExpenseAction', '소비내역 입력하기'),
          onAddExpense: onAddExpense,
        ),
      ],
    );
  }
}
