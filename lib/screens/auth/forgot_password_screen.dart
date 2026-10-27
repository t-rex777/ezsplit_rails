import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_input.dart';
import 'auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to log in',
                    onPressed: () => context.go('/login'),
                    constraints: const BoxConstraints(
                      minWidth: kMinTap,
                      minHeight: kMinTap,
                    ),
                    icon: Icon(Symbols.arrow_back, color: c.ink),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Reset password',
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Enter your email. We'll send you a link to set a new password.",
                style: text.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              BrutalInput(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                errorText: _error,
              ),
              const SizedBox(height: 16),
              BrutalButton(
                label: 'Send link',
                onPressed: _busy || _email.text.trim().isEmpty ? null : _send,
              ),
              if (_sent) ...[
                const SizedBox(height: 28),
                AuthNotice(
                  icon: Symbols.mark_email_read,
                  color: c.mint,
                  title: 'Check your inbox.',
                  body: 'The link works for 15 minutes.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
