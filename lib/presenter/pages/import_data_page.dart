// .csv파일을 입력받아 가계부 데이터와 동기화하는 페이지입니다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/presenter/common/widgets/ledger_dialogs.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/main.dart';
import 'package:household_ledger/services/data_im_export_service.dart';

/// CSV 파일을 선택해 가계부 데이터를 복원하는 화면이다.
class ImportDataPage extends ConsumerStatefulWidget {
  /// 데이터 가져오기 화면을 생성한다.
  ///
  /// [fromSetup]이 true이면 초기 설정 화면에서 진입한 것이므로,
  /// 가져오기 성공 시 홈 화면으로 스택을 초기화하며 이동한다.
  const ImportDataPage({super.key, this.fromSetup = false});

  /// 초기 설정 화면에서 진입했는지 여부를 나타낸다.
  final bool fromSetup;

  @override
  ConsumerState<ImportDataPage> createState() => _ImportDataPageState();
}

class _ImportDataPageState extends ConsumerState<ImportDataPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passkeyController = TextEditingController();
  bool _isImporting = false;
  bool _obscurePasskey = true;
  String? _selectedFilePath;

  final DataImExportService _service = DataImExportService();

  String _text(Map<String, String> strings, String tag) {
    return strings[tag] ??
        '${strings['failedReadingData'] ?? 'ErrorCode: 4401'}+$tag';
  }

  Future<void> _pickFile() async {
    final path = await _service.pickImportFile();
    if (path == null) {
      return;
    }
    setState(() => _selectedFilePath = path);
  }

  Future<void> _doImport(Map<String, String> strings) async {
    final email = _emailController.text.trim();
    final passkey = _passkeyController.text;
    final filePath = _selectedFilePath;

    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(strings, 'noFileSelectedMessage'))),
      );
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(strings, 'emailFormatError'))),
      );
      return;
    }
    if (passkey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(strings, 'passkeyLabel'))),
      );
      return;
    }

    final confirmed = await showLedgerConfirmDialog(
      context: context,
      title: _text(strings, 'importConfirmTitle'),
      message: _text(strings, 'importConfirmMessage'),
      confirmLabel: _text(strings, 'importButton'),
      cancelLabel: _text(strings, 'cancel'),
    );
    if (!confirmed) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() => _isImporting = true);

    try {
      final csvContent = await File(filePath).readAsString();
      final result = _service.importFromCsv(
        csvContent: csvContent,
        email: email,
        passkey: passkey,
      );

      if (!result.success) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text(strings, result.errorKey ?? 'importFailedMessage'),
            ),
          ),
        );
        return;
      }

      await ref.read(ledgerProvider.notifier).importAllData(
        expenses: result.expenses,
        fixedExpenses: result.fixedExpenses,
        incomes: result.incomes,
        importedState: result.ledgerState!,
      );

      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF198754),
              size: 40,
            ),
            title: Text(_text(strings, 'importSuccessMessage')),
            content: Text(_text(strings, 'importRestartMessage')),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(_text(strings, 'confirmOk')),
              ),
            ],
          );
        },
      );
      if (mounted) {
        AppRestartWidget.restartApp(context);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(strings, 'importFailedMessage'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passkeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final fileName = _selectedFilePath?.split(Platform.pathSeparator).last;

    return Stack(
      children: <Widget>[
        BootstrapPage(
          title: _text(strings, 'importDataPageTitle'),
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                BootstrapSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _text(strings, 'signatureInfoMessage'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isImporting ? null : _pickFile,
                          icon: const Icon(Icons.folder_open_outlined),
                          label: Text(_text(strings, 'selectFileButton')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      if (fileName != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FFF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF28A745)),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF28A745),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fileName,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: const Color(0xFF28A745)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          _text(strings, 'noFileSelectedMessage'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: _text(strings, 'emailLabel'),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passkeyController,
                        obscureText: _obscurePasskey,
                        decoration: InputDecoration(
                          labelText: _text(strings, 'passkeyLabel'),
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePasskey
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePasskey = !_obscurePasskey,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                BootstrapActionButton(
                  label: _text(strings, 'importButton'),
                  icon: Icons.download_outlined,
                  backgroundColor: const Color(0xFF198754),
                  onPressed: _isImporting ? null : () => _doImport(strings),
                ),
              ],
            ),
          ),
        ),
        if (_isImporting) _buildProgressOverlay(strings),
      ],
    );
  }

  Widget _buildProgressOverlay(Map<String, String> strings) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: BootstrapSectionCard(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _text(strings, 'keepAppOpenMessage'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _text(strings, 'importingMessage'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
