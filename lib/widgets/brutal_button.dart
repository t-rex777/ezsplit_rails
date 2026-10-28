import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'brutal_card.dart';

class BrutalButton extends StatelessWidget {
  const BrutalButton({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  /// Null disables the button: grey fill, no shadow, ink text.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final enabled = onPressed != null;
    final fill = enabled ? (color ?? c.amber) : EzColors.disabled;
    // The card fill is dark in dark mode, so it needs ink text; accents stay dark-on-light.
    final textColor = fill == c.card ? c.ink : onAccent;
    return BrutalSurface(
      color: fill,
      borderWidth: kCardBorder,
      radius: kCardRadius,
      showShadow: enabled,
      isButton: true,
      onTap: onPressed,
      semanticLabel: label,
      constraints: const BoxConstraints(minHeight: 48, minWidth: kMinTap),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
