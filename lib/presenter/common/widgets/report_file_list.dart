import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

/// 이미 생성된 PDF 리포트 파일 목록을 표시하는 위젯이다.
///
/// 각 항목에서 파일을 열거나 OS 공유 시트를 통해 공유할 수 있다.
class ReportFileList extends StatelessWidget {
  const ReportFileList({
    required this.files,
    required this.isLoading,
    required this.strings,
    super.key,
  });

  final List<File> files;
  final bool isLoading;
  final Map<String, String> strings;

  String _text(String key, [String fallback = '']) =>
      strings[key] ?? fallback;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _text('reportPreviousFiles', '이전에 생성된 리포트'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (files.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _text('reportNoPreviousFiles', '이전에 생성된 파일이 없습니다'),
              style: TextStyle(color: Colors.grey.shade500),
            ),
          )
        else
          ...files.map((File file) {
            final String name =
                file.path.split(Platform.pathSeparator).last;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFDC3545),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  DateFormat('yyyy/MM/dd HH:mm').format(
                    file.lastModifiedSync(),
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      tooltip: _text('reportOpenFile', '열기'),
                      onPressed: () => OpenFile.open(file.path),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, size: 20),
                      tooltip: _text('reportShareFile', '공유'),
                      onPressed: () => Share.shareXFiles([
                        XFile(file.path, mimeType: 'application/pdf'),
                      ]),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
