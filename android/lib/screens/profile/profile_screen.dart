import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';
import '../../state/session.dart';
import '../../state/theme_mode.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_pill.dart';
import '../groups/group_widgets.dart';

String userInitials(User u) => u.initials.isEmpty ? '?' : u.initials;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) {
    // Read before the await: logging out removes this screen.
    final session = ref.read(sessionProvider.notifier);
    return confirmAndRun(
      context,
      title: 'Log out?',
      body: "You'll need to log in again to see your groups.",
      confirmLabel: 'Log out',
      destructive: true,
      action: session.logout,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(sessionProvider).value;
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          children: [
            Text(
              'Profile',
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (user != null)
              BrutalCard(
                color: c.lilac,
                child: Row(
                  children: [
                    Avatar(userInitials(user), Colors.white, size: 64),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName(user),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge?.copyWith(
                              color: onAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(color: onAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _NavRow(
              icon: Symbols.edit,
              label: 'Edit personal details',
              onTap: () => context.go('/profile/details'),
            ),
            const SizedBox(height: 16),
            _NavRow(
              icon: Symbols.person_add,
              label: 'Invite a friend',
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final toast = await showInviteSheet(
                  context,
                  sentMessage: (email) => 'Invite sent to $email.',
                );
                if (toast != null) {
                  messenger.showSnackBar(SnackBar(content: Text(toast)));
                }
              },
            ),
            const SizedBox(height: 16),
            _NavRow(
              icon: Symbols.category,
              label: 'My categories',
              onTap: () => context.go('/profile/categories'),
            ),
            const SizedBox(height: 16),
            BrutalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Symbols.dark_mode, color: c.ink),
                      const SizedBox(width: 8),
                      Text(
                        'Theme',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (label, value) in const [
                        ('Light', ThemeMode.light),
                        ('Dark', ThemeMode.dark),
                        ('System', ThemeMode.system),
                      ])
                        BrutalPill(
                          label: label,
                          selected: mode == value,
                          onTap: () =>
                              ref.read(themeModeProvider.notifier).set(value),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            BrutalButton(
              label: 'Log out',
              icon: Symbols.logout,
              color: c.peach,
              onPressed: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: BrutalCard(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTap),
          child: Row(
            children: [
              Icon(icon, color: c.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Symbols.chevron_right, color: c.ink),
            ],
          ),
        ),
      ),
    );
  }
}
