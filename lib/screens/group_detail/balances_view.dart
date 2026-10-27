import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';
import '../../domain/money.dart';
import '../../domain/settle_plan.dart';
import '../../state/group_detail.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/money_text.dart';
import '../groups/group_widgets.dart';
import 'settle_up_sheet.dart';

class BalancesView extends ConsumerWidget {
  const BalancesView({super.key, required this.groupId});

  final int groupId;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(groupBalancesProvider(groupId));
    try {
      await ref.read(groupBalancesProvider(groupId).future);
    } catch (_) {
      // The view shows its own error state.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(groupBalancesProvider(groupId));
    final me = ref.watch(sessionProvider).value;
    return balances.when(
      skipLoadingOnReload: true,
      loading: () =>
          Center(child: CircularProgressIndicator(color: context.ez.ink)),
      error: (e, _) => RetryMessage(
        message: errorMessage(e),
        onRetry: () => ref.invalidate(groupBalancesProvider(groupId)),
      ),
      data: (rows) => RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: _Body(groupId: groupId, rows: rows, meId: me?.id),
      ),
    );
  }
}

/// The simplest transfers, or null when the balances do not add up to 0.
List<Transfer>? _plan(List<BalanceRow> rows) {
  try {
    return settlePlan({for (final r in rows) r.userId: r.paise});
  } on ArgumentError {
    return null;
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.groupId, required this.rows, required this.meId});

  final int groupId;
  final List<BalanceRow> rows;
  final int? meId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plan = _plan(rows);
    final names = {
      for (final r in rows) r.userId: r.userId == meId ? 'You' : balanceName(r),
    };
    final first = plan == null
        ? null
        : plan.where((t) => t.fromUserId == meId).firstOrNull ??
              plan.where((t) => t.toUserId == meId).firstOrNull;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24, right: 4),
      children: [
        BrutalCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (final r in rows)
                _MemberRow(
                  row: r,
                  name: names[r.userId]!,
                  isMe: r.userId == meId,
                ),
            ],
          ),
        ),
        if (plan != null) ...[
          const SizedBox(height: 20),
          if (plan.isEmpty)
            Text(
              "Everyone's settled up",
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            )
          else ...[
            Text(
              'Simplest way to settle',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (final t in plan)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransferRow(
                  from: names[t.fromUserId] ?? 'Member',
                  to: names[t.toUserId] ?? 'Member',
                  paise: t.paise,
                ),
              ),
          ],
          if (first != null) ...[
            const SizedBox(height: 10),
            BrutalButton(
              label: 'Settle up',
              icon: Symbols.payments,
              onPressed: () => showSettleUpSheet(
                context,
                groupId: groupId,
                transfer: first,
                meId: meId!,
                names: names,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.row, required this.name, required this.isMe});

  final BalanceRow row;
  final String name;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinTap + 8),
      child: Row(
        children: [
          Avatar(balanceInitials(row), tintFor(context, row.userId)),
          const SizedBox(width: 12),
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
          MoneyText(row.paise, style: MoneyStyle.owesGets),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.from,
    required this.to,
    required this.paise,
  });

  final String from;
  final String to;
  final int paise;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$from pays $to ${formatRupees(paise)}',
      excludeSemantics: true,
      child: BrutalCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$from → $to',
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
      ),
    );
  }
}
