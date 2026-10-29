import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activities_repository.dart';
import '../data/models.dart';

class ActivityFeedState {
  const ActivityFeedState({
    required this.items,
    required this.nextPage,
    this.loadingMore = false,
    this.moreFailed = false,
  });

  final List<ActivityEntry> items;
  final int? nextPage;
  final bool loadingMore;
  final bool moreFailed;

  /// Expenses with a delete in the loaded feed, so their rows don't offer a dead link.
  Set<int> get deletedExpenseIds => {
    for (final e in items)
      if (e.action == ActivityAction.deleted && e.expenseId != null)
        e.expenseId!,
  };
}

class ActivityFeedNotifier extends AsyncNotifier<ActivityFeedState> {
  ActivityFeedNotifier(this.filter);

  final ActivityFilter filter;

  // Bumped on every (re)load so a late page for an old list is dropped.
  int _generation = 0;

  @override
  Future<ActivityFeedState> build() async {
    _generation++;
    final page = await ref.watch(activitiesRepositoryProvider).list(filter);
    return ActivityFeedState(items: page.items, nextPage: page.nextPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (state.isLoading ||
        current == null ||
        current.nextPage == null ||
        current.loadingMore) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      ActivityFeedState(
        items: current.items,
        nextPage: current.nextPage,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(activitiesRepositoryProvider)
          .list(filter, page: current.nextPage!);
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        ActivityFeedState(
          items: [...current.items, ...page.items],
          nextPage: page.nextPage,
        ),
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        ActivityFeedState(
          items: current.items,
          nextPage: current.nextPage,
          moreFailed: true,
        ),
      );
    }
  }
}

final activityFeedProvider = AsyncNotifierProvider.autoDispose
    .family<ActivityFeedNotifier, ActivityFeedState, ActivityFilter>(
      ActivityFeedNotifier.new,
      retry: (_, _) => null,
    );
