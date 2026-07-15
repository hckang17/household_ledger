// """ MVVM 계층: Infrastructure Service """
// """ 역할: 화면의 PDF 생성 요청을 기존 렌더러와 파일 조회 기능에 연결 """
// """ 의존 방향: ViewModel 또는 View -> Service -> PDF Renderer """

import 'dart:io';

import 'package:household_ledger/model/reporting/report_generation_request.dart';
import 'package:household_ledger/services/imexporting_file/export_pdf_report_service.dart';

/// UI의 생성 요청과 PDF 렌더러·파일 저장소 사이를 연결한다.
class PdfReportGenerationService {
  PdfReportGenerationService({ExportPdfReportService? renderer})
    : _renderer = renderer ?? ExportPdfReportService();

  final ExportPdfReportService _renderer;

  // """ 생성된 리포트 파일 조회 유스케이스 """
  Future<List<File>> getExistingReports() => _renderer.getExistingReports();

  // """ PDF 생성 유스케이스 """
  Future<String> generate(
    ReportGenerationRequest request, {
    void Function(double progress)? onProgress,
  }) {
    return _renderer.generateReport(
      expenses: request.expenses,
      fixedExpenses: request.fixedExpenses,
      incomes: request.incomes,
      ledger: request.ledger,
      email: request.email,
      options: request.options,
      periodLabel: request.periodLabel,
      strings: request.strings,
      prevExpenses: request.previousExpenses,
      periodStart: request.periodStart,
      prevPeriodStart: request.previousPeriodStart,
      reportTitle: request.reportTitle,
      onProgress: onProgress,
    );
  }
}
