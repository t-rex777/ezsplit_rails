import '../data/models.dart';

/// Pie slices smaller than this share of the month fold into "Other".
const double otherThreshold = 0.05;

String categoryKey(String name) => name.toLowerCase();

/// Every category in [months], biggest total first. Bars stack in this order,
/// so a category keeps its place and colour from month to month.
List<CategorySpend> rankedCategories(List<AnalyticsMonth> months) {
  final totals = <String, int>{};
  final first = <String, CategorySpend>{};
  for (final m in months) {
    for (final c in m.categories) {
      final key = categoryKey(c.name);
      totals[key] = (totals[key] ?? 0) + c.paise;
      first.putIfAbsent(key, () => c);
    }
  }
  final keys = totals.keys.toList()
    ..sort((a, b) {
      final byAmount = totals[b]!.compareTo(totals[a]!);
      return byAmount != 0 ? byAmount : a.compareTo(b);
    });
  return [
    for (final k in keys)
      CategorySpend(
        name: first[k]!.name,
        icon: first[k]!.icon,
        color: first[k]!.color,
        paise: totals[k]!,
      ),
  ];
}

/// [months] without the [hidden] categories (keys from [categoryKey]), with
/// totals recounted.
List<AnalyticsMonth> withoutCategories(
  List<AnalyticsMonth> months,
  Set<String> hidden,
) {
  if (hidden.isEmpty) return months;
  return [
    for (final m in months)
      () {
        final kept = [
          for (final c in m.categories)
            if (!hidden.contains(categoryKey(c.name))) c,
        ];
        return AnalyticsMonth(
          month: m.month,
          totalPaise: kept.fold(0, (sum, c) => sum + c.paise),
          categories: kept,
          otherCurrencyCount: m.otherCurrencyCount,
        );
      }(),
  ];
}

/// Categories that get their own chart colour; the rest show as "Other".
const int chartSlots = 6;

/// A month's categories for the pie: the ones with their own colour, plus
/// what folded into Other.
typedef PieSplit = ({List<CategorySpend> big, int otherPaise, int otherCount});

/// Keeps a category when it is in [keep] (keys from [categoryKey]) and at least
/// [otherThreshold] of the month. Everything else folds into Other.
PieSplit foldSmall(
  List<CategorySpend> categories, {
  required Set<String> keep,
}) {
  final total = categories.fold<int>(0, (sum, c) => sum + c.paise);
  bool own(CategorySpend c) => keep.contains(categoryKey(c.name));
  bool small(CategorySpend c) => total > 0 && c.paise / total < otherThreshold;
  final big = <CategorySpend>[];
  final rest = <CategorySpend>[];
  for (final c in categories) {
    (own(c) && !small(c) ? big : rest).add(c);
  }
  // A lone leftover with its own colour keeps its name instead of "Other".
  if (rest.length == 1 && own(rest.single)) {
    big.add(rest.single);
    rest.clear();
  }
  big.sort((a, b) => b.paise.compareTo(a.paise));
  return (
    big: big,
    otherPaise: rest.fold(0, (sum, c) => sum + c.paise),
    otherCount: rest.length,
  );
}

/// Whole-number percent change from the month before [index] to [index].
/// Null when there is no earlier month or it had no spending.
int? changePercent(List<AnalyticsMonth> months, int index) {
  if (index < 1 || index >= months.length) return null;
  final before = months[index - 1].totalPaise;
  if (before <= 0) return null;
  return ((months[index].totalPaise - before) * 100 / before).round();
}

/// Average of the last 12 months (fewer if there are fewer), in paise,
/// rounded to whole rupees.
int averagePaise(List<AnalyticsMonth> months) {
  if (months.isEmpty) return 0;
  final recent = months.length > 12
      ? months.sublist(months.length - 12)
      : months;
  final sum = recent.fold<int>(0, (sum, m) => sum + m.totalPaise);
  return (sum / recent.length / 100).round() * 100;
}

/// The month with the most spending; the latest one wins a tie.
AnalyticsMonth? highestMonth(List<AnalyticsMonth> months) {
  AnalyticsMonth? best;
  for (final m in months) {
    if (best == null || m.totalPaise >= best.totalPaise) best = m;
  }
  return best;
}
