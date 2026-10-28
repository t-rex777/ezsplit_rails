import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/balances_repository.dart';
import '../data/categories_repository.dart';
import '../data/expenses_repository.dart';
import '../data/groups_repository.dart';
import '../data/models.dart';

/// What the expenses list is narrowed and ordered by. Equal filters are equal
/// keys, so the same filters reuse the same loaded list.
class ExpenseFilters {
  const ExpenseFilters({
    this.q = '',
    this.sort = ExpenseSort.newest,
    this.categoryIds = const [],
    this.paidBy,
    this.from,
    this.to,
    this.onlyUnsettled = false,
  });

  final String q;
  final ExpenseSort sort;
  final List<int> categoryIds;
  final PaidBy? paidBy;
  final DateTime? from;
  final DateTime? to;

  /// Applied on the device: hides expenses where my amount is 0.
  final bool onlyUnsettled;

  /// True when the filter sheet has nothing set (the search text is separate).
  bool get isDefault =>
      sort == ExpenseSort.newest &&
      categoryIds.isEmpty &&
      paidBy == null &&
      from == null &&
      to == null &&
      !onlyUnsettled;

  ExpenseFilters copyWith({
    String? q,
    ExpenseSort? sort,
    List<int>? categoryIds,
    PaidBy? Function()? paidBy,
    DateTime? Function()? from,
    DateTime? Function()? to,
    bool? onlyUnsettled,
  }) => ExpenseFilters(
    q: q ?? this.q,
    sort: sort ?? this.sort,
    categoryIds: categoryIds ?? this.categoryIds,
    paidBy: paidBy != null ? paidBy() : this.paidBy,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
    onlyUnsettled: onlyUnsettled ?? this.onlyUnsettled,
  );

  ExpenseQuery toQuery(int groupId, {int? page}) => ExpenseQuery(
    groupId: groupId,
    q: q.trim(),
    categoryIds: categoryIds,
    paidBy: paidBy,
    from: from,
    to: to,
    sort: sort == ExpenseSort.newest ? null : sort,
    page: page,
  );

  @override
  bool operator ==(Object other) =>
      other is ExpenseFilters &&
      other.q == q &&
      other.sort == sort &&
      _sameIds(other.categoryIds, categoryIds) &&
      other.paidBy == paidBy &&
      other.from == from &&
      other.to == to &&
      other.onlyUnsettled == onlyUnsettled;

  @override
  int get hashCode => Object.hash(
    q,
    sort,
    Object.hashAll(categoryIds),
    paidBy,
    from,
    to,
    onlyUnsettled,
  );
}

bool _sameIds(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class ExpenseListState {
  const ExpenseListState({
    required this.items,
    required this.nextPage,
    this.loadingMore = false,
    this.moreFailed = false,
  });

  final List<Expense> items;
  final int? nextPage;
  final bool loadingMore;

  /// The last attempt at the next page failed; the list offers a retry.
  final bool moreFailed;

  ExpenseListState copyWith({
    List<Expense>? items,
    int? nextPage,
    bool? loadingMore,
    bool? moreFailed,
  }) => ExpenseListState(
    items: items ?? this.items,
    nextPage: nextPage ?? this.nextPage,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailed: moreFailed ?? this.moreFailed,
  );
}

typedef ExpenseListKey = (int groupId, ExpenseFilters filters);

class ExpenseListNotifier extends AsyncNotifier<ExpenseListState> {
  ExpenseListNotifier(this.key);

  final ExpenseListKey key;

  // Bumped on every (re)load so a late page for an old list is dropped.
  int _generation = 0;

  @override
  Future<ExpenseListState> build() async {
    _generation++;
    final page = await ref
        .watch(expensesRepositoryProvider)
        .list(key.$2.toQuery(key.$1));
    return ExpenseListState(items: page.items, nextPage: page.nextPage);
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
    state = AsyncData(current.copyWith(loadingMore: true, moreFailed: false));
    try {
      final page = await ref
          .read(expensesRepositoryProvider)
          .list(key.$2.toQuery(key.$1, page: current.nextPage));
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        ExpenseListState(
          items: [...current.items, ...page.items],
          nextPage: page.nextPage,
        ),
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(current.copyWith(loadingMore: false, moreFailed: true));
    }
  }
}

final groupExpensesProvider = AsyncNotifierProvider.autoDispose
    .family<ExpenseListNotifier, ExpenseListState, ExpenseListKey>(
      ExpenseListNotifier.new,
      retry: (_, _) => null,
    );

final groupBalancesProvider = FutureProvider.autoDispose
    .family<List<BalanceRow>, int>(
      (ref, id) => ref.watch(balancesRepositoryProvider).forGroup(id),
      retry: (_, _) => null,
    );

final groupTotalsProvider = FutureProvider.autoDispose.family<GroupTotals, int>(
  (ref, id) => ref.watch(groupsRepositoryProvider).totals(id),
  retry: (_, _) => null,
);

final categoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(categoriesRepositoryProvider).list(),
  retry: (_, _) => null,
);
