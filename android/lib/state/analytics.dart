import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics_repository.dart';
import '../data/models.dart';

/// Oldest month first.
final analyticsMonthsProvider = FutureProvider.autoDispose
    .family<List<AnalyticsMonth>, AnalyticsScope>(
      (ref, scope) => ref.watch(analyticsRepositoryProvider).months(scope),
      retry: (_, _) => null,
    );

typedef AnalyticsCategoryKey = ({
  DateTime month,
  String category,
  AnalyticsScope scope,
});

final analyticsExpensesProvider = FutureProvider.autoDispose
    .family<List<AnalyticsExpense>, AnalyticsCategoryKey>(
      (ref, key) => ref
          .watch(analyticsRepositoryProvider)
          .expenses(month: key.month, category: key.category, scope: key.scope),
      retry: (_, _) => null,
    );

class AnalyticsFilters {
  const AnalyticsFilters({
    this.scope = AnalyticsScope.all,
    this.hidden = const {},
  });

  final AnalyticsScope scope;

  /// Unticked categories, by lowercased name.
  final Set<String> hidden;
}

class AnalyticsFiltersNotifier extends Notifier<AnalyticsFilters> {
  @override
  AnalyticsFilters build() => const AnalyticsFilters();

  void set(AnalyticsFilters filters) => state = filters;
}

final analyticsFiltersProvider =
    NotifierProvider<AnalyticsFiltersNotifier, AnalyticsFilters>(
      AnalyticsFiltersNotifier.new,
    );
