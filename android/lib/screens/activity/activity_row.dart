import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';
import '../../domain/money.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_card.dart';
import '../groups/group_widgets.dart';
import 'activity_text.dart';

/// The actor's avatar with a small badge for what they did.
class ActorBadge extends StatelessWidget {
  const ActorBadge({super.key, required this.entry, this.size = 44});

  final ActivityEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final (IconData icon, Color fill) = switch (entry.action) {
      ActivityAction.created => (Symbols.add, c.green),
      ActivityAction.updated => (Symbols.edit, c.amber),
      ActivityAction.deleted => (Symbols.delete, c.peach),
      ActivityAction.settled => (Symbols.payments, c.mint),
    };
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          Avatar(
            initialsOf(entry.actorName),
            tintFor(context, entry.actorId),
            size: size,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: c.line, width: kPillBorder),
              ),
              child: Icon(icon, size: 14, color: onAccent, weight: 700),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Riya edited Beach dinner" with the names in bold.
class ActivitySentence extends StatelessWidget {
  const ActivitySentence({
    super.key,
    required this.entry,
    required this.meId,
    this.style,
  });

  final ActivityEntry entry;
  final int? meId;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    const bold = TextStyle(fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: personName(entry.actorName, entry.actorId, meId),
            style: bold,
          ),
          TextSpan(text: ' ${verbFor(entry.action)} '),
          TextSpan(text: objectOf(entry, meId), style: bold),
        ],
      ),
    );
  }
}

class GroupTag extends StatelessWidget {
  const GroupTag({super.key, required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final id = entry.groupId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: id == null ? c.card : tintFor(context, id),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.line, width: 1.5),
      ),
      child: Text(
        entry.groupName ?? 'No group',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: id == null ? c.ink : onAccent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.entry,
    required this.meId,
    required this.onTap,
  });

  final ActivityEntry entry;
  final int? meId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BrutalCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ActorBadge(entry: entry),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ActivitySentence(
                  entry: entry,
                  meId: meId,
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(child: GroupTag(entry: entry)),
                    const SizedBox(width: 6),
                    Text(timeLabel(entry.at), style: text.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Amount(entry: entry),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final struck = text.bodySmall?.copyWith(
      color: c.negative,
      decoration: TextDecoration.lineThrough,
      decorationColor: c.negative,
    );
    final strong = text.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final before = entry.before;
    final after = entry.after;
    if (entry.action == ActivityAction.deleted) {
      return Text(
        formatRupees(entry.subjectPaise),
        style: strong?.copyWith(
          color: c.negative,
          decoration: TextDecoration.lineThrough,
          decorationColor: c.negative,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (before != null && after != null && before.paise != after.paise)
          Text(formatRupees(before.paise), style: struck),
        Text(formatRupees(entry.subjectPaise), style: strong),
      ],
    );
  }
}
