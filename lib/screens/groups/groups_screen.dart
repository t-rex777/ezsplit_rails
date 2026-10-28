import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';
import '../../state/group_icons.dart';
import '../../data/users_repository.dart';
import '../../state/groups.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_input.dart';
import '../../widgets/brutal_pill.dart';
import '../../widgets/brutal_sheet.dart';
import '../../widgets/money_text.dart';
import 'group_widgets.dart';

enum GroupFilter {
  all('All'),
  owesMe('Owes me'),
  iOwe('I owe');

  const GroupFilter(this.label);
  final String label;
}

enum GroupSort {
  recent('Recent activity'),
  name('Name'),
  amount('Amount');

  const GroupSort(this.label);
  final String label;
}

/// Applies the search, filter and sort. Ties keep the server's order.
List<Group> visibleGroups(
  List<Group> groups, {
  String query = '',
  GroupFilter filter = GroupFilter.all,
  GroupSort sort = GroupSort.recent,
}) {
  final q = query.trim().toLowerCase();
  final indexed = <(int, Group)>[
    for (var i = 0; i < groups.length; i++)
      if ((q.isEmpty || groups[i].name.toLowerCase().contains(q)) &&
          switch (filter) {
            GroupFilter.all => true,
            GroupFilter.owesMe => groups[i].myNetPaise > 0,
            GroupFilter.iOwe => groups[i].myNetPaise < 0,
          })
        (i, groups[i]),
  ];
  int byOrder((int, Group) a, (int, Group) b) => a.$1.compareTo(b.$1);
  indexed.sort((a, b) {
    final cmp = switch (sort) {
      GroupSort.recent => _recent(a.$2, b.$2),
      GroupSort.name => a.$2.name.toLowerCase().compareTo(
        b.$2.name.toLowerCase(),
      ),
      GroupSort.amount => b.$2.myNetPaise.abs().compareTo(
        a.$2.myNetPaise.abs(),
      ),
    };
    return cmp != 0 ? cmp : byOrder(a, b);
  });
  return [for (final e in indexed) e.$2];
}

