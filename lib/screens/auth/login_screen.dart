import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/invite_link.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_input.dart';
import '../../widgets/brutal_sheet.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final String? _expired;
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _expired = ref.read(sessionProvider.notifier).expiredMessage;
    _email.addListener(_refresh);
    _password.addListener(_refresh);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _ready =>
      !_busy && _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(_email.text.trim(), _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openInviteSheet() {
    final router = GoRouter.of(context);
    showBrutalSheet<void>(
      context,
      title: 'Paste your invite link',
      child: _InviteLinkForm(
        onLink: (link) => router.go(
          Uri(
            path: '/invite',
            queryParameters: {'token': link.token, 'email': link.email},
          ).toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final notice = _error ?? _expired;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Transform.rotate(
                      angle: -0.052,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: c.amber,
                          border: Border.all(color: c.ink, width: 3),
                          boxShadow: [
                            BoxShadow(offset: const Offset(5, 5), color: c.ink),
                          ],
                        ),
                        child: Text(
                          'ezsplit',
                          style: text.displaySmall?.copyWith(
                            color: onAccent,
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Split bills. Stay friends.',
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 32),
                  if (notice != null) ...[
                    AuthNotice(
                      icon: Symbols.error,
                      color: c.peach,
                      title: notice,
                    ),
                    const SizedBox(height: 16),
                  ],
                  BrutalInput(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  BrutalInput(
                    label: 'Password',
                    controller: _password,
                    obscureText: _hidden,
                    textInputAction: TextInputAction.done,
                    suffix: PasswordToggle(
                      hidden: _hidden,
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/forgot'),
                      style: TextButton.styleFrom(
                        foregroundColor: c.ink,
                        minimumSize: const Size(kMinTap, kMinTap),
                        textStyle: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  BrutalButton(
                    label: 'Log in',
                    onPressed: _ready ? _submit : null,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Invite only. Ask a friend on ezsplit to invite you.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: c.ink.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _openInviteSheet,
                      style: TextButton.styleFrom(
                        foregroundColor: c.ink,
                        minimumSize: const Size(kMinTap, kMinTap),
                        textStyle: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      child: const Text('Have an invite link?'),
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

class _InviteLinkForm extends StatefulWidget {
  const _InviteLinkForm({required this.onLink});

  final void Function(InviteLink link) onLink;

  @override
  State<_InviteLinkForm> createState() => _InviteLinkFormState();
}

class _InviteLinkFormState extends State<_InviteLinkForm> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    final link = parseInviteLink(_controller.text);
    if (link == null) {
      setState(() => _error = "That isn't an ezsplit invite link");
      return;
    }
    Navigator.of(context).pop();
    widget.onLink(link);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrutalInput(
          controller: _controller,
          keyboardType: TextInputType.url,
          errorText: _error,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 16),
        BrutalButton(label: 'Continue', onPressed: _continue),
      ],
    );
  }
}
