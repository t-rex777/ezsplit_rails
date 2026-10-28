import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/groups_repository.dart';
import '../../data/models.dart';
import '../../state/group_icons.dart';
import '../../state/groups.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_input.dart';
import 'group_widgets.dart';

class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _search = TextEditingController();
  final List<User> _picked = [];
  String _icon = defaultGroupIcon;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _canCreate => _name.text.trim().isNotEmpty && !_saving;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/groups');
    }
  }

  Future<void> _invite() async {
    final toast = await showInviteSheet(context);
    if (toast == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  Future<void> _create() async {
    final repo = ref.read(groupsRepositoryProvider);
    final router = GoRouter.maybeOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final icon = _icon;
    final description = _description.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    final Group group;
    try {
      group = await repo.create(
        _name.text.trim(),
        description.isEmpty ? null : description,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(e);
      });
      return;
    }
    // The group exists now, so a failure below must not offer a second create.
    final iconNotifier = ref.read(groupIconProvider(group.id).notifier);
    await iconNotifier.set(icon);
    String? addFailure;
    if (_picked.isNotEmpty) {
      try {
        await repo.addMembers(group.id, [for (final u in _picked) u.id]);
      } catch (e) {
        addFailure = errorMessage(e);
      }
    }
    if (!mounted) return;
    ref.invalidate(groupsProvider);
    if (addFailure != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text("Group created. Couldn't add people: $addFailure"),
        ),
      );
    }
    router?.go('/groups/${group.id}');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.ez;
    final friends = ref.watch(friendsProvider);
    final query = _search.text.trim().toLowerCase();
    final suggestions = friends.maybeWhen(
      data: (all) => [
        for (final f in all)
          if (!_picked.any((p) => p.id == f.id) &&
              (query.isEmpty ||
                  fullName(f).toLowerCase().contains(query) ||
                  f.email.toLowerCase().contains(query)))
            f,
      ].take(5).toList(),
      orElse: () => const <User>[],
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        constraints: const BoxConstraints(
                          minWidth: kMinTap,
                          minHeight: kMinTap,
                        ),
                        onPressed: _close,
                        icon: const Icon(Symbols.close),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'New group',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GroupIconPicker(
                    selected: _icon,
                    onChanged: (v) => setState(() => _icon = v),
                  ),
                  const SizedBox(height: 16),
                  BrutalInput(
                    label: 'Group name',
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  BrutalInput(
                    label: 'Description',
                    hint: 'Optional',
                    controller: _description,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  BrutalInput(
                    label: 'Add people',
                    hint: 'Name or email',
                    prefix: const Icon(Symbols.search),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_picked.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final u in _picked)
                          _PersonChip(
                            user: u,
                            onRemove: () => setState(() => _picked.remove(u)),
                          ),
                      ],
                    ),
                  ],
                  if (friends.hasError) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Couldn't load your friends.",
                      style: text.bodyMedium?.copyWith(color: c.negative),
                    ),
                  ],
                  for (final f in suggestions)
                    InkWell(
                      onTap: () => setState(() {
                        _picked.add(f);
                        _search.clear();
                      }),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: kMinTap),
                        child: Row(
                          children: [
                            Avatar(
                              userName(f)[0].toUpperCase(),
                              tintFor(context, f.id),
                              size: 32,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                fullName(f),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Symbols.add),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _DashedButton(
                    label: 'Not on ezsplit? Invite by email',
                    onTap: _invite,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: text.bodyMedium?.copyWith(
                          color: c.negative,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  BrutalButton(
                    label: 'Create group',
                    color: c.green,
                    onPressed: _canCreate ? _create : null,
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

class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.user, required this.onRemove});

  final User user;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return BrutalSurface(
      color: tintFor(context, user.id),
      borderWidth: kPillBorder,
      radius: 999,
      shadowOffset: 2,
      isButton: true,
      semanticLabel: 'Remove ${userName(user)}',
      onTap: onRemove,
      constraints: const BoxConstraints(minHeight: kMinTap),
      padding: const EdgeInsets.only(left: 14, right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              userName(user),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: onAccent, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Symbols.close, size: 16, color: onAccent),
        ],
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(kCardRadius),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorder(context.ez.line),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTap),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Symbols.mail),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = kCardBorder;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(kCardRadius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 8), paint);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
