import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shown while the saved session loads on a cold start. The tile repeats the
/// launcher icon so the hand-off from Android's own splash looks continuous.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Loading EzSplit',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: c.lilac,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: c.line, width: kSheetBorder),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(kShadowOffset, kShadowOffset),
                      color: c.line,
                    ),
                  ],
                ),
                child: Image.asset('assets/brand/receipt.png'),
              ),
              const SizedBox(height: 20),
              Text(
                'EzSplit',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.line, width: kCardBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    color: c.amber,
                    backgroundColor: c.card,
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
