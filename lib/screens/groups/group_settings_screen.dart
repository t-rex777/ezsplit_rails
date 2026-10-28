import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/groups_repository.dart';
import '../../data/models.dart';
import '../../state/group_icons.dart';
import '../../state/groups.dart';
import '../../state/session.dart';
import '../../state/summary.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_input.dart';
import '../../widgets/brutal_pill.dart';
import '../../widgets/brutal_sheet.dart';
import 'group_widgets.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});

  final int groupId;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _busy = false;
  String? _error;

  int get _id => widget.groupId;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/groups/$_id');
    }
  }

  /// Runs [action], shows the server's message if it fails, and tells the
  /// caller whether it worked.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) setState(() => _busy = false);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(e);
        });
      }
      return false;
    }
  }

  Future<int> _membershipId(int userId) async {
    final all = await ref.read(groupsRepositoryProvider).memberships(_id);
    return all.firstWhere((m) => m.userId == userId).id;
  }

  Future<void> _leave(User me) async {
    final ok = await confirmSheet(
      context,
      title: 'Leave this group?',
      body: "You won't see its expenses any more.",
      confirmLabel: 'Yes, leave',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(groupsRepositoryProvider);
    final router = GoRouter.maybeOf(context);
    final left = await _run(
      () async => repo.removeMember(_id, await _membershipId(me.id)),
    );
    if (!left || !mounted) return;
    ref.invalidate(groupsProvider);
    invalidateMonthlySummaries(ref.invalidate);
    router?.go('/groups');
  }

  Future<void> _delete() async {
    final ok = await confirmSheet(
      context,
      title: 'Delete this group?',
      body: 'This removes the group and its expenses for everyone.',
      confirmLabel: 'Yes, delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(groupsRepositoryProvider);
    final router = GoRouter.maybeOf(context);
    final deleted = await _run(() => repo.delete(_id));
    if (!deleted || !mounted) return;
    ref.invalidate(groupsProvider);
    invalidateMonthlySummaries(ref.invalidate);
    router?.go('/groups');
  }

  Future<void> _remove(User member) async {
    final ok = await confirmSheet(
      context,
      title: 'Remove ${userName(member)}?',
      body: '${userName(member)} will no longer be in this group.',
      confirmLabel: 'Yes, remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(groupsRepositoryProvider);
    final removed = await _run(
      () async => repo.removeMember(_id, await _membershipId(member.id)),
    );
    if (!removed || !mounted) return;
    ref.invalidate(groupProvider(_id));
    ref.invalidate(groupsProvider);
  }

  Future<void> _add(Group group) async {
    final added = await showBrutalSheet<bool>(
      context,
      title: 'Add people',
      child: _AddPeople(group: group),
    );
    if (added == true && mounted) {
      ref.invalidate(groupProvider(_id));
      ref.invalidate(groupsProvider);
    }
  }

  Future<void> _edit(Group group) async {
    final saved = await showBrutalSheet<bool>(
      context,
      title: 'Edit group',
      child: _EditGroup(group: group),
    );
    if (saved == true && mounted) {
      ref.invalidate(groupProvider(_id));
      ref.invalidate(groupsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupProvider(_id));
    final me = ref.watch(sessionProvider).value;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    constraints: const BoxConstraints(
                      minWidth: kMinTap,
                      minHeight: kMinTap,
                    ),
                    onPressed: _back,
                    icon: const Icon(Symbols.arrow_back),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Group settings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: group.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: context.ez.ink),
                  ),
                  error: (e, _) => RetryMessage(
                    message: errorMessage(e),
                    onRetry: () => ref.invalidate(groupProvider(_id)),
                  ),
                  data: (g) => _content(g, me),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(Group group, User? me) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final isOwner = me != null && group.ownerId == me.id;
    final owner = group.members.where((m) => m.id == group.ownerId).firstOrNull;
    final icon = ref.watch(groupIconProvider(_id)).value ?? defaultGroupIcon;
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 24, right: 4),
      children: [
        BrutalCard(
          color: tintFor(context, group.id),
          child: Row(
            children: [
              IconTile(icon: icon, color: Colors.white, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onAccent,
                      ),
                    ),
                    Text(
                      isOwner
                          ? 'Created by you'
                          : owner == null
                          ? 'Created by someone else'
                          : 'Created by ${userName(owner)}',
                      style: text.bodySmall?.copyWith(color: onAccent),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  tooltip: 'Edit group',
                  constraints: const BoxConstraints(
                    minWidth: kMinTap,
                    minHeight: kMinTap,
                  ),
                  color: onAccent,
                  onPressed: () => _edit(group),
                  icon: const Icon(Symbols.edit),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Members (${group.members.length})',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            BrutalSurface(
              color: c.green,
              borderWidth: kPillBorder,
              radius: 999,
              shadowOffset: 3,
              isButton: true,
              semanticLabel: 'Add',
              onTap: () => _add(group),
              constraints: const BoxConstraints(
                minHeight: kMinTap,
                minWidth: kMinTap,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Symbols.person_add, size: 18, color: onAccent),
                  const SizedBox(width: 6),
                  Text(
                    'Add',
                    style: text.labelLarge?.copyWith(
                      color: onAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BrutalCard(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < group.members.length; i++)
                _MemberRow(
                  member: group.members[i],
                  isMe: group.members[i].id == me?.id,
                  isAdmin: group.members[i].id == group.ownerId,
                  canRemove:
                      isOwner && group.members[i].id != group.ownerId && !_busy,
                  divider: i > 0,
                  onRemove: () => _remove(group.members[i]),
                ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: c.negative,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (!isOwner && me != null)
          BrutalButton(
            label: 'Leave group',
            icon: Symbols.logout,
            color: c.card,
            onPressed: _busy ? null : () => _leave(me),
          ),
        if (isOwner)
          BrutalButton(
            label: 'Delete group',
            icon: Symbols.delete,
            color: c.peach,
            onPressed: _busy ? null : _delete,
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.isAdmin,
    required this.canRemove,
    required this.divider,
    required this.onRemove,
  });

  final User member;
  final bool isMe;
  final bool isAdmin;
  final bool canRemove;
  final bool divider;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: c.line, width: 2))
            : null,
      ),
      child: Row(
        children: [
          Avatar(
            userName(member)[0].toUpperCase(),
            tintFor(context, member.id),
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? 'You' : fullName(member),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            const BrutalPill(label: 'admin'),
          ],
          if (canRemove)
            IconButton(
              tooltip: '${userName(member)} options',
              constraints: const BoxConstraints(
                minWidth: kMinTap,
                minHeight: kMinTap,
              ),
              onPressed: onRemove,
              icon: const Icon(Symbols.more_vert),
            ),
        ],
      ),
    );
  }
}

/// Friends who are not in the group yet; adds the picked ones.
class _AddPeople extends ConsumerStatefulWidget {
  const _AddPeople({required this.group});

  final Group group;

  @override
  ConsumerState<_AddPeople> createState() => _AddPeopleState();
}

class _AddPeopleState extends ConsumerState<_AddPeople> {
  final Set<int> _picked = {};
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final repo = ref.read(groupsRepositoryProvider);
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await repo.addMembers(widget.group.id, _picked.toList());
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    return friends.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => RetryMessage(
        message: errorMessage(e),
        onRetry: () => ref.invalidate(friendsProvider),
      ),
      data: (all) {
        final candidates = [
          for (final f in all)
            if (!widget.group.members.any((m) => m.id == f.id)) f,
        ];
        if (candidates.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'All your friends are already in this group.',
              style: text.bodyLarge,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final f in candidates)
              CheckboxListTile(
                value: _picked.contains(f.id),
                activeColor: c.ink,
                checkColor: c.bg,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.trailing,
                title: Text(
                  fullName(f),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: Avatar(
                  userName(f)[0].toUpperCase(),
                  tintFor(context, f.id),
                  size: 38,
                ),
                onChanged: (v) => setState(() {
                  v == true ? _picked.add(f.id) : _picked.remove(f.id);
                }),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: text.bodyMedium?.copyWith(color: c.negative),
              ),
            ],
            const SizedBox(height: 16),
            BrutalButton(
              label: _picked.isEmpty
                  ? 'Add'
                  : 'Add ${_picked.length} ${_picked.length == 1 ? 'person' : 'people'}',
              color: c.green,
              onPressed: _picked.isEmpty || _saving ? null : _save,
            ),
          ],
        );
      },
    );
  }
}

class _EditGroup extends ConsumerStatefulWidget {
  const _EditGroup({required this.group});

  final Group group;

  @override
  ConsumerState<_EditGroup> createState() => _EditGroupState();
}

class _EditGroupState extends ConsumerState<_EditGroup> {
  late final _name = TextEditingController(text: widget.group.name);
  late final _description = TextEditingController(
    text: widget.group.description ?? '',
  );
  late String _icon =
      ref.read(groupIconProvider(widget.group.id)).value ?? defaultGroupIcon;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(groupsRepositoryProvider);
    final icon = ref.read(groupIconProvider(widget.group.id).notifier);
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await repo.update(
        widget.group.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
      );
      await icon.set(_icon);
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupIconPicker(
          selected: _icon,
          onChanged: (v) => setState(() => _icon = v),
        ),
        const SizedBox(height: 16),
        BrutalInput(
          label: 'Group name',
          controller: _name,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        BrutalInput(
          label: 'Description',
          hint: 'Optional',
          controller: _description,
          errorText: _error,
        ),
        const SizedBox(height: 16),
        BrutalButton(
          label: 'Save',
          color: c.green,
          onPressed: _name.text.trim().isEmpty || _saving ? null : _save,
        ),
      ],
    );
  }
}
