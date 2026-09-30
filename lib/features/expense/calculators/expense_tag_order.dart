/// Orders available codes by usage, preserving their original order on ties.
/// An existing selection stays visible when reopening an expense for editing.
List<String> orderExpenseTagCodes({
  required Iterable<String> availableCodes,
  required Iterable<String> usedCodes,
  String? selectedCode,
}) {
  final codes = availableCodes.toList();
  final positions = <String, int>{
    for (var i = 0; i < codes.length; i++) codes[i]: i,
  };
  final counts = <String, int>{};
  for (final code in usedCodes) {
    counts[code] = (counts[code] ?? 0) + 1;
  }
  codes.sort((a, b) {
    if (a == b) return 0;
    if (a == selectedCode) return -1;
    if (b == selectedCode) return 1;
    final frequency = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
    return frequency != 0 ? frequency : positions[a]!.compareTo(positions[b]!);
  });
  return List.unmodifiable(codes);
}
