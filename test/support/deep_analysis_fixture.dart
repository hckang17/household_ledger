import 'package:household_ledger/features/analysis/models/deep_analysis_report.dart';

final deepAnalysisPreview = DeepAnalysisReport(
  month: DateTime(2026, 9),
  total: 1480000,
  fixedTotal: 420000,
  fixedShare: 28.4,
  topShare: 27.7,
  withoutTop: 1070000,
  isDemo: true,
  baselines: const [
    DeepAnalysisBaseline(
      months: 1,
      average: 1360000,
      difference: 120000,
      fixedAverage: 400000,
      changes: [
        DeepAnalysisItem(labelKey: 'deepHousehold', amount: 90000),
        DeepAnalysisItem(labelKey: 'deepFood', amount: 60000),
        DeepAnalysisItem(labelKey: 'deepFixed', amount: 20000),
        DeepAnalysisItem(labelKey: 'deepTransport', amount: -50000),
      ],
    ),
    DeepAnalysisBaseline(
      months: 3,
      average: 1320000,
      difference: 160000,
      fixedAverage: 400000,
      changes: [
        DeepAnalysisItem(labelKey: 'deepHousehold', amount: 110000),
        DeepAnalysisItem(labelKey: 'deepFood', amount: 70000),
        DeepAnalysisItem(labelKey: 'deepFixed', amount: 20000),
        DeepAnalysisItem(labelKey: 'deepTransport', amount: -40000),
      ],
    ),
    DeepAnalysisBaseline(
      months: 6,
      average: 1290000,
      difference: 190000,
      fixedAverage: 390000,
      changes: [
        DeepAnalysisItem(labelKey: 'deepHousehold', amount: 130000),
        DeepAnalysisItem(labelKey: 'deepFood', amount: 70000),
        DeepAnalysisItem(labelKey: 'deepFixed', amount: 30000),
        DeepAnalysisItem(labelKey: 'deepTransport', amount: -40000),
      ],
    ),
    DeepAnalysisBaseline(months: 12),
  ],
  trend: [
    DeepAnalysisMonth(DateTime(2026, 3), 1180000),
    DeepAnalysisMonth(DateTime(2026, 4), 1280000),
    DeepAnalysisMonth(DateTime(2026, 5), 1320000),
    DeepAnalysisMonth(DateTime(2026, 6), 1260000),
    DeepAnalysisMonth(DateTime(2026, 7), 1340000),
    DeepAnalysisMonth(DateTime(2026, 8), 1360000),
    DeepAnalysisMonth(DateTime(2026, 9), 1480000),
  ],
  largeExpenses: [
    DeepAnalysisItem(
      label: 'IKEA',
      amount: 180000,
      date: DateTime(2026, 9, 12),
    ),
    DeepAnalysisItem(
      label: 'COSTCO',
      amount: 135000,
      date: DateTime(2026, 9, 19),
    ),
    DeepAnalysisItem(
      label: 'UNIQLO',
      amount: 95000,
      date: DateTime(2026, 9, 24),
    ),
  ],
  fixedBreakdown: const [
    DeepAnalysisItem(labelKey: 'deepHousing', amount: 300000, share: 71.4),
    DeepAnalysisItem(labelKey: 'deepTelecom', amount: 70000, share: 16.7),
    DeepAnalysisItem(labelKey: 'deepSubscription', amount: 50000, share: 11.9),
  ],
);
