import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_ledger/model/trip.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';
import 'package:household_ledger/provider/localization_provider.dart';
import 'package:household_ledger/provider/travel_provider.dart';

/// 여행 메타데이터를 생성하거나 수정하는 화면이다.
class TravelEditorPage extends ConsumerStatefulWidget {
  const TravelEditorPage({super.key, this.trip});

  final Trip? trip;

  @override
  ConsumerState<TravelEditorPage> createState() => _TravelEditorPageState();
}

class _TravelEditorPageState extends ConsumerState<TravelEditorPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  late final TextEditingController _noteController;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    final today = DateTime.now();
    _nameController = TextEditingController(text: trip?.name ?? '');
    _budgetController = TextEditingController(
      text: trip?.budget?.toString() ?? '',
    );
    _noteController = TextEditingController(text: trip?.note ?? '');
    _startDate =
        trip?.startDate ?? DateTime(today.year, today.month, today.day);
    _endDate = trip?.endDate ?? _startDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save(Map<String, String> strings) async {
    final name = _nameController.text.trim();
    final budgetText = _budgetController.text.trim();
    final budget = budgetText.isEmpty ? null : int.tryParse(budgetText);
    if (name.isEmpty ||
        (budgetText.isNotEmpty && budget == null) ||
        _endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings['travelValidationMessage'] ?? '여행 이름, 기간과 예산을 올바르게 입력해주세요.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final existing = widget.trip;
    final trip = existing == null
        ? Trip.create(
            name: name,
            startDate: _startDate,
            endDate: _endDate,
            budget: budget,
            note: _noteController.text,
          )
        : existing.copyWith(
            name: name,
            startDate: _startDate,
            endDate: _endDate,
            budget: budget,
            clearBudget: budget == null,
            note: _noteController.text,
          );
    await ref.read(travelProvider.notifier).saveTrip(trip);
    if (mounted) Navigator.of(context).pop(trip.id);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(localizedStringsProvider);
    return BootstrapPage(
      title: widget.trip == null
          ? (strings['travelAddTitle'] ?? '새 여행')
          : (strings['travelEditTitle'] ?? '여행정보 수정'),
      showSideBar: false,
      child: SingleChildScrollView(
        child: BootstrapSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _nameController,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: strings['travelNameLabel'] ?? '여행 이름',
                  prefixIcon: const Icon(Icons.luggage_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DateField(
                      label: strings['travelStartDateLabel'] ?? '시작일',
                      date: _startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      label: strings['travelEndDateLabel'] ?? '종료일',
                      date: _endDate,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings['travelBudgetLabel'] ?? '여행 예산 (선택)',
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: strings['travelNoteLabel'] ?? '메모',
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 20),
              BootstrapActionButton(
                label: strings['save'] ?? '저장',
                icon: Icons.save_outlined,
                onPressed: _saving ? null : () => _save(strings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(_dateText(date)),
      ),
    );
  }
}

String _dateText(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
