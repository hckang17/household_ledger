import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/expense_entry.dart';
import 'package:household_ledger/model/fixed_expense.dart';
import 'package:household_ledger/model/income_entry.dart';
import 'package:household_ledger/presenter/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/ledger_provider.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/services/data_im_export_service.dart';

enum _ExportRange { all, month, period }

class ExportDataPage extends ConsumerStatefulWidget {
  const ExportDataPage({super.key});

  @override
  ConsumerState<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends ConsumerState<ExportDataPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passkeyController = TextEditingController();
  final TextEditingController _passkeyConfirmController =
      TextEditingController();

  bool _isExporting = false;
  bool _obscurePasskey = true;
  bool _obscurePasskeyConfirm = true;
  bool _isCooldown = false;
  Timer? _cooldownTimer;

  _ExportRange _exportRange = _ExportRange.all;
  late DateTime _selectedMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  final DataImExportService _service = DataImExportService();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passkeyController.dispose();
    _passkeyConfirmController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String _text(Map<String, String> strings, String tag) {
    return strings[tag] ??
        '${strings['failedReadingData'] ?? 'ErrorCode: 4401'}+$tag';
  }

  String _twoDigit(int n) => n.toString().padLeft(2, '0');

  String _formatDate(DateTime d) =>
      '${d.year}-${_twoDigit(d.month)}-${_twoDigit(d.day)}';

