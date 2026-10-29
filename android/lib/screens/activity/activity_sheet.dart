import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../domain/money.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_sheet.dart';
import 'activity_row.dart';
import 'activity_text.dart';

/// [canOpen] is false once the feed shows the expense was deleted.
Future<void> showActivitySheet(
  BuildContext context, {
  required ActivityEntry entry,
  required int? meId,
  required DateTime now,
  required bool canOpen,
}) {
  final title =
      '${personName(entry.actorName, entry.actorId, meId)} '
      '${verbFor(entry.action)} ${objectOf(entry, meId)}';
  return showBrutalSheet<void>(
    context,
    title: title,
    child: _ActivityDetail(
      entry: entry,
      meId: meId,
      now: now,
      onOpen: canOpen && entry.expenseId != null
          ? () {
              Navigator.of(context).pop();
              context.push('/expenses/${entry.expenseId}');
            }
          : null,
    ),
  );
}

class _ActivityDetail extends StatelessWidget {
  const _ActivityDetail({
    required this.entry,
    required this.meId,
    required this.now,
    required this.onOpen,
  });

  final ActivityEntry entry;
  final int? meId;
  final DateTime now;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final unchanged = entry.action == ActivityAction.updated
        ? unchangedLine(entry.changedFields)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ActorBadge(entry: entry, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${entry.groupName ?? 'No group'} · '
                '${dayLabel(entry.at, now)}, ${timeLabel(entry.at)}',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        switch (entry.action) {
          ActivityAction.updated => _ChangesCard(entry: entry, meId: meId),
          ActivityAction.deleted => _SnapshotCard(
            title: 'The expense that was removed',
            fill: context.ez.peach,
            snapshot: entry.before!,
            meId: meId,
          ),
          ActivityAction.created => _SnapshotCard(
            title: 'The expense as added',
            fill: context.ez.green,
            snapshot: entry.after!,
            meId: meId,
          ),
          ActivityAction.settled => _PaymentCard(
            payment: entry.payment!,
            meId: meId,
          ),
        },
        if (entry.action == ActivityAction.updated) ...[
          const SizedBox(height: 12),
          _BeforeTile(snapshot: entry.before!, meId: meId),
        ],
        if (unchanged != null) ...[
          const SizedBox(height: 12),
          Text(unchanged, style: text.bodyMedium),
        ],
        if (entry.action == ActivityAction.settled) ...[
          const SizedBox(height: 12),
          Text(
            'This records a payment. No money moves in the app.',
            style: text.bodyMedium,
          ),
        ],
        if (entry.action == ActivityAction.deleted) ...[
          const SizedBox(height: 12),
          Text(
            'This expense no longer counts toward balances.',
            style: text.bodyMedium,
          ),
        ],
        if (onOpen != null) ...[
          const SizedBox(height: 20),
          BrutalButton(label: 'Open expense', onPressed: onOpen),
        ],
      ],
    );
  }
}

class _Framed extends StatelessWidget {
  const _Framed({required this.title, required this.fill, required this.child});

  final String title;
  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: c.line, width: kCardBorder),
        boxShadow: [
          BoxShadow(
            color: c.line,
            offset: const Offset(kShadowOffset, kShadowOffset),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: fill,
              border: Border(
                bottom: BorderSide(color: c.line, width: kCardBorder),
              ),
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: onAccent, fontWeight: FontWeight.w700),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ChangesCard extends StatelessWidget {
  const _ChangesCard({required this.entry, required this.meId});

  final ActivityEntry entry;
  final int? meId;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final fields = [
      for (final f in fieldLabels.keys)
        if (entry.changedFields.contains(f)) f,
    ];
    final divider = BoxDecoration(
      border: Border(top: BorderSide(color: c.line.withValues(alpha: 0.15))),
    );
    Widget cell(String value, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(value, style: style),
    );
    return _Framed(
      title: 'What changed',
      fill: c.amber,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(92),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        children: [
          TableRow(
            children: [
              cell(''),
              cell('Before', style: text.labelMedium),
              cell('After', style: text.labelMedium),
            ],
          ),
          for (final f in fields)
            TableRow(
              decoration: divider,
              children: [
                cell(
                  fieldLabels[f]!,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                cell(
                  fieldValue(f, entry.before!, meId),
                  style: text.bodyMedium?.copyWith(
                    color: c.negative,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: c.negative,
                  ),
                ),
                cell(
                  fieldValue(f, entry.after!, meId),
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.title,
    required this.fill,
    required this.snapshot,
    required this.meId,
  });

  final String title;
  final Color fill;
  final ExpenseSnapshot snapshot;
  final int? meId;

  @override
  Widget build(BuildContext context) {
    return _Framed(
      title: title,
      fill: fill,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _SnapshotBody(snapshot: snapshot, meId: meId),
      ),
    );
  }
}

class _SnapshotBody extends StatelessWidget {
  const _SnapshotBody({required this.snapshot, required this.meId});

  final ExpenseSnapshot snapshot;
  final int? meId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${s.categoryName} · ${DateFormat('d MMM y').format(s.date)}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              formatRupees(s.paise),
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Paid by ${personName(s.payerName, s.payerId, meId)}',
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          '${splitTypeLabel(s.splitType)}, ${s.shares.length} '
          '${s.shares.length == 1 ? 'person' : 'people'}',
          style: text.bodySmall,
        ),
        const SizedBox(height: 6),
        for (final share in s.shares)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${personName(share.name, share.userId, meId)} · '
              '${formatRupees(share.paise)}',
              style: text.bodyMedium,
            ),
          ),
        if (s.notes != null && s.notes!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(s.notes!, style: text.bodySmall),
        ],
      ],
    );
  }
}

class _BeforeTile extends StatelessWidget {
  const _BeforeTile({required this.snapshot, required this.meId});

  final ExpenseSnapshot snapshot;
  final int? meId;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Material(
      color: c.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kCardRadius),
        side: BorderSide(color: c.line, width: kCardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            'Full expense before the edit',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          iconColor: c.ink,
          collapsedIconColor: c.ink,
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [_SnapshotBody(snapshot: snapshot, meId: meId)],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment, required this.meId});

  final PaymentSnapshot payment;
  final int? meId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = payment;
    final from = personName(p.payerName, p.payerId, meId);
    final to = personName(p.payeeName, p.payeeId, meId);
    return _Framed(
      title: 'The payment',
      fill: context.ez.mint,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'From $from to $to',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  formatRupees(p.paise),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Paid on ${DateFormat('d MMM y').format(p.settledOn)}',
              style: text.bodySmall,
            ),
            if (p.notes != null && p.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(p.notes!, style: text.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
