import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/expenses_repository.dart';
import '../../data/models.dart';
import '../../domain/money.dart';
import '../../state/expense_form.dart';
import '../../state/groups.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_card.dart';
import '../groups/group_widgets.dart';
import 'expense_form_screen.dart' show personLabel;

class ExpenseDetailScreen extends ConsumerStatefulWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  ConsumerState<ExpenseDetailScreen> createState() =>
      _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends ConsumerState<ExpenseDetailScreen> {
  bool _deleting = false;
  String? _error;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/groups');
    }
  }

  Future<void> _delete(Expense e) async {
    final groupId = e.groupId;
    final meId = ref.read(sessionProvider).value?.id;
    final personal = meId != null && e.isPersonalFor(meId);
    final confirmed = await confirmSheet(
      context,
      title: 'Delete this expense?',
      body: personal
          ? "It's removed from your personal spending."
          : "It's removed for everyone in the split, and balances change.",
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted || _deleting) return;
    // The container outlives this screen, so the reload still happens.
    final container = ProviderScope.containerOf(context);
    final repo = ref.read(expensesRepositoryProvider);
    final router = GoRouter.of(context);
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await repo.delete(e.id);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = errorMessage(err);
      });
      return;
    }
    invalidateAfterExpenseChange(container.invalidate, groupId);
    router.go(
      groupId != null
          ? '/groups/$groupId'
          : personal
          ? '/home/personal'
          : '/groups',
    );
  }

  @override
  Widget build(BuildContext context) {
    final expense = ref.watch(expenseProvider(widget.expenseId));
    final me = ref.watch(sessionProvider).value;
    final e = expense.value;
    final mine = e != null && me != null && e.creatorId == me.id;
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _BarButton(
                      icon: Symbols.arrow_back,
                      label: 'Back',
                      onTap: _deleting ? null : _back,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Expense detail',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    // The server only lets the creator change or remove it.
                    if (mine && (e.groupId != null || e.isPersonalFor(me.id)))
                      _BarButton(
                        icon: Symbols.edit,
                        label: 'Edit expense',
                        onTap: _deleting
                            ? null
                            : () => context.push('/expenses/${e.id}/edit'),
                      ),
                    if (mine)
                      _BarButton(
                        icon: Symbols.delete,
                        label: 'Delete expense',
                        onTap: _deleting ? null : () => _delete(e),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: expense.when(
                  skipLoadingOnReload: true,
                  loading: () => Center(
                    child: CircularProgressIndicator(color: context.ez.ink),
                  ),
                  error: (err, _) => RetryMessage(
                    message: errorMessage(err),
                    onRetry: () =>
                        ref.invalidate(expenseProvider(widget.expenseId)),
                  ),
                  data: (e) => _Body(expense: e, deleteError: _error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: IconButton(
        constraints: const BoxConstraints(
          minWidth: kMinTap,
          minHeight: kMinTap,
        ),
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}

String _splitLabel(Expense e, int people) {
  final how = switch (e.splitType) {
    SplitType.equal => 'equally',
    SplitType.percentage => 'by percent',
    SplitType.exact => 'by exact amounts',
  };
  return 'split $how, $people ${people == 1 ? 'person' : 'people'}';
}

class _Body extends ConsumerWidget {
  const _Body({required this.expense, required this.deleteError});

  final Expense expense;
  final String? deleteError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = expense;
    final meId = ref.watch(sessionProvider).value?.id;
    final group = e.groupId == null
        ? null
        : ref.watch(groupProvider(e.groupId!)).value;
    final c = context.ez;
    final text = Theme.of(context).textTheme;

    // Payer and members cover everyone the group payload names.
    final people = <int, User>{
      for (final u in group?.members ?? const <User>[]) u.id: u,
      e.payer.id: e.payer,
    };
    String nameOf(int id) {
      final u = people[id];
      return u == null ? 'Member' : personLabel(u, meId ?? -1);
    }

    final creator = people[e.creatorId];
    final payerShare = e.shares
        .where((s) => s.userId == e.payer.id)
        .firstOrNull;
    final others = [
      for (final s in e.shares)
        if (s.userId != e.payer.id) s,
    ];
    final payerName = nameOf(e.payer.id);
    final personal = meId != null && e.isPersonalFor(meId);
    final details = [
      if (group != null) group.name,
      if (personal) 'Personal',
      e.category.name,
      DateFormat('d MMM y').format(e.date),
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        BrutalCard(
          child: Column(
            children: [
              IconTile(
                icon: e.category.icon,
                color: parseHexColor(e.category.color, c.amber),
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                e.name,
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                formatRupees(e.paise),
                softWrap: false,
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(details, textAlign: TextAlign.center),
              if (creator != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Added by ${personLabel(creator, meId ?? -1)}',
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        BrutalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$payerName paid ${formatRupees(e.paise)}',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              if (personal)
                const Text('Only you. Nobody owes anything.')
              else
                Text(_splitLabel(e, e.shares.length)),
              if (payerShare != null && !personal) ...[
                const SizedBox(height: 2),
                Text(
                  e.payer.id == meId
                      ? 'Your own share is ${formatRupees(payerShare.paise)}'
                      : "$payerName's own share is ${formatRupees(payerShare.paise)}",
                  style: text.bodySmall,
                ),
              ],
              for (final s in others) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Avatar(
                      _initial(nameOf(s.userId)),
                      tintFor(context, s.userId),
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nameOf(s.userId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${s.userId == meId ? 'owe' : 'owes'} ${formatRupees(s.paise)}',
                      softWrap: false,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: s.userId == meId ? c.negative : null,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (e.notes != null && e.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          BrutalCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Symbols.sticky_note_2),
                const SizedBox(width: 10),
                Expanded(child: Text(e.notes!.trim())),
              ],
            ),
          ),
        ],
        if (deleteError != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              deleteError!,
              style: text.bodyMedium?.copyWith(
                color: c.negative,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (e.groupId != null) ...[
          const SizedBox(height: 16),
          Semantics(
            button: true,
            child: InkWell(
              onTap: () => context.go('/groups/${e.groupId}?view=balances'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kMinTap),
                child: Row(
                  children: [
                    Text(
                      'See group balances',
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Symbols.arrow_forward, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _initial(String name) => name.isEmpty ? '?' : name[0].toUpperCase();
