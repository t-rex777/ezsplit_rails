import 'package:flutter/material.dart';

import '../../data/api_error.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_card.dart';

String messageFor(Object error) =>
    error is ApiError ? error.message : 'Something went wrong. Try again.';

/// A card with an icon and a line of text, for errors and confirmations.
class AuthNotice extends StatelessWidget {
  const AuthNotice({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: BrutalCard(
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: onAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.bodyLarge?.copyWith(
                      color: onAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (body != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        body!,
                        style: text.bodyMedium?.copyWith(color: onAccent),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The show/hide toggle at the end of a password field.
class PasswordToggle extends StatelessWidget {
  const PasswordToggle({
    super.key,
    required this.hidden,
    required this.onPressed,
  });

  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: hidden ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: kMinTap, minHeight: kMinTap),
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: context.ez.ink,
      ),
    );
  }
}
