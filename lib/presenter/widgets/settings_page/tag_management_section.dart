// """ MVVM 계층: View / settings_page """
// """ 역할: 설정 화면의 메타데이터 태그 목록과 관리 액션 구성 """

import 'package:flutter/material.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/widgets/common/metadata_tag_icon_label.dart';
import 'package:household_ledger/presenter/widgets/common/bootstrap_style/bootstrap_widgets.dart';

/// 태그(소비구분/소비소구분/소비수단) 목록을 접기/펼치며 관리하는 섹션 카드다.
///
/// 확장 상태는 위젯 내부에서 관리하며, 추가/수정/삭제 이벤트는 콜백으로 전달한다.
class TagManagementSection extends StatefulWidget {
  const TagManagementSection({
    required this.title,
    required this.tags,
    required this.strings,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final String title;
  final List<MetadataTag> tags;
  final Map<String, String> strings;
  final VoidCallback onAdd;
  final ValueChanged<MetadataTag> onEdit;
  final ValueChanged<MetadataTag> onDelete;

  @override
  State<TagManagementSection> createState() => _TagManagementSectionState();
}

class _TagManagementSectionState extends State<TagManagementSection> {
  bool _expanded = false;

  String _label(String key, String fallback) => widget.strings[key] ?? fallback;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return BootstrapSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  button: true,
                  label:
                      '${widget.title} ${_label(_expanded ? 'collapseSection' : 'expandSection', _expanded ? '접기' : '펼치기')}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: _toggleExpanded,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add_circle_outline),
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                tooltip: '${widget.title} ${_label('addTag', '태그 추가')}',
              ),
              IconButton(
                onPressed: _toggleExpanded,
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                tooltip: _label(
                  _expanded ? 'collapseSection' : 'expandSection',
                  _expanded ? '접기' : '펼치기',
                ),
              ),
            ],
          ),
          if (_expanded) const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: !_expanded
                ? const SizedBox.shrink()
                : Column(
                    children: widget.tags.map((MetadataTag tag) {
                      final bool isSystemDefault = tag.isSystemDefault;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F9FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: tag.type == MetadataTagType.category
                                  ? MetadataTagIconLabel(tag: tag)
                                  : Text(
                                      tag.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                            ),
                            IconButton(
                              constraints: const BoxConstraints.tightFor(
                                width: 48,
                                height: 48,
                              ),
                              tooltip: '${tag.label} ${_label('edit', '수정')}',
                              onPressed: isSystemDefault
                                  ? null
                                  : () => widget.onEdit(tag),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              constraints: const BoxConstraints.tightFor(
                                width: 48,
                                height: 48,
                              ),
                              tooltip: '${tag.label} ${_label('delete', '삭제')}',
                              onPressed:
                                  !isSystemDefault && widget.tags.length > 1
                                  ? () => widget.onDelete(tag)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