int _recent(Group a, Group b) {
  final x = a.lastActivityAt;
  final y = b.lastActivityAt;
  if (x == null && y == null) return 0;
  if (x == null) return 1;
  if (y == null) return -1;
  return y.compareTo(x);
}

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  String _query = '';
  GroupFilter _filter = GroupFilter.all;
  GroupSort _sort = GroupSort.recent;

  Future<void> _refresh() async {
    ref.invalidate(groupsProvider);
    ref.invalidate(friendRequestsProvider);
    try {
      await ref.read(groupsProvider.future);
    } catch (_) {
      // The list shows its own error state.
    }
  }

  void _pickSort() {
    showBrutalSheet<void>(
      context,
      title: 'Sort by',
      child: Builder(
        builder: (ctx) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in GroupSort.values)
              BrutalPill(
                label: s.label,
                selected: s == _sort,
                onTap: () {
                  setState(() => _sort = s);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final text = Theme.of(context).textTheme;
    final empty = groups.hasValue && groups.requireValue.isEmpty;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Groups',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!empty)
                    _NewButton(onTap: () => context.push('/groups/new')),
                ],
              ),
              const SizedBox(height: 14),
              if (!empty) ...[
                BrutalInput(
                  hint: 'Search groups',
                  prefix: const Icon(Symbols.search),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in GroupFilter.values)
                            BrutalPill(
                              label: f.label,
                              selected: f == _filter,
                              onTap: () => setState(() => _filter = f),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    BrutalSurface(
                      color: context.ez.card,
                      borderWidth: kPillBorder,
                      radius: 999,
                      shadowOffset: 2,
                      isButton: true,
                      semanticLabel: 'Sort',
                      onTap: _pickSort,
                      constraints: const BoxConstraints(
                        minWidth: kMinTap,
                        minHeight: kMinTap,
                      ),
                      child: const Center(child: Icon(Symbols.swap_vert)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              const _FriendRequests(),
              Expanded(
                child: groups.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: context.ez.ink),
                  ),
                  error: (e, _) => RetryMessage(
                    message: errorMessage(e),
                    onRetry: () => ref.invalidate(groupsProvider),
                  ),
                  data: (all) => RefreshIndicator(
                    onRefresh: _refresh,
                    child: all.isEmpty
                        ? const _EmptyGroups()
                        : _list(
                            visibleGroups(
                              all,
                              query: _query,
                              filter: _filter,
                              sort: _sort,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(List<Group> shown) {
    if (shown.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No groups match.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24, right: 4),
      itemCount: shown.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _GroupRow(group: shown[i]),
    );
  }
}

class _FriendRequests extends ConsumerStatefulWidget {
  const _FriendRequests();

  @override
  ConsumerState<_FriendRequests> createState() => _FriendRequestsState();
}

class _FriendRequestsState extends ConsumerState<_FriendRequests> {
  final Set<int> _busy = {};

  Future<void> _answer(FriendRequest r, {required bool accept}) async {
    final repo = ref.read(usersRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(r.id));
    String message;
    try {
      message = accept
          ? await repo.acceptFriendRequest(r.id)
          : await repo.declineFriendRequest(r.id);
    } catch (e) {
      message = errorMessage(e);
    }
    if (!mounted) return;
    ref.invalidate(friendsProvider);
    ref.invalidate(friendRequestsProvider);
    try {
      await ref.read(friendRequestsProvider.future);
    } catch (_) {
      // The section stays hidden when the list cannot load.
    }
    if (!mounted) return;
    setState(() => _busy.remove(r.id));
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(friendRequestsProvider).value ?? const [];
    if (requests.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Friend requests',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in requests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, right: 4),
                      child: BrutalCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              r.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: BrutalButton(
                                    label: 'Accept',
                                    color: context.ez.green,
                                    onPressed: _busy.contains(r.id)
                                        ? null
                                        : () => _answer(r, accept: true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: BrutalButton(
                                    label: 'Decline',
                                    color: context.ez.peach,
                                    onPressed: _busy.contains(r.id)
                                        ? null
                                        : () => _answer(r, accept: false),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewButton extends StatelessWidget {
  const _NewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BrutalSurface(
      color: context.ez.green,
      borderWidth: kPillBorder,
      radius: 999,
      shadowOffset: 3,
      isButton: true,
      semanticLabel: 'New group',
      onTap: onTap,
      constraints: const BoxConstraints(minHeight: kMinTap, minWidth: kMinTap),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.add, color: onAccent),
          const SizedBox(width: 4),
          Text(
            'New',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: onAccent, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _GroupRow extends ConsumerWidget {
  const _GroupRow({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final me = ref.watch(sessionProvider).value;
    final icon =
        ref.watch(groupIconProvider(group.id)).value ?? defaultGroupIcon;
    final tint = tintFor(context, group.id);
    final justTwo = group.members.length == 2;
    final other = justTwo
        ? group.members.where((m) => m.id != me?.id).firstOrNull
        : null;
    return BrutalCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push('/groups/${group.id}'),
      child: Row(
        children: [
          if (other != null)
            Avatar(userName(other)[0].toUpperCase(), tint, size: 44)
          else
            IconTile(icon: icon, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  key: const ValueKey('group-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  justTwo
                      ? 'just you two'
                      : '${group.members.length} ${group.members.length == 1 ? 'member' : 'members'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Balance(paise: group.myNetPaise),
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({required this.paise});

  final int paise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (paise == 0) {
      return Text(
        'settled',
        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MoneyText(paise, style: MoneyStyle.signed),
        Text(paise > 0 ? 'owes you' : 'you owe', style: text.bodySmall),
      ],
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups();

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 48),
      children: [
        Center(
          child: Transform.rotate(
            angle: 0.05,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: c.mint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.ink, width: kSheetBorder),
                boxShadow: [
                  BoxShadow(offset: const Offset(6, 6), color: c.ink),
                ],
              ),
              child: const Icon(Symbols.groups, size: 72, color: onAccent),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Start your first group',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              'Add a trip, your flatmates, or just one friend. Then split anything inside it.',
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: BrutalButton(
            label: 'New group',
            icon: Symbols.add,
            onPressed: () => context.push('/groups/new'),
          ),
        ),
      ],
    );
  }
}
