import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/offline.dart';
import '../theme/tokens.dart';

const offlineMessage = "You're offline. Changes won't save.";

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(offlineProvider);
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: navigationShell),
          if (offline) const _OfflineBanner(),
          _TabBar(
            index: navigationShell.currentIndex,
            onSelect: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: c.peach,
          border: Border(
            top: BorderSide(color: c.ink, width: kCardBorder),
          ),
        ),
        child: Row(
          children: [
            const Icon(Symbols.cloud_off, size: 20, color: onAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                offlineMessage,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: onAccent, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _tabs = [
  _Tab('Home', Symbols.home),
  _Tab('Groups', Symbols.group),
  _Tab('Activity', Symbols.history),
  _Tab('Profile', Symbols.person),
];

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        10,
        8,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          top: BorderSide(color: c.ink, width: kSheetBorder),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: Center(
                child: _TabItem(
                  tab: _tabs[i],
                  active: i == index,
                  onTap: () => onSelect(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final radius = BorderRadius.circular(10);
    // Inactive tabs read against the card fill, so they keep the screen ink;
    // the active tab sits on amber and uses the fixed dark ink.
    final color = active ? onAccent : c.ink;
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: active ? c.amber : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: active ? c.ink : Colors.transparent,
            width: kPillBorder,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: kMinTap + 20,
              minHeight: kMinTap,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 24, fill: active ? 1 : 0, color: color),
                  const SizedBox(height: 2),
                  // Large text scales down to fit instead of overflowing.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