  // 쿨다운 중에는 토스트를 보여주고 실제 내보내기는 막는다.
  void _onExportPressed(Map<String, String> strings) {
    if (_isExporting) return;
    if (_isCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_text(strings, 'exportCooldownMessage')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _doExport(strings);
  }

  Future<void> _doExport(Map<String, String> strings) async {
    final email = _emailController.text.trim();
    final passkey = _passkeyController.text;
    final passkeyConfirm = _passkeyConfirmController.text;

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
    if (passkey != passkeyConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(strings, 'passkeyMismatchError'))),
      );
      return;
    }
    if (_exportRange == _ExportRange.period &&
        (_startDate == null || _endDate == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(strings, 'exportRangeDateRequired'))),
      );
      return;
    }
    if (_exportRange == _ExportRange.period && _startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(strings, 'exportRangeInvalidRange'))),
      );
      return;
    }

    // 쿨다운 시작: 버튼을 3초간 회색으로 표시한다.
    setState(() {
      _isExporting = true;
      _isCooldown = true;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isCooldown = false);
    });

    try {
      final ledger = ref.read(ledgerProvider).asData?.value;
      if (ledger == null) throw Exception('ledger state is null');

      final expenseService = ref.read(expenseDatabaseServiceProvider);
      final fixedService = ref.read(fixedExpenseDatabaseServiceProvider);
      final incomeService = ref.read(incomeDatabaseServiceProvider);

      List<ExpenseEntry> allExpenses;
      List<FixedExpense> allFixed;
      List<IncomeEntry> allIncomes;

      switch (_exportRange) {
        case _ExportRange.all:
          allExpenses = await expenseService.loadAllExpenses();
          allFixed = await fixedService.loadAllFixedExpenses();
          allIncomes = await incomeService.loadAllIncomes();
        case _ExportRange.month:
          allExpenses =
              await expenseService.loadExpensesByMonth(_selectedMonth);
          allFixed = await fixedService.loadFixedExpensesByMonth(_selectedMonth);
          allIncomes = await incomeService.loadIncomesByMonth(_selectedMonth);
        case _ExportRange.period:
          final endExclusive = DateTime(
            _endDate!.year,
            _endDate!.month,
            _endDate!.day + 1,
          );
          allExpenses = await expenseService.loadExpensesByRange(
            start: _startDate!,
            endExclusive: endExclusive,
          );
          allFixed = await fixedService.loadFixedExpensesByRange(
            start: _startDate!,
            endExclusive: endExclusive,
          );
          allIncomes = await incomeService.loadIncomesByRange(
            start: _startDate!,
            endExclusive: endExclusive,
          );
      }

      final now = DateTime.now();
      final timestamp =
          '${now.year}${_twoDigit(now.month)}${_twoDigit(now.day)}'
          '_${_twoDigit(now.hour)}${_twoDigit(now.minute)}${_twoDigit(now.second)}';

      final savedPath = await _service.exportData(
        expenses: allExpenses,
        fixedExpenses: allFixed,
        incomes: allIncomes,
        ledgerState: ledger,
        email: email,
        passkey: passkey,
        timestamp: timestamp,
      );

      if (!mounted) return;
      setState(() => _isExporting = false);
      await _showSaveSuccessDialog(strings, savedPath);
    } on UnsupportedError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web export is not supported.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text(strings, 'exportFailedMessage'))),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showSaveSuccessDialog(
    Map<String, String> strings,
    String savedPath,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: <Widget>[
              const Icon(Icons.check_circle, color: Color(0xFF28A745)),
              const SizedBox(width: 8),
              Flexible(child: Text(_text(strings, 'exportSuccessMessage'))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _text(strings, 'savedPathLabel'),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: savedPath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(_text(strings, 'pathCopiedMessage'))),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          savedPath,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                      const Icon(Icons.copy, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _service.shareFile(savedPath);
              },
              icon: const Icon(Icons.share_outlined),
              label: Text(_text(strings, 'shareFileLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_text(strings, 'save')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    final now = DateTime.now();
    final years =
        List<int>.generate(now.year - 2020 + 1, (i) => 2020 + i).reversed.toList();

    return Stack(
      children: <Widget>[
        BootstrapPage(
          title: _text(strings, 'exportDataPageTitle'),
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                // ── 추출 범위 섹션 ─────────────────────────
                BootstrapSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _text(strings, 'exportRangeSectionTitle'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildRangeSegment(strings),
                      if (_exportRange == _ExportRange.month) ...<Widget>[
                        const SizedBox(height: 16),
                        _buildMonthSelector(strings, years),
                      ],
                      if (_exportRange == _ExportRange.period) ...<Widget>[
                        const SizedBox(height: 16),
                        _buildPeriodSelector(strings),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── 서명 섹션 ──────────────────────────────
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
                            onPressed: () => setState(
                                () => _obscurePasskey = !_obscurePasskey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passkeyConfirmController,
                        obscureText: _obscurePasskeyConfirm,
                        decoration: InputDecoration(
                          labelText: _text(strings, 'passkeyConfirmLabel'),
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePasskeyConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePasskeyConfirm =
                                  !_obscurePasskeyConfirm,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                BootstrapActionButton(
                  label: _text(strings, 'exportButton'),
                  icon: Icons.upload_file_outlined,
                  backgroundColor: (_isExporting || _isCooldown)
                      ? Colors.grey.shade400
                      : const Color(0xFF0D6EFD),
                  onPressed:
                      _isExporting ? null : () => _onExportPressed(strings),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (_isExporting) _buildProgressOverlay(strings),
      ],
    );
  }

  Widget _buildRangeSegment(Map<String, String> strings) {
    return SegmentedButton<_ExportRange>(
      segments: <ButtonSegment<_ExportRange>>[
        ButtonSegment(
          value: _ExportRange.all,
          label: Text(_text(strings, 'exportRangeAll')),
        ),
        ButtonSegment(
          value: _ExportRange.month,
          label: Text(_text(strings, 'exportRangeMonth')),
        ),
        ButtonSegment(
          value: _ExportRange.period,
          label: Text(_text(strings, 'exportRangePeriod')),
        ),
      ],
      selected: <_ExportRange>{_exportRange},
      onSelectionChanged: (Set<_ExportRange> s) =>
          setState(() => _exportRange = s.first),
      showSelectedIcon: false,
    );
  }

  Widget _buildMonthSelector(
      Map<String, String> strings, List<int> years) {
    return Row(
      children: <Widget>[
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: _text(strings, 'yearLabel'),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonth.year,
                isDense: true,
                items: years
                    .map((y) =>
                        DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (y) {
                  if (y == null) return;
                  setState(() =>
                      _selectedMonth = DateTime(y, _selectedMonth.month));
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: _text(strings, 'monthLabel'),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedMonth.month,
                isDense: true,
                items: List<int>.generate(12, (i) => i + 1)
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(_twoDigit(m))))
                    .toList(),
                onChanged: (m) {
                  if (m == null) return;
                  setState(() =>
                      _selectedMonth = DateTime(_selectedMonth.year, m));
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(Map<String, String> strings) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _pickDate(
              context: context,
              initial: _startDate,
              onPicked: (d) => setState(() => _startDate = d),
            ),
            child: Text(
              _startDate != null
                  ? _formatDate(_startDate!)
                  : _text(strings, 'exportRangeStartDateLabel'),
              style: TextStyle(
                  color: _startDate != null ? null : Colors.grey[500]),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward, size: 18, color: Colors.grey),
        ),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _pickDate(
              context: context,
              initial: _endDate,
              onPicked: (d) => setState(() => _endDate = d),
            ),
            child: Text(
              _endDate != null
                  ? _formatDate(_endDate!)
                  : _text(strings, 'exportRangeEndDateLabel'),
              style: TextStyle(
                  color: _endDate != null ? null : Colors.grey[500]),
            ),
          ),
        ),
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
                  _text(strings, 'exportingMessage'),
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
