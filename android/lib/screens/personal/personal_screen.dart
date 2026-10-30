import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';
import '../../domain/money.dart';
import '../../state/group_detail.dart';
import '../../state/summary.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../groups/group_widgets.dart';
import '../home/dashboard_screen.dart' show monthName;

/// The personal list: no filters, newest first.
const ExpenseListKey personalListKey = (null, ExpenseFilters());

/// Expenses outside any group that only I am in.
class PersonalScreen extends ConsumerWidget {
  const PersonalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final month = DateTime(now.year, now.month);
    final summary = ref.watch(monthlySummaryProvider(month)).value;
    final list = ref.watch(groupExpensesProvider(personalListKey));
    final text = Theme.of(context).textTheme;

    Future<void> refresh() async {
      ref.invalidate(groupExpensesProvider(personalListKey));
      ref.invalidate(monthlySummaryProvider(month));
      try {
        await ref.read(groupExpensesProvider(personalListKey).future);
      } catch (_) {
        // The list shows its own error state.
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    constraints: const BoxConstraints(
                      minWidth: kMinTap,
                      minHeight: kMinTap,
                    ),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    icon: const Icon(Symbols.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      'Personal',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AddPersonalButton(
                    label: 'Add',
                    onTap: () => context.push('/home/personal/new'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _MonthCard(month: month, summary: summary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: list.when(
                    skipLoadingOnReload: true,
                    loading: () => Center(
                      child: CircularProgressIndicator(color: context.ez.ink),
                    ),
                    error: (e, _) => RetryMessage(
                      message: errorMessage(e),
                      onRetry: () => ref.invalidate(
                        groupExpensesProvider(personalListKey),
                      ),
                    ),
                    data: (state) => RefreshIndicator(
                      onRefresh: refresh,
                      child: _List(state: state),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The amber pill that opens the personal expense form.
class AddPersonalButton extends StatelessWidget {
  const AddPersonalButton({super.key, required this.onTap, this.label});

  final VoidCallback onTap;

  /// Null shows only the plus.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return BrutalSurface(
      color: context.ez.amber,
      borderWidth: kPillBorder,
      radius: 999,
      shadowOffset: 3,
      isButton: true,
      semanticLabel: 'Add personal expense',
      onTap: onTap,
      constraints: const BoxConstraints(minHeight: kMinTap, minWidth: kMinTap),
      padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.add, color: onAccent),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: onAccent, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month, required this.summary});

  final DateTime month;
  final MonthlySummary? summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const ink = TextStyle(color: onAccent);
    final s = summary;
    return BrutalCard(
      color: context.ez.lilac,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${monthName(month)} ${month.year} · only you',
            style: text.bodyLarge?.merge(ink),
          ),
          const SizedBox(height: 4),
          Text(
            s == null ? '…' : formatRupees(s.personalPaise),
            style: text.headlineMedium
                ?.merge(ink)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          if (s != null)
            Text(
              '${s.personalCount} ${s.personalCount == 1 ? 'expense' : 'expenses'}, not shared with anyone',
              style: text.bodyMedium?.merge(ink),
            ),
        ],
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.state});

  final ExpenseListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 32),
          Icon(Symbols.receipt_long, size: 56, color: context.ez.ink),
          const SizedBox(height: 16),
          Text(
            'No personal expenses yet',
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            "Log what you spend on yourself. It isn't shared with anyone.",
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 20),
          Center(
            child: BrutalButton(
              label: 'Add personal expense',
              icon: Symbols.add,
              onPressed: () => context.push('/home/personal/new'),
            ),
          ),
        ],
      );
    }
    final more = state.nextPage != null;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24, right: 4),
      itemCount: state.items.length + (more ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == state.items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                if (state.moreFailed) const Text("Couldn't load more."),
                const SizedBox(height: 8),
                BrutalButton(
                  label: state.moreFailed ? 'Try again' : 'Load more',
                  onPressed: state.loadingMore
                      ? null
                      : () => ref
                            .read(
                              groupExpensesProvider(personalListKey).notifier,
                            )
                            .loadMore(),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Row(expense: state.items[i]),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = expense;
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push('/expenses/${e.id}'),
      child: Row(
        children: [
          IconTile(
            icon: e.category.icon,
            color: parseHexColor(e.category.color, context.ez.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${e.category.name} · ${DateFormat('d MMM').format(e.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRupees(e.paise),
            softWrap: false,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
