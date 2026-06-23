import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// [RepaintBoundary]로 감싼 위젯을 PNG 이미지로 캡처하거나 공유하는 서비스다.
///
/// 사용 예:
/// ```dart
/// final GlobalKey repaintKey = GlobalKey();
/// // 위젯에 RepaintBoundary(key: repaintKey, child: ...) 적용 후:
/// await GeneratingPngService.captureAndShare(repaintKey, filename: 'receipt.png');
/// ```
class GeneratingPngService {
  const GeneratingPngService._();

  // ── 캡처 ─────────────────────────────────────────────────────────────────

  /// [RepaintBoundary]로 감싼 위젯을 PNG 바이트로 캡처한다.
  ///
  /// [repaintKey] : RepaintBoundary에 부착한 GlobalKey.
  /// [pixelRatio] : 출력 해상도 배율. 기본값 3.0은 Retina급 고해상도를 보장한다.
  ///
  /// 캡처에 실패하면 null 을 반환한다.
  static Future<Uint8List?> captureWidget(
    GlobalKey repaintKey, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final RenderObject? renderObject = repaintKey.currentContext
          ?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;

      final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ── 공유 ─────────────────────────────────────────────────────────────────

  /// PNG 바이트를 임시 파일로 저장한 뒤 시스템 공유 시트를 연다.
  ///
  /// [bytes]    : [captureWidget]이 반환한 PNG 바이트.
  /// [filename] : 임시 파일명 (예: 'receipt.png').
  /// [subject]  : 공유 시 표시될 제목 (선택).
  static Future<void> shareAsImage(
    Uint8List bytes, {
    required String filename,
    String? subject,
  }) async {
    final File? file = await saveTempFile(bytes, filename: filename);
    if (file == null) return;
    await Share.shareXFiles(<XFile>[
      XFile(file.path, mimeType: 'image/png'),
    ], subject: subject);
  }

  /// 위젯 캡처부터 공유까지 한 번에 처리하는 편의 메서드다.
  ///
  /// 내부적으로 [captureWidget] → [shareAsImage] 를 순서대로 호출한다.
  /// 캡처에 실패하면 아무 동작도 하지 않는다.
  static Future<void> captureAndShare(
    GlobalKey repaintKey, {
    required String filename,
    double pixelRatio = 3.0,
    String? subject,
  }) async {
    final Uint8List? bytes = await captureWidget(
      repaintKey,
      pixelRatio: pixelRatio,
    );
    if (bytes == null) return;
    await shareAsImage(bytes, filename: filename, subject: subject);
  }

  // ── 파일 저장 ────────────────────────────────────────────────────────────

  /// PNG 바이트를 앱 임시 디렉토리에 저장하고 [File] 객체를 반환한다.
  ///
  /// PDF 생성 등 이미지 파일 자체가 필요한 경우에 사용한다.
  /// 저장에 실패하면 null 을 반환한다.
  static Future<File?> saveTempFile(
    Uint8List bytes, {
    required String filename,
  }) async {
    try {
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }
}
