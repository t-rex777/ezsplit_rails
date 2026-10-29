import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/api_error.dart';
import '../../data/models.dart';
import '../../data/users_repository.dart';
import '../../state/group_icons.dart';
import '../../state/groups.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_input.dart';
import '../../widgets/brutal_sheet.dart';
import '../../widgets/category_icon.dart';

export '../../widgets/confirm_sheet.dart';

/// How a person is shown: first name, or the start of their email.
String userName(User u) =>
    u.firstName.isNotEmpty ? u.firstName : u.email.split('@').first;

String fullName(User u) {
  final full = '${u.firstName} ${u.lastName}'.trim();
  return full.isEmpty ? u.email : full;
}

/// A person on a balance row: first name, else last name.
String balanceName(BalanceRow r) {
  if (r.firstName.isNotEmpty) return r.firstName;
  return r.lastName.isNotEmpty ? r.lastName : 'Member';
}

String balanceInitials(BalanceRow r) {
  final f = r.firstName.isEmpty ? '' : r.firstName[0];
  final l = r.lastName.isEmpty ? '' : r.lastName[0];
  final both = (f + l).toUpperCase();
  return both.isEmpty ? '?' : both;
}

/// "#5DCAA5" to a colour; [fallback] when the server sends something else.
Color parseHexColor(String hex, Color fallback) {
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex.trim());
  if (m == null) return fallback;
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

/// The server's message for an ApiError, shown as is.
String errorMessage(Object error) =>
    error is ApiError ? error.message : 'Something went wrong. Try again.';

/// A stable accent for a group or person, so the same one always looks the same.
Color tintFor(BuildContext context, int id) {
  final c = context.ez;
  final tints = [c.amber, c.mint, c.lilac, c.peach, c.green];
  return tints[id.abs() % tints.length];
}

class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final String icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size > 48 ? kCardRadius : 10),
        border: Border.all(color: context.ez.line, width: kCardBorder),
      ),
      child: Center(child: CategoryIcon(icon, onAccent)),
    );
  }
}

class GroupIconPicker extends StatelessWidget {
  const GroupIconPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final name in groupIconChoices)
          BrutalSurface(
            color: name == selected ? c.amber : c.card,
            borderWidth: kCardBorder,
            radius: kCardRadius,
            shadowOffset: 3,
            showShadow: name == selected,
            isButton: true,
            semanticLabel: 'Icon ${name.replaceAll('_', ' ')}',
            onTap: () => onChanged(name),
            constraints: const BoxConstraints.tightFor(width: 52, height: 52),
            child: Center(
              child: CategoryIcon(name, name == selected ? onAccent : c.ink),
            ),
          ),
      ],
    );
  }
}

/// Sends a friend invite. Returns the toast to show, or null if dismissed.
/// An invite only makes the person a friend; it never adds them to a group.
/// [sentMessage] words the toast for a new invite; the default suits New group.
/// [onShowQr] adds a "Show QR code" button that closes this sheet and calls it.
Future<String?> showInviteSheet(
  BuildContext context, {
  String Function(String email)? sentMessage,
  VoidCallback? onShowQr,
}) => showBrutalSheet<String>(
  context,
  title: 'Invite by email',
  child: _InviteForm(
    sentMessage: sentMessage ?? _groupSentMessage,
    onShowQr: onShowQr,
  ),
);

String _groupSentMessage(String email) =>
    'Invite sent. Add ${email.split('@').first} to the group once they join.';

class _InviteForm extends ConsumerStatefulWidget {
  const _InviteForm({required this.sentMessage, this.onShowQr});

  final String Function(String email) sentMessage;
  final VoidCallback? onShowQr;

  @override
  ConsumerState<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends ConsumerState<_InviteForm> {
  final _email = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _valid {
    final e = _email.text.trim();
    return e.contains('@') && !e.startsWith('@') && !e.endsWith('@');
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    final usersRepository = ref.read(usersRepositoryProvider);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await usersRepository.invite(email);
      if (!mounted) return;
      ref.invalidate(friendsProvider);
      final already = message.toLowerCase().contains('already a friend');
      Navigator.of(context).pop(already ? message : widget.sentMessage(email));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrutalInput(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          errorText: _error,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 16),
        BrutalButton(
          label: 'Send invite',
          icon: Symbols.mail,
          onPressed: _valid && !_sending ? _send : null,
        ),
        if (widget.onShowQr case final onShowQr?) ...[
          const SizedBox(height: 12),
          BrutalButton(
            label: 'Show QR code',
            icon: Symbols.qr_code_2,
            color: context.ez.card,
            onPressed: () {
              Navigator.of(context).pop();
              onShowQr();
            },
          ),
        ],
      ],
    );
  }
}

class RetryMessage extends StatelessWidget {
  const RetryMessage({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            BrutalButton(label: 'Try again', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
