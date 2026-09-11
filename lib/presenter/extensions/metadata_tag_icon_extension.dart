import 'package:flutter/material.dart';
import 'package:household_ledger/model/metadata_tag.dart';

/// 저장된 아이콘 코드를 현재 Material 아이콘으로 변환한다.
extension MetadataTagIconX on MetadataTag {
  IconData get iconData => switch (effectiveIconCode) {
    'hotel' => Icons.hotel_rounded,
    'local_cafe' => Icons.local_cafe_rounded,
    'shopping_bag' => Icons.shopping_bag_rounded,
    'category' => Icons.category_rounded,
    'restaurant' => Icons.restaurant_rounded,
    'local_grocery_store' => Icons.local_grocery_store_rounded,
    'palette' => Icons.palette_rounded,
    'home' => Icons.home_rounded,
    'sports_soccer' => Icons.sports_soccer_rounded,
    'directions_transit' => Icons.directions_transit_rounded,
    'celebration' => Icons.celebration_rounded,
    _ => Icons.label_rounded,
  };
}

extension MetadataTagIconListX on List<MetadataTag> {
  IconData iconFor(String code) {
    for (final tag in this) {
      if (tag.code == code) return tag.iconData;
    }
    return Icons.label_rounded;
  }
}
