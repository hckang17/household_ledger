import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:household_ledger/model/app_settings.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/ledger_state.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/reporting/report_options.dart';
import 'package:household_ledger/model/user_profile.dart';
import 'package:household_ledger/services/imexporting_file/export_pdf_report_service.dart';
import 'package:household_ledger/services/imexporting_file/pdf_report_fonts.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled CJK fonts render Korean and Japanese without network',
    () async {
      final fonts = await PdfReportFontLoader().load();
      final document = pw.Document()
        ..addPage(
          pw.Page(
            build: (_) => pw.Column(
              children: <pw.Widget>[
                pw.Text(
                  '家計簿 日本語',
                  style: pw.TextStyle(font: fonts.japaneseRegular),
                ),
                pw.Text('가계부 한국어', style: pw.TextStyle(font: fonts.koreanBold)),
              ],
            ),
          ),
        );

      final bytes = await document.save();
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
  );

  test(
    'Korean and Japanese reports use bundled fonts and matching percentages',
    () async {
      final output = Directory('tmp/pdfs');
      if (await output.exists()) await output.delete(recursive: true);
      await output.create(recursive: true);
      final strings = Map<String, String>.from(
        jsonDecode(File('assets/language_data/jp.json').readAsStringSync())
            as Map,
      );
      final expenses = <ExpenseEntry>[
        ExpenseEntry.create(
          id: 'hotel',
          spentAt: DateTime(2026, 9, 5),
          categoryCode: 'A',
          description: 'ホテル',
          amount: 40000,
        ),
        ExpenseEntry.create(
          id: 'meal',
          spentAt: DateTime(2026, 9, 6),
          categoryCode: 'F',
          description: '夕食',
          amount: 12000,
        ),
      ];
      final fixedExpenses = <FixedExpense>[
        FixedExpense.create(
          id: 'rent',
          appliedAt: DateTime(2026, 9),
          categoryCode: 'L',
          description: '家賃',
          amount: 800000,
        ),
      ];
      final ledger = LedgerState(
        settings: const AppSettings(
          localeCode: 'jp',
          currencyUnit: '¥',
          monthlyBudget: 0,
          onboardingCompleted: true,
        ),
        userProfile: const UserProfile(name: 'ベータ利用者', age: 30),
        metadataTags: const <MetadataTag>[
          MetadataTag(type: MetadataTagType.category, code: 'A', label: '宿泊費'),
          MetadataTag(type: MetadataTagType.category, code: 'F', label: '外食費'),
          MetadataTag(
            type: MetadataTagType.paymentMethod,
            code: '_s',
            label: 'カード',
          ),
        ],
        expenses: expenses,
        fixedExpenses: fixedExpenses,
      );
      final service = ExportPdfReportService(
        reportDirectoryProvider: () async => output,
      );

      final path = await service.generateReport(
        expenses: expenses,
        fixedExpenses: fixedExpenses,
        incomes: const [],
        ledger: ledger,
        email: 'beta@example.com',
        options: const ReportOptions(
          includeDetailedData: false,
          includeTop10: false,
          includePaymentSummary: false,
        ),
        periodLabel: '2026-09',
        strings: strings,
        periodStart: DateTime(2026, 9),
        reportTitle: '家計簿レポート',
      );

      final file = File(path);
      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(10000));
      final secondPath = await service.generateReport(
        expenses: expenses,
        fixedExpenses: fixedExpenses,
        incomes: const [],
        ledger: ledger,
        email: 'beta@example.com',
        options: const ReportOptions(
          includeDetailedData: false,
          includeTop10: false,
          includePaymentSummary: false,
        ),
        periodLabel: '2026-09',
        strings: strings,
        periodStart: DateTime(2026, 9),
        reportTitle: '家計簿レポート',
      );
      expect(secondPath, isNot(path));
      expect(await file.exists(), isTrue);

      final koreanStrings = Map<String, String>.from(
        jsonDecode(File('assets/language_data/ko.json').readAsStringSync())
            as Map,
      );
      final koreanLedger = LedgerState(
        settings: const AppSettings(
          localeCode: 'ko',
          currencyUnit: '₩',
          monthlyBudget: 0,
          onboardingCompleted: true,
        ),
        userProfile: const UserProfile(name: '베타 사용자', age: 30),
        metadataTags: const <MetadataTag>[
          MetadataTag(type: MetadataTagType.category, code: 'A', label: '숙박비'),
          MetadataTag(type: MetadataTagType.category, code: 'F', label: '외식비'),
          MetadataTag(
            type: MetadataTagType.paymentMethod,
            code: '_s',
            label: '카드',
          ),
        ],
        expenses: expenses,
        fixedExpenses: fixedExpenses,
      );
      final koreanPath = await service.generateReport(
        expenses: expenses,
        fixedExpenses: fixedExpenses,
        incomes: const [],
        ledger: koreanLedger,
        email: 'beta@example.com',
        options: const ReportOptions(
          includeDetailedData: false,
          includeTop10: false,
          includePaymentSummary: false,
        ),
        periodLabel: '2026-09-ko',
        strings: koreanStrings,
        periodStart: DateTime(2026, 9),
        reportTitle: '가계부 리포트',
      );
      expect(await File(koreanPath).length(), greaterThan(10000));

      final beforeFailure = <String, int>{
        for (final file in output.listSync().whereType<File>())
          file.path: file.lengthSync(),
      };
      final failingService = ExportPdfReportService(
        reportDirectoryProvider: () async => output,
        temporaryFileWriter: (_, _) async {
          throw const FileSystemException('injected write failure');
        },
      );
      await expectLater(
        failingService.generateReport(
          expenses: expenses,
          fixedExpenses: fixedExpenses,
          incomes: const [],
          ledger: ledger,
          email: 'beta@example.com',
          options: const ReportOptions(
            includeDetailedData: false,
            includeTop10: false,
            includePaymentSummary: false,
          ),
          periodLabel: '2026-09',
          strings: strings,
          periodStart: DateTime(2026, 9),
          reportTitle: '家計簿レポート',
        ),
        throwsA(isA<FileSystemException>()),
      );
      final afterFailure = <String, int>{
        for (final file in output.listSync().whereType<File>())
          file.path: file.lengthSync(),
      };
      expect(afterFailure, beforeFailure);
      expect(
        output.listSync().whereType<File>().any((f) => f.path.endsWith('.tmp')),
        isFalse,
      );
    },
  );
}
