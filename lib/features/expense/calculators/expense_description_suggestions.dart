import 'package:household_ledger/model/expense_entry.dart';

/// Builds a sheet-local index from existing expenses, without storing a second
/// history. Frequency wins, then most recent usage, then normalized text.
List<String> rankExpenseDescriptions(Iterable<ExpenseEntry> expenses) {
  final counts = <String, int>{};
  final latest = <String, DateTime>{};
  final labels = <String, String>{};
  for (final expense in expenses) {
    final label = expense.description.trim();
    if (label.isEmpty) continue;
    final key = label.toLowerCase();
    counts[key] = (counts[key] ?? 0) + 1;
    if (!latest.containsKey(key) || expense.spentAt.isAfter(latest[key]!)) {
      latest[key] = expense.spentAt;
      labels[key] = label;
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final frequency = counts[b]!.compareTo(counts[a]!);
      if (frequency != 0) return frequency;
      final recency = latest[b]!.compareTo(latest[a]!);
      return recency != 0 ? recency : a.compareTo(b);
    });
  return List.unmodifiable(keys.map((key) => labels[key]!));
}

/// Matches literal substrings, including Korean/Japanese and partial words.
/// An exact match is already entered and does not need a completion action.
List<String> matchExpenseDescriptions(List<String> ranked, String input) {
  final query = input.trim().toLowerCase();
  return ranked
      .where((label) {
        final normalized = label.toLowerCase();
        return normalized != query && normalized.contains(query);
      })
      .take(5)
      .toList(growable: false);
}
