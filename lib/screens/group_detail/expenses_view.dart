import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';
import '../../domain/money.dart';
import '../../state/group_detail.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_input.dart';
import '../../widgets/category_icon.dart';
import '../groups/group_widgets.dart';
import 'filter_sheet.dart';

class ExpensesView extends ConsumerStatefulWidget {
  const ExpensesView({
    super.key,
    required this.groupId,
    required this.filters,
    required this.onFilters,
  });

  final int groupId;
  final ExpenseFilters filters;
  final ValueChanged<ExpenseFilters> onFilters;

  @override
  ConsumerState<ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends ConsumerState<ExpensesView> {
  late final TextEditingController _search;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.filters.q);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  ExpenseListKey get _key => (widget.groupId, widget.filters);

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      widget.onFilters(widget.filters.copyWith(q: value.trim()));
    });
  }

  /// The filters with the search box exactly as it reads now. Any pending
  /// debounce is dropped because this applies the text itself.
  ExpenseFilters _withSearch(ExpenseFilters f) {
    _debounce?.cancel();
    return f.copyWith(q: _search.text.trim());
  }

  Future<void> _openFilters() async {
    final picked = await showFilterSheet(
      context,
      groupId: widget.groupId,
      current: _withSearch(widget.filters),
    );
    if (!mounted) return;
    // The sheet never owns the search text, so keep the box's text either way.
    widget.onFilters(_withSearch(picked ?? widget.filters));
  }

  Future<void> _refresh() async {
    ref.invalidate(groupExpensesProvider(_key));
    try {
      await ref.read(groupExpensesProvider(_key).future);
    } catch (_) {
      // The list shows its own error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(groupExpensesProvider(_key));
    final active = !widget.filters.isDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: BrutalInput(
                hint: 'Search expenses',
                controller: _search,
                prefix: const Icon(Symbols.search),
                onChanged: _onSearch,
              ),
            ),
            const SizedBox(width: 8),
            _ToolButton(
              icon: Symbols.filter_list,
              label: 'Filter',
              active: active,
              onTap: _openFilters,
            ),
            const SizedBox(width: 8),
            _ToolButton(
              icon: Symbols.swap_vert,
              label: 'Sort',
              active: widget.filters.sort != ExpenseSort.newest,
              onTap: _openFilters,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: list.when(
            skipLoadingOnReload: true,
            loading: () =>
                Center(child: CircularProgressIndicator(color: context.ez.ink)),
            error: (e, _) => RetryMessage(
              message: errorMessage(e),
              onRetry: () => ref.invalidate(groupExpensesProvider(_key)),
            ),
            data: (state) => RefreshIndicator(
              onRefresh: _refresh,
              child: _List(
                groupId: widget.groupId,
                state: state,
                filters: widget.filters,
                searching: _search.text.trim().isNotEmpty,
                onMore: () =>
                    ref.read(groupExpensesProvider(_key).notifier).loadMore(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BrutalSurface(
      color: active ? context.ez.amber : context.ez.card,
      borderWidth: kPillBorder,
      radius: 999,
      shadowOffset: 2,
      isButton: true,
      semanticLabel: label,
      onTap: onTap,
      constraints: const BoxConstraints(minWidth: kMinTap, minHeight: kMinTap),
      child: Center(child: Icon(icon, color: active ? onAccent : null)),
    );
  }
}

/// A date heading or an expense, in list order.
sealed class _Entry {}

class _Heading extends _Entry {
  _Heading(this.date);
  final DateTime date;
}

class _Row extends _Entry {
  _Row(this.expense);
  final Expense expense;
}

class _More extends _Entry {}

List<_Entry> _entries(ExpenseListState state, List<Expense> shown) {
  final out = <_Entry>[];
  DateTime? last;
  for (final e in shown) {
    final day = DateTime(e.date.year, e.date.month, e.date.day);
    if (last != day) out.add(_Heading(day));
    last = day;
    out.add(_Row(e));
  }
  if (state.nextPage != null) out.add(_More());
  return out;
}

class _List extends ConsumerWidget {
  const _List({
    required this.groupId,
    required this.state,
    required this.filters,
    required this.searching,
    required this.onMore,
  });

  final int groupId;
  final ExpenseListState state;
  final ExpenseFilters filters;
  final bool searching;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = filters.onlyUnsettled
        ? [
            for (final e in state.items)
              if (e.myAmountPaise != 0) e,
          ]
        : state.items;
    final entries = _entries(state, shown);
    if (entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.items.isEmpty && !searching && filters.isDefault)
            _EmptyExpenses(groupId: groupId)
          else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No expenses match.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88, right: 4),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        switch (entries[i]) {
          case _Heading(:final date):
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                _dateLabel(date),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            );
          case _Row(:final expense):
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ExpenseRow(expense: expense),
            );
          case _More():
            return _MoreFooter(state: state, onMore: onMore);
        }
      },
    );
  }
}

String _dateLabel(DateTime d) {
  final sameYear = d.year == DateTime.now().year;
  return DateFormat(sameYear ? 'MMM d' : 'MMM d, y').format(d);
}

/// Building this row means the user is near the bottom, so it asks for the
/// next page. After a failure it waits for a tap instead of retrying alone.
class _MoreFooter extends StatefulWidget {
  const _MoreFooter({required this.state, required this.onMore});

  final ExpenseListState state;
  final VoidCallback onMore;

  @override
  State<_MoreFooter> createState() => _MoreFooterState();
}

class _MoreFooterState extends State<_MoreFooter> {
  @override
  void initState() {
    super.initState();
    _ask();
  }

  @override
  void didUpdateWidget(_MoreFooter old) {
    super.didUpdateWidget(old);
    // A page that is still too short to fill the screen keeps the footer on screen.
    if (old.state.items.length != widget.state.items.length) _ask();
  }

  void _ask() {
    if (widget.state.loadingMore || widget.state.moreFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.moreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            const Text("Couldn't load more."),
            const SizedBox(height: 8),
            BrutalButton(label: 'Try again', onPressed: widget.onMore),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: context.ez.ink,
          ),
        ),
      ),
    );
  }
}

class _ExpenseRow extends ConsumerWidget {
  const _ExpenseRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final me = ref.watch(sessionProvider).value;
    final payer = expense.payer.id == me?.id ? 'You' : userName(expense.payer);
    final mine = expense.myAmountPaise;
    final (String word, Color color) = mine < 0
        ? ('you owe', c.negative)
        : mine > 0
        ? ('you lent', c.positive)
        : ('not involved', c.ink);
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push('/expenses/${expense.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: parseHexColor(expense.category.color, c.amber),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.line, width: kCardBorder),
            ),
            child: Center(child: CategoryIcon(expense.category.icon, onAccent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        payer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'paid ${formatRupees(expense.paise)}',
                      softWrap: false,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(word, style: text.bodySmall),
              if (mine != 0)
                Text(
                  formatRupees(mine.abs()),
                  softWrap: false,
                  style: text.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses({required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Icon(Symbols.receipt_long, size: 56, color: context.ez.ink),
          const SizedBox(height: 16),
          Text(
            'No expenses yet',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          BrutalButton(
            label: 'Add the first expense',
            icon: Symbols.add,
            onPressed: () => context.push('/groups/$groupId/expenses/new'),
          ),
        ],
      ),
    );
  }
}
