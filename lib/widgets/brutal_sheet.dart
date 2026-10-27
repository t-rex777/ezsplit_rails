import 'package:flutter/material.dart';

import '../theme/tokens.dart';

Future<T?> showBrutalSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  bool enableDrag = true,
}) {
  final c = context.ez;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    enableDrag: enableDrag,
    useSafeArea: true,
    backgroundColor: c.card,
    barrierColor: c.ink.withValues(alpha: 0.6),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(kSheetRadius),
      ),
      side: BorderSide(color: c.ink, width: kSheetBorder),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: c.ink,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(ctx).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    ),
  );
}
