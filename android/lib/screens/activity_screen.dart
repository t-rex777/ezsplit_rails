import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/activities_repository.dart';
import '../data/models.dart';
import '../state/activity.dart';
import '../state/groups.dart';
import '../state/session.dart';
import '../state/summary.dart';
import '../theme/tokens.dart';
import '../widgets/brutal_pill.dart';
import 'activity/activity_row.dart';
import 'activity/activity_sheet.dart';
import 'activity/activity_text.dart';
import 'groups/group_widgets.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  ActivityFilter _filter = const AllActivity();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final chips = <(String, ActivityFilter)>[
      ('All groups', const AllActivity()),
      for (final g in groups) (g.name, GroupActivity(g.id)),
      ('Friends', const FriendActivity()),
    ];
    final scope = switch (_filter) {
      GroupActivity(:final groupId) =>
        groups.where((g) => g.id == groupId).firstOrNull?.name ?? 'this group',
      FriendActivity() => 'your friend expenses',
      AllActivity() => 'your groups',
    };
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                'Activity',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              height: kMinTap + 6,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Align(
                  alignment: Alignment.topCenter,
                  child: BrutalPill(
                    label: chips[i].$1,
                    selected: chips[i].$2 == _filter,
                    onTap: () => setState(() => _filter = chips[i].$2),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _Feed(filter: _filter, scope: scope),
            ),
          ],
        ),
      ),
    );
  }
}

sealed class _Item {}

class _Header extends _Item {
  _Header(this.label);
  final String label;
}

class _Entry extends _Item {
  _Entry(this.entry);
  final ActivityEntry entry;
}

class _More extends _Item {}

class _Feed extends ConsumerWidget {
  const _Feed({required this.filter, required this.scope});

  final ActivityFilter filter;
  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(activityFeedProvider(filter));
    final meId = ref.watch(sessionProvider).value?.id;
    final now = ref.watch(nowProvider);
    Future<void> refresh() => ref.refresh(activityFeedProvider(filter).future);

    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => RetryMessage(
        message: errorMessage(e),
        onRetry: () => ref.invalidate(activityFeedProvider(filter)),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(children: [_Empty(scope: scope)]),
          );
        }
        final items = <_Item>[];
        String? lastDay;
        for (final e in state.items) {
          final day = dayLabel(e.at, now);
          if (day != lastDay) items.add(_Header(day));
          lastDay = day;
          items.add(_Entry(e));
        }
        if (state.nextPage != null) items.add(_More());
        final deleted = state.deletedExpenseIds;

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 20, 24),
            itemCount: items.length,
            itemBuilder: (context, i) => switch (items[i]) {
              _Header(:final label) => Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _Entry(:final entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ActivityRow(
                  entry: entry,
                  meId: meId,
                  onTap: () => showActivitySheet(
                    context,
                    entry: entry,
                    meId: meId,
                    now: now,
                    canOpen:
                        entry.action != ActivityAction.deleted &&
                        entry.action != ActivityAction.settled &&
                        !deleted.contains(entry.expenseId),
                  ),
                ),
              ),
              _More() => _MoreFooter(
                failed: state.moreFailed,
                onMore: () =>
                    ref.read(activityFeedProvider(filter).notifier).loadMore(),
              ),
            },
          ),
        );
      },
    );
  }
}

/// Building this row means the user is near the bottom, so it asks for the
/// next page. After a failure it waits for a tap instead of retrying alone.
class _MoreFooter extends StatefulWidget {
  const _MoreFooter({required this.failed, required this.onMore});

  final bool failed;
  final VoidCallback onMore;

  @override
  State<_MoreFooter> createState() => _MoreFooterState();
}

class _MoreFooterState extends State<_MoreFooter> {
  @override
  void initState() {
    super.initState();
    if (!widget.failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: widget.failed
            ? TextButton(
                onPressed: widget.onMore,
                child: const Text("Couldn't load more. Tap to try again."),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.scope});

  final String scope;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: c.lilac,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.line, width: kCardBorder),
              boxShadow: [
                BoxShadow(
                  color: c.line,
                  offset: const Offset(kShadowOffset, kShadowOffset),
                ),
              ],
            ),
            child: const Icon(Symbols.history, size: 44, color: onAccent),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing here yet',
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'When anyone in $scope adds, edits, or deletes an expense, it shows up here.',
            textAlign: TextAlign.center,
            style: text.bodyLarge,
          ),
        ],
      ),
    );
  }
}
