import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/api_error.dart';
import '../../domain/money.dart';
import '../../state/group_detail.dart';
import '../../state/groups.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_pill.dart';
import '../groups/group_widgets.dart' show RetryMessage;
import 'balances_view.dart';
import 'expenses_view.dart';
import 'totals_view.dart';

enum GroupView {
  expenses('Expenses'),
  balances('Balances'),
  totals('Totals');

  const GroupView(this.label);
  final String label;

  static GroupView fromQuery(String? value) => GroupView.values.firstWhere(
    (v) => v.name == value,
    orElse: () => GroupView.expenses,
  );
}

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId, this.view});

  /// Null when the id in the link is not a number.
  final int? groupId;

  /// The `view` query value; anything unknown opens Expenses.
  final String? view;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  // Kept here so the search and filters survive a trip to another view.
  ExpenseFilters _filters = const ExpenseFilters();

  int get _id => widget.groupId!;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/groups');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupId == null) {
      return _NotFound(message: 'Group not found', onBack: _back);
    }
    final view = GroupView.fromQuery(widget.view);
    final group = ref.watch(groupProvider(_id));
    if (group.hasError && !group.hasValue) {
      final error = group.error;
      return _NotFound(
        message: error is ApiError && error.status == null
            ? error.message
            : 'Group not found',
        onBack: _back,
        onRetry: () => ref.invalidate(groupProvider(_id)),
      );
    }
    final text = Theme.of(context).textTheme;
    return Scaffold(
      floatingActionButton: view == GroupView.expenses
          ? _AddButton(onTap: () => context.push('/groups/$_id/expenses/new'))
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _IconButton(
                    icon: Symbols.arrow_back,
                    label: 'Back',
                    onTap: _back,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.value?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _IconButton(
                    icon: Symbols.settings,
                    label: 'Group settings',
                    onTap: () => context.push('/groups/$_id/settings'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _NetCard(groupId: _id),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in GroupView.values)
                    BrutalPill(
                      label: v.label,
                      selected: v == view,
                      onTap: v == view
                          ? null
                          : () => context.go('/groups/$_id?view=${v.name}'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: switch (view) {
                  GroupView.expenses => ExpensesView(
                    groupId: _id,
                    filters: _filters,
                    onFilters: (f) => setState(() => _filters = f),
                  ),
                  GroupView.balances => BalancesView(groupId: _id),
                  GroupView.totals => TotalsView(groupId: _id),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.message, required this.onBack, this.onRetry});

  final String message;
  final VoidCallback onBack;

  /// Null when retrying cannot help, as with a link that is not a number.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _IconButton(
                  icon: Symbols.arrow_back,
                  label: 'Back',
                  onTap: onBack,
                ),
              ),
              Expanded(
                child: onRetry == null
                    ? Center(child: Text(message, textAlign: TextAlign.center))
                    : RetryMessage(message: message, onRetry: onRetry!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetCard extends ConsumerWidget {
  const _NetCard({required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).value;
    final rows = ref.watch(groupBalancesProvider(groupId)).value;
    if (me == null || rows == null) return const SizedBox.shrink();
    final mine = rows.where((r) => r.userId == me.id).firstOrNull;
    final net = mine?.paise ?? 0;
    final text = Theme.of(context).textTheme;
    final label = net > 0
        ? "you're owed overall"
        : net < 0
        ? 'you owe overall'
        : 'all settled up';
    return BrutalCard(
      color: net > 0
          ? context.ez.green
          : net < 0
          ? context.ez.peach
          : context.ez.mint,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyLarge?.copyWith(
                color: onAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (net != 0)
            Text(
              formatRupees(net.abs()),
              softWrap: false,
              style: text.titleLarge?.copyWith(
                color: onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BrutalSurface(
      color: context.ez.card,
      borderWidth: kPillBorder,
      radius: 999,
      shadowOffset: 2,
      isButton: true,
      semanticLabel: label,
      onTap: onTap,
      constraints: const BoxConstraints(minWidth: kMinTap, minHeight: kMinTap),
      child: Center(child: Icon(icon, color: context.ez.ink)),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The floating button slot gives loose constraints, so the size is fixed.
    return SizedBox(
      width: 56,
      height: 56,
      child: BrutalSurface(
        color: context.ez.amber,
        borderWidth: kCardBorder,
        radius: 999,
        isButton: true,
        semanticLabel: 'Add expense',
        onTap: onTap,
        child: const Center(
          child: Icon(Symbols.add, color: onAccent, size: 28),
        ),
      ),
    );
  }
}
