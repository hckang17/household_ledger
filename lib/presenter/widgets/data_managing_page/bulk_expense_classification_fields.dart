import 'package:flutter/material.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/model/trip.dart';

/// 소비 소구분과 여행 연결의 일괄 변경 선택값이다.
class BulkExpenseClassificationChange {
  const BulkExpenseClassificationChange({
    this.subcategoryCode,
    this.changeTripId = false,
    this.tripId,
  });

  final String? subcategoryCode;
  final bool changeTripId;
  final String? tripId;

  bool get hasChanges => subcategoryCode != null || changeTripId;
}

/// 데이터 관리의 소비 소구분·여행 연결 일괄 변경 필드를 표시한다.
class BulkExpenseClassificationFields extends StatefulWidget {
  const BulkExpenseClassificationFields({
    required this.subcategoryTags,
    required this.trips,
    required this.strings,
    required this.onChanged,
    super.key,
    this.activeTripId,
  });

  final List<MetadataTag> subcategoryTags;
  final List<Trip> trips;
  final String? activeTripId;
  final Map<String, String> strings;
  final ValueChanged<BulkExpenseClassificationChange> onChanged;

  @override
  State<BulkExpenseClassificationFields> createState() =>
      _BulkExpenseClassificationFieldsState();
}

class _BulkExpenseClassificationFieldsState
    extends State<BulkExpenseClassificationFields> {
  static const String _tripNoChange = '__trip_no_change__';
  static const String _tripUnassigned = '__trip_unassigned__';

  String? _subcategoryCode;
  String _tripChoice = _tripNoChange;

  String _text(String key, String fallback) => widget.strings[key] ?? fallback;

  void _notifyChanged() {
    widget.onChanged(
      BulkExpenseClassificationChange(
        subcategoryCode: _subcategoryCode,
        changeTripId: _tripChoice != _tripNoChange,
        tripId: _tripChoice == _tripNoChange || _tripChoice == _tripUnassigned
            ? null
            : _tripChoice,
      ),
    );
  }

  String _defaultTripChoice() {
    final activeTripId = widget.activeTripId;
    if (activeTripId != null &&
        widget.trips.any(
          (Trip trip) => trip.id == activeTripId && !trip.isArchived,
        )) {
      return activeTripId;
    }
    for (final trip in widget.trips) {
      if (!trip.isArchived) return trip.id;
    }
    return _tripUnassigned;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DropdownButtonFormField<String>(
          key: ValueKey<String?>('bulk_subcategory_$_subcategoryCode'),
          initialValue: _subcategoryCode,
          decoration: InputDecoration(
            labelText: _text('subcategoryLabel', '소비 소구분'),
          ),
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              value: null,
              child: Text(_text('dataManageNoChange', '변경 안함')),
            ),
            ...widget.subcategoryTags.map(
              (MetadataTag tag) => DropdownMenuItem<String>(
                value: tag.code,
                child: Text(tag.label),
              ),
            ),
          ],
          onChanged: (String? value) {
            setState(() {
              _subcategoryCode = value;
              if (value == 't' && _tripChoice == _tripNoChange) {
                _tripChoice = _defaultTripChoice();
              } else if (value != null && value != 't') {
                _tripChoice = _tripNoChange;
              }
            });
            _notifyChanged();
          },
        ),
        if (_subcategoryCode == null || _subcategoryCode == 't') ...<Widget>[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('bulk_trip_$_tripChoice'),
            initialValue: _tripChoice,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _text('dataManageTripChangeLabel', '여행 연결'),
            ),
            items: <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: _tripNoChange,
                child: Text(_text('dataManageNoChange', '변경 안함')),
              ),
              DropdownMenuItem<String>(
                value: _tripUnassigned,
                child: Text(_text('travelUnassignedLabel', '미지정')),
              ),
              ...widget.trips.map(
                (Trip trip) => DropdownMenuItem<String>(
                  value: trip.id,
                  child: Text(
                    '${trip.name} · ${_formatPeriod(trip)}${trip.isArchived ? ' (${_text('travelArchivedLabel', '보관됨')})' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (String? value) {
              if (value == null) return;
              setState(() {
                _tripChoice = value;
                if (value != _tripNoChange) _subcategoryCode = 't';
              });
              _notifyChanged();
            },
          ),
          if (_tripChoice != _tripNoChange) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _text(
                  'dataManageTripChangeHint',
                  '여행을 선택하면 소비 소구분도 여행으로 변경됩니다.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _formatPeriod(Trip trip) {
    String date(DateTime value) =>
        '${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
    return '${date(trip.startDate)}~${date(trip.endDate)}';
  }
}
