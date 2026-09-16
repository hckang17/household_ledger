import 'package:flutter/material.dart';

/// 복구가 실패한 경우 원본 복구본을 보존하고 재시도만 허용하는 시작 화면.
class ImportRecoveryPage extends StatefulWidget {
  const ImportRecoveryPage({
    super.key,
    required this.strings,
    required this.retry,
  });
  final Map<String, String> strings;
  final Future<void> Function() retry;
  @override
  State<ImportRecoveryPage> createState() => _ImportRecoveryPageState();
}

class _ImportRecoveryPageState extends State<ImportRecoveryPage> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.strings['importRecoveryMessage']!),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            try {
                              await widget.retry();
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: Text(widget.strings['importRecoveryRetry']!),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
