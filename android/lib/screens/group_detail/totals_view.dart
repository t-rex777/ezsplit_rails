import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../domain/money.dart';
import '../../state/group_detail.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/money_text.dart';
import '../groups/group_widgets.dart';

class TotalsView extends ConsumerWidget {
  const TotalsView({super.key, required this.groupId});

  final int groupId;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(groupTotalsProvider(groupId));
    try {
      await ref.read(groupTotalsProvider(groupId).future);
    } catch (_) {
      // The view shows its own error state.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(groupTotalsProvider(groupId));
    final meId = ref.watch(sessionProvider).value?.id;
    return totals.when(
      skipLoadingOnReload: true,
      loading: () =>
          Center(child: CircularProgressIndicator(color: context.ez.ink)),
      error: (e, _) => RetryMessage(
        message: errorMessage(e),
        onRetry: () => ref.invalidate(groupTotalsProvider(groupId)),
      ),
      data: (t) => RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: _Body(totals: t, meId: meId),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.totals, required this.meId});

  final GroupTotals totals;
  final int? meId;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    Widget heading(String s) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        s,
        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24, right: 4),
      children: [
        _StatCard(
          label: 'Group spent',
          paise: totals.totalSpentPaise,
          color: c.amber,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Your share',
                paise: totals.mySharePaise,
                color: c.mint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'You paid',
                paise: totals.iPaidPaise,
                color: c.lilac,
              ),
            ),
          ],
        ),
        heading('By category'),
        BrutalCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (final cat in totals.categories)
                _AmountRow(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: parseHexColor(cat.color, c.amber),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.line, width: kPillBorder),
                    ),
                    child: Center(
                      child: CategoryIcon(cat.icon, onAccent, size: 20),
                    ),
                  ),
                  name: cat.name,
                  paise: cat.paise,
                ),
            ],
          ),
        ),
        heading('Who paid what'),
        BrutalCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (final p in totals.paidBy)
                _AmountRow(
                  name: p.userId == meId
                      ? 'You'
                      : (p.firstName.isNotEmpty ? p.firstName : p.lastName),
                  paise: p.paise,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.paise,
    required this.color,
  });

  final String label;
  final int paise;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BrutalCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodyMedium?.copyWith(color: onAccent)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupees(paise),
              softWrap: false,
              style: text.headlineSmall?.copyWith(
                color: onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({this.leading, required this.name, required this.paise});

  final Widget? leading;
  final String name;
  final int paise;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinTap + 4),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          MoneyText(paise),
        ],
      ),
    );
  }
}
