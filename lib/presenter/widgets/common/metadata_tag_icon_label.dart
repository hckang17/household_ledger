import 'package:flutter/material.dart';
import 'package:household_ledger/model/metadata_tag.dart';
import 'package:household_ledger/presenter/extensions/metadata_tag_icon_extension.dart';

class MetadataTagIconLabel extends StatelessWidget {
  const MetadataTagIconLabel({
    required this.tag,
    this.iconSize = 20,
    super.key,
  });

  final MetadataTag tag;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(tag.iconData, size: iconSize),
        const SizedBox(width: 8),
        Flexible(child: Text(tag.label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
