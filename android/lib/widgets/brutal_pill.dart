import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'brutal_card.dart';

class BrutalPill extends StatelessWidget {
  const BrutalPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Fill used when selected. Defaults to ink, with bg text.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Semantics(
      selected: selected,
      child: BrutalSurface(
        color: selected ? (color ?? c.ink) : c.card,
        borderWidth: kPillBorder,
        radius: 999,
        shadowOffset: 2,
        isButton: true,
        onTap: onTap,
        semanticLabel: label,
        constraints: const BoxConstraints(
          minHeight: kMinTap,
          minWidth: kMinTap,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: !selected ? c.ink : (color == null ? c.bg : onAccent),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
