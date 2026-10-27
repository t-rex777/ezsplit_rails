import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';
import '../../data/users_repository.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_input.dart';
import '../../widgets/brutal_pill.dart';
import '../groups/group_widgets.dart';
import 'profile_screen.dart';

class EditDetailsScreen extends ConsumerStatefulWidget {
  const EditDetailsScreen({super.key});

  @override
  ConsumerState<EditDetailsScreen> createState() => _EditDetailsScreenState();
}

class _EditDetailsScreenState extends ConsumerState<EditDetailsScreen> {
  late final User _user;
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  final _dobText = TextEditingController();
  late final TextEditingController _email;
  DateTime? _dob;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Only signed-in users reach this route, so the session user is set.
    _user = ref.read(sessionProvider).requireValue!;
    _first = TextEditingController(text: _user.firstName);
    _last = TextEditingController(text: _user.lastName);
    _phone = TextEditingController(text: _user.phone ?? '');
    _email = TextEditingController(text: _user.email);
    _setDob(_user.dob);
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _phone, _dobText, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setDob(DateTime? dob) {
    _dob = dob;
    _dobText.text = dob == null ? '' : DateFormat('d MMM yyyy').format(dob);
  }

  bool get _canSave => _first.text.trim().isNotEmpty && !_saving;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _setDob(picked));
  }

  Future<void> _save() async {
    final repo = ref.read(usersRepositoryProvider);
    final session = ref.read(sessionProvider.notifier);
    final phone = _phone.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    final User updated;
    try {
      updated = await repo.updateMe(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        // An empty phone on a user with none sends nothing.
        phone: phone.isEmpty && _user.phone == null ? null : phone,
        dob: _dob,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(e);
      });
      return;
    }
    session.setUser(updated);
    if (!mounted) return;
    _back();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final initials = userInitials(
      User(
        id: _user.id,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: _user.email,
      ),
    );
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to profile',
                    constraints: const BoxConstraints(
                      minWidth: kMinTap,
                      minHeight: kMinTap,
                    ),
                    onPressed: _saving ? null : _back,
                    icon: const Icon(Symbols.arrow_back),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Your details',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  BrutalPill(
                    label: 'Save',
                    selected: _canSave,
                    color: c.green,
                    onTap: _canSave ? _save : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Avatar(initials, c.lilac, size: 96),
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: BrutalSurface(
                        color: c.amber,
                        borderWidth: kCardBorder,
                        radius: 999,
                        shadowOffset: 2,
                        isButton: true,
                        semanticLabel: 'Change photo',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coming soon')),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: kMinTap,
                          minHeight: kMinTap,
                        ),
                        child: const Center(
                          child: Icon(
                            Symbols.photo_camera,
                            size: 20,
                            color: onAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: BrutalInput(
                      label: 'First name',
                      controller: _first,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BrutalInput(
                      label: 'Last name',
                      controller: _last,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              BrutalInput(
                label: 'Phone',
                controller: _phone,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
              BrutalInput(
                label: 'Date of birth',
                controller: _dobText,
                readOnly: true,
                onTap: _pickDob,
                suffix: Icon(Symbols.calendar_month, color: c.ink),
              ),
              const SizedBox(height: 14),
              BrutalInput(
                label: 'Email',
                controller: _email,
                readOnly: true,
                suffix: Icon(Symbols.lock, color: c.ink),
              ),
              const SizedBox(height: 8),
              Text(
                "Your email is your login, so it can't be changed here.",
                style: text.bodySmall?.copyWith(
                  color: c.ink.withValues(alpha: 0.7),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: text.bodyMedium?.copyWith(
                    color: c.negative,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
