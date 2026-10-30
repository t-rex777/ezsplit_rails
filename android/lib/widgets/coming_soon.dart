import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'brutal_card.dart';
import 'brutal_pill.dart';

class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    required this.tile,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color tile;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BrutalCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(kCardRadius),
                  border: Border.all(color: context.ez.line, width: kCardBorder),
                ),
                child: Icon(icon, size: 32, color: onAccent),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(body, textAlign: TextAlign.center, style: text.bodyMedium),
              const SizedBox(height: 16),
              BrutalPill(
                label: 'Coming soon',
                selected: true,
                color: context.ez.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
