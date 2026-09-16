import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// 앱에 포함된 PDF용 CJK 글꼴 한 쌍이다.
class PdfReportFonts {
  const PdfReportFonts({
    required this.japaneseRegular,
    required this.japaneseBold,
    required this.koreanRegular,
    required this.koreanBold,
  });

  final pw.Font japaneseRegular;
  final pw.Font japaneseBold;
  final pw.Font koreanRegular;
  final pw.Font koreanBold;
}

/// 네트워크 없이 PDF용 한글·일본어 글꼴을 앱 자산에서 읽는다.
///
/// 자산이 없거나 손상되면 예외를 그대로 전달한다. CJK 글리프가 없는 기본 글꼴로
/// 조용히 대체하면 깨진 PDF를 성공으로 안내할 수 있기 때문이다.
class PdfReportFontLoader {
  PdfReportFontLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String japaneseRegularAsset =
      'assets/fonts/NotoSansJP-Regular.ttf';
  static const String japaneseBoldAsset = 'assets/fonts/NotoSansJP-Bold.ttf';
  static const String koreanRegularAsset =
      'assets/fonts/NotoSansKR-Regular.ttf';
  static const String koreanBoldAsset = 'assets/fonts/NotoSansKR-Bold.ttf';

  final AssetBundle _bundle;
  Future<PdfReportFonts>? _cached;

  Future<PdfReportFonts> load() => _cached ??= _load();

  Future<PdfReportFonts> _load() async {
    final ByteData japaneseRegularData = await _bundle.load(
      japaneseRegularAsset,
    );
    final ByteData japaneseBoldData = await _bundle.load(japaneseBoldAsset);
    final ByteData koreanRegularData = await _bundle.load(koreanRegularAsset);
    final ByteData koreanBoldData = await _bundle.load(koreanBoldAsset);
    return PdfReportFonts(
      japaneseRegular: pw.Font.ttf(japaneseRegularData),
      japaneseBold: pw.Font.ttf(japaneseBoldData),
      koreanRegular: pw.Font.ttf(koreanRegularData),
      koreanBold: pw.Font.ttf(koreanBoldData),
    );
  }
}
