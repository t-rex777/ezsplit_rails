import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/money.dart';
import '../../state/expense_form.dart' show SplitMode;
import '../../state/quick_actions.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_sheet.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/confirm_sheet.dart';

const double _tileWidth = 124;
const double _tileHeight = 132;

/// Saved expenses on the dashboard. A tap opens the add form filled in;
/// holding a tile offers edit and delete.
class QuickActionsSection extends ConsumerWidget {
  const QuickActionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(quickActionsProvider).value;
    if (actions == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final c = context.ez;
    final fills = [c.amber, c.lilac, c.mint, c.peach];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'Quick actions',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (actions.isNotEmpty)
              Text('Hold one to edit', style: text.bodySmall),
          ],
        ),
        const SizedBox(height: 10),
        if (actions.isEmpty)
          const _EmptyCard()
        else
          SizedBox(
            // Room for the tile shadow below the tiles.
            height: _tileHeight + 6,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: actions.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => i == 0
                  ? const _NewTile()
                  : _Tile(
                      action: actions[i - 1],
                      color: fills[(i - 1) % fills.length],
                    ),
            ),
          ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    return BrutalSurface(
      color: c.bg,
      borderWidth: kCardBorder,
      radius: 12,
      showShadow: false,
      isButton: true,
      semanticLabel: 'Add a quick action',
      onTap: () => context.push('/home/quick/new'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.amber,
              shape: BoxShape.circle,
              border: Border.all(color: c.line, width: kPillBorder),
            ),
            child: const Icon(Symbols.bolt, color: onAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a quick action',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Save an expense you add often, like rent. Then add it in '
                  'one tap.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewTile extends StatelessWidget {
  const _NewTile();

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return BrutalSurface(
      color: c.bg,
      borderWidth: kCardBorder,
      radius: 12,
      showShadow: false,
      isButton: true,
      semanticLabel: 'New quick action',
      onTap: () => context.push('/home/quick/new'),
      constraints: const BoxConstraints.tightFor(
        width: 64,
        height: _tileHeight,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.add, size: 28, color: c.ink),
          const SizedBox(height: 6),
          Text(
            'New',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

String quickActionSubtitle(QuickAction a) => a.groupId == null
    ? a.groupName
    : '${a.groupName} · ${SplitMode.of(a.splitType).label}';

class _Tile extends ConsumerWidget {
  const _Tile({required this.action, required this.color});

  final QuickAction action;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = action;
    final text = Theme.of(context).textTheme;
    final onText = text.bodySmall?.copyWith(color: onAccent);
    return GestureDetector(
      onLongPress: () => _showOptions(context, ref, a),
      child: BrutalSurface(
        color: color,
        borderWidth: kCardBorder,
        radius: 12,
        shadowOffset: 4,
        isButton: true,
        semanticLabel:
            '${a.name}, ${formatRupees(a.paise)}, ${quickActionSubtitle(a)}',
        onTap: () => context.push('/home/quick/${a.id}'),
        constraints: const BoxConstraints.tightFor(
          width: _tileWidth,
          height: _tileHeight,
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.ez.line, width: kPillBorder),
              ),
              child: CategoryIcon(a.categoryIcon, onAccent, size: 22),
            ),
            const Spacer(),
            Text(
              a.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyLarge?.copyWith(
                color: onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupees(a.paise),
                softWrap: false,
                style: text.titleLarge?.copyWith(
                  color: onAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              quickActionSubtitle(a),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: onText,
            ),
          ],
        ),
      ),
    );
  }
}

enum _Option { add, edit, delete }

Future<void> _showOptions(
  BuildContext context,
  WidgetRef ref,
  QuickAction a,
) async {
  final c = context.ez;
  final picked = await showBrutalSheet<_Option>(
    context,
    title: a.name,
    child: Builder(
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${formatRupees(a.paise)} · ${quickActionSubtitle(a)}',
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          BrutalButton(
            label: 'Add expense',
            icon: Symbols.add,
            color: c.green,
            onPressed: () => Navigator.of(ctx).pop(_Option.add),
          ),
          const SizedBox(height: 12),
          BrutalButton(
            label: 'Edit quick action',
            icon: Symbols.edit,
            color: c.card,
            onPressed: () => Navigator.of(ctx).pop(_Option.edit),
          ),
          const SizedBox(height: 12),
          BrutalButton(
            label: 'Delete quick action',
            icon: Symbols.delete,
            color: c.peach,
            onPressed: () => Navigator.of(ctx).pop(_Option.delete),
          ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  switch (picked) {
    case _Option.add:
      context.push('/home/quick/${a.id}');
    case _Option.edit:
      context.push('/home/quick/${a.id}/edit');
    case _Option.delete:
      final ok = await confirmSheet(
        context,
        title: 'Delete ${a.name}?',
        body:
            'This removes the quick action from this phone. Expenses you '
            'already added stay.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (ok) await ref.read(quickActionsProvider.notifier).remove(a.id);
  }
}
