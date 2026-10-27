import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class Avatar extends StatelessWidget {
  const Avatar(this.initials, this.color, {super.key, this.size = 40});

  final String initials;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: c.ink, width: kPillBorder),
      ),
      child: Text(
        initials,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFF111111),
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}
