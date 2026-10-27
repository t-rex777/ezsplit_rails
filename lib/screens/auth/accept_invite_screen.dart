import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_input.dart';
import 'auth_widgets.dart';

const _minPassword = 6;

class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({
    super.key,
    required this.token,
    required this.email,
  });

  final String token;
  final String email;

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _dobText = TextEditingController();
  final _password = TextEditingController();
  DateTime? _dob;
  bool _hidden = true;
  bool _busy = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _first, _last, _phone, _dobText, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  // Errors show after the first submit, then update as the person types.
  String? _required(TextEditingController c, String message) =>
      _submitted && c.text.trim().isEmpty ? message : null;

  String? get _passwordError =>
      _submitted && _password.text.length < _minPassword
      ? 'Use at least $_minPassword characters'
      : null;

  String? get _dobError =>
      _submitted && _dob == null ? 'Choose your date of birth' : null;

  bool get _valid =>
      _first.text.trim().isNotEmpty &&
      _last.text.trim().isNotEmpty &&
      _phone.text.trim().isNotEmpty &&
      _dob != null &&
      _password.text.length >= _minPassword;

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _dob = picked;
      _dobText.text = DateFormat('d MMM yyyy').format(picked);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_valid) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .acceptInvite(
            token: widget.token,
            email: widget.email,
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            phone: _phone.text.trim(),
            dob: _dob!,
            password: _password.text,
          );
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
    final passwordError = _passwordError;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrutalCard(
                color: c.lilac,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    const Icon(Symbols.drafts, size: 40, color: onAccent),
                    const SizedBox(height: 6),
                    Text(
                      "You're invited",
                      style: text.headlineSmall?.copyWith(
                        color: onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'to split expenses on ezsplit',
                      style: text.bodyLarge?.copyWith(color: onAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BrutalInput(
                label: 'Email',
                controller: _email,
                readOnly: true,
                suffix: Icon(Symbols.lock, color: c.ink),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: BrutalInput(
                      label: 'First name',
                      controller: _first,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      errorText: _required(_first, 'Enter your first name'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BrutalInput(
                      label: 'Last name',
                      controller: _last,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      errorText: _required(_last, 'Enter your last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BrutalInput(
                label: 'Phone',
                controller: _phone,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
                errorText: _required(_phone, 'Enter your phone number'),
              ),
              const SizedBox(height: 16),
              BrutalInput(
                label: 'Date of birth',
                controller: _dobText,
                readOnly: true,
                onTap: _pickDob,
                suffix: Icon(Symbols.calendar_month, color: c.ink),
                errorText: _dobError,
              ),
              const SizedBox(height: 16),
              BrutalInput(
                label: 'Set a password',
                controller: _password,
                obscureText: _hidden,
                onChanged: (_) => setState(() {}),
                errorText: passwordError,
                suffix: PasswordToggle(
                  hidden: _hidden,
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
              if (passwordError == null) ...[
                const SizedBox(height: 8),
                Text(
                  'At least $_minPassword characters.',
                  style: text.bodySmall?.copyWith(
                    color: c.ink.withValues(alpha: 0.7),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                AuthNotice(
                  icon: Symbols.error,
                  color: c.peach,
                  title: _error!,
                ),
              ],
              const SizedBox(height: 24),
              BrutalButton(
                label: 'Join ezsplit',
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
