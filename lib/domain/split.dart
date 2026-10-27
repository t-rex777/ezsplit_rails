class SplitCheck {
  const SplitCheck({required this.ok, required this.remaining});

  final bool ok;

  /// Paise for exact splits, hundredths of a percent for percent splits.
  /// Positive means left, negative means over.
  final int remaining;
}

/// Mirrors the server: floor each share, then give leftover paise one each to
/// the first entries in list order.
Map<int, int> splitByWeights(int totalPaise, List<MapEntry<int, num>> weights) {
  // Weights are scaled to hundredths so fractional weights stay integer maths.
  final scaled = [for (final w in weights) (w.value * 100).round()];
  final sum = scaled.fold<int>(0, (a, b) => a + b);
  final result = <int, int>{};
  if (weights.isEmpty) return result;
  if (sum <= 0) {
    for (final w in weights) {
      result[w.key] = 0;
    }
    return result;
  }
  var assigned = 0;
  for (var i = 0; i < weights.length; i++) {
    final share = (totalPaise * scaled[i]) ~/ sum;
    result[weights[i].key] = share;
    assigned += share;
  }
  var leftover = totalPaise - assigned;
  for (final w in weights) {
    if (leftover <= 0) break;
    result[w.key] = result[w.key]! + 1;
    leftover--;
  }
  return result;
}

Map<int, int> splitEqual(int totalPaise, List<int> userIds) =>
    splitByWeights(totalPaise, [for (final id in userIds) MapEntry(id, 1)]);

Map<int, int> splitPercent(int totalPaise, List<MapEntry<int, num>> percents) =>
    splitByWeights(totalPaise, percents);

SplitCheck checkExact(int totalPaise, Map<int, int> amounts) {
  final remaining = totalPaise - amounts.values.fold<int>(0, (a, b) => a + b);
  return SplitCheck(ok: remaining == 0, remaining: remaining);
}

SplitCheck checkPercent(List<num> percents) {
  final sum = percents.fold<int>(0, (a, p) => a + (p * 100).round());
  final remaining = 10000 - sum;
  return SplitCheck(ok: remaining == 0, remaining: remaining);
}
