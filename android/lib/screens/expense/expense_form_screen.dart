import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';
import '../../domain/money.dart';
import '../../state/expense_form.dart';
import '../../state/group_detail.dart';
import '../../state/group_icons.dart';
import '../../state/groups.dart';
import '../../state/session.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_input.dart';
import '../../widgets/brutal_pill.dart';
import '../../widgets/brutal_sheet.dart';
import '../../widgets/category_icon.dart';
import '../groups/group_widgets.dart';
import 'split_screen.dart';

const _maxWholeDigits = 12;

/// Keeps digits, commas and one point, and stops the part before the point at
/// 12 digits so the paise total cannot overflow. [maxDecimals] null leaves the
/// decimals free, so the form can explain a third one instead of hiding it.
class RupeesInputFormatter extends TextInputFormatter {
  const RupeesInputFormatter({this.maxDecimals});

  final int? maxDecimals;

  static final _allowed = RegExp(r'^[0-9,]*\.?[0-9]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    if (!_allowed.hasMatch(t)) return oldValue;
    final parts = t.split('.');
    if (parts.first.replaceAll(',', '').length > _maxWholeDigits) {
      return oldValue;
    }
    if (maxDecimals != null && parts.length > 1) {
      if (parts[1].length > maxDecimals!) return oldValue;
    }
    return newValue;
  }
}

/// "You" for the signed-in user, else the first name.
String personLabel(User u, int meId) => u.id == meId ? 'You' : userName(u);

String _dateLabel(DateTime d) {
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return 'Today';
  }
  return DateFormat('d MMM y').format(d);
}

/// Opens the edit form for an expense. The group comes from the expense.
class EditExpenseScreen extends ConsumerWidget {
  const EditExpenseScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expense = ref.watch(expenseProvider(expenseId));
    final e = expense.value;
    if (e != null && e.groupId != null) {
      return ExpenseFormScreen(groupId: e.groupId!, expenseId: expenseId);
    }
    if (e != null) {
      return const _FormShell(
        title: 'Edit expense',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "This expense isn't in a group, so it can't be edited here.",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return _FormShell(
      title: 'Edit expense',
      child: expense.isLoading
          ? Center(child: CircularProgressIndicator(color: context.ez.ink))
          : RetryMessage(
              message: errorMessage(expense.error!),
              onRetry: () => ref.invalidate(expenseProvider(expenseId)),
            ),
    );
  }
}

class ExpenseFormScreen extends ConsumerWidget {
  const ExpenseFormScreen({super.key, required this.groupId, this.expenseId});

  final int groupId;
  final int? expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = expenseId == null ? 'Add expense' : 'Edit expense';
    // The form reads these once when it starts, so all of them load first.
    final loads = <AsyncValue<Object?>>[
      ref.watch(sessionProvider),
      ref.watch(groupProvider(groupId)),
      ref.watch(categoriesProvider),
      ref.watch(lastCategoryIdProvider),
      if (expenseId != null) ref.watch(expenseProvider(expenseId!)),
    ];
    final failed = loads.where((l) => l.hasError && !l.hasValue).firstOrNull;
    if (failed != null) {
      return _FormShell(
        title: title,
        child: RetryMessage(
          message: errorMessage(failed.error!),
          onRetry: () {
            ref.invalidate(groupProvider(groupId));
            ref.invalidate(categoriesProvider);
            if (expenseId != null) ref.invalidate(expenseProvider(expenseId!));
          },
        ),
      );
    }
    if (loads.any((l) => !l.hasValue)) {
      return _FormShell(
        title: title,
        child: Center(child: CircularProgressIndicator(color: context.ez.ink)),
      );
    }
    return _FormBody(formKey: (groupId: groupId, expenseId: expenseId));
  }
}

/// The header and close button around a form that is not ready yet.
class _FormShell extends StatelessWidget {
  const _FormShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                children: [
                  _CloseButton(onTap: () => _leave(context, null)),
                  Expanded(child: _Title(title)),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

void _leave(BuildContext context, int? groupId) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(groupId == null ? '/groups' : '/groups/$groupId');
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Close',
      constraints: const BoxConstraints(minWidth: kMinTap, minHeight: kMinTap),
      onPressed: onTap,
      icon: const Icon(Symbols.close),
    );
  }
}

class _FormBody extends ConsumerStatefulWidget {
  const _FormBody({required this.formKey});

  final ExpenseFormKey formKey;

  @override
  ConsumerState<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends ConsumerState<_FormBody> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  ExpenseFormKey get _key => widget.formKey;
  ExpenseFormNotifier get _form => ref.read(expenseFormProvider(_key).notifier);

  @override
  void initState() {
    super.initState();
    final s = ref.read(expenseFormProvider(_key));
    _name = TextEditingController(text: s.name);
    _amount = TextEditingController(text: s.amountText);
    _notes = TextEditingController(text: s.notes);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // The container outlives this screen, so the reload still happens.
    final container = ProviderScope.containerOf(context);
    final saved = await _form.save();
    if (saved == null) return;
    invalidateAfterExpenseChange(
      container.invalidate,
      _key.groupId,
      expenseId: _key.expenseId,
    );
    if (mounted) _leave(context, _key.groupId);
  }

  Future<void> _pickPayer(ExpenseFormState s) async {
    final id = await showBrutalSheet<int>(
      context,
      title: 'Paid by',
      child: Column(
        children: [
          for (final u in s.members)
            _ChoiceRow(
              leading: Avatar(u.initials, tintFor(context, u.id), size: 36),
              label: personLabel(u, s.meId),
              selected: u.id == s.payerId,
              onTap: (ctx) => Navigator.of(ctx).pop(u.id),
            ),
        ],
      ),
    );
    if (id != null) _form.setPayer(id);
  }

  Future<void> _pickCategory(ExpenseFormState s) async {
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    final id = await showBrutalSheet<int>(
      context,
      title: 'Category',
      child: Column(
        children: [
          for (final c in categories)
            _ChoiceRow(
              leading: IconTile(
                icon: c.icon,
                color: parseHexColor(c.color, context.ez.amber),
                size: 36,
              ),
              label: c.name,
              selected: c.id == s.categoryId,
              onTap: (ctx) => Navigator.of(ctx).pop(c.id),
            ),
        ],
      ),
    );
    if (id != null) _form.setCategory(id);
  }

  Future<void> _pickDate(ExpenseFormState s) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: s.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked != null) _form.setDate(picked);
  }

  Future<void> _openSplit(SplitMode mode) async {
    final s = ref.read(expenseFormProvider(_key));
    // By % and Exact work on a total, so it has to be valid first.
    if (mode != SplitMode.equal && s.paise == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter an amount first')));
      return;
    }
    _form.setMode(mode);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => SplitScreen(formKey: _key)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(expenseFormProvider(_key));
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final category = ref
        .watch(categoriesProvider)
        .value
        ?.where((x) => x.id == s.categoryId)
        .firstOrNull;
    final payer = s.member(s.payerId);
    return PopScope(
      canPop: !s.posting,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  _CloseButton(
                    onTap: s.posting
                        ? null
                        : () => _leave(context, _key.groupId),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _Title(s.isEdit ? 'Edit expense' : 'Add expense'),
                  ),
                  const SizedBox(width: 8),
                  _SaveButton(enabled: s.canSave, onTap: _save),
                ],
              ),
              const SizedBox(height: 12),
              _GroupLine(groupId: s.groupId, memberCount: s.members.length),
              const SizedBox(height: 12),
              BrutalInput(
                key: const ValueKey('description'),
                hint: 'Description',
                controller: _name,
                textInputAction: TextInputAction.next,
                onChanged: _form.setName,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: BrutalInput(
                      key: const ValueKey('amount'),
                      hint: 'Amount',
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 4),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            '₹',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      errorText: s.amountError,
                      inputFormatters: const [RupeesInputFormatter()],
                      onChanged: _form.setAmount,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: _CategoryPill(
                      category: category,
                      onTap: () => _pickCategory(s),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      semanticLabel: 'Paid by',
                      onTap: () => _pickPayer(s),
                      child: Row(
                        children: [
                          const Text('Paid by'),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              payer == null ? '' : personLabel(payer, s.meId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(Symbols.expand_more),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Field(
                    semanticLabel: 'Date',
                    onTap: () => _pickDate(s),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.calendar_today),
                        const SizedBox(width: 8),
                        Text(_dateLabel(s.date)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in SplitMode.values)
                    BrutalPill(
                      label: m.label,
                      selected: m == s.mode,
                      onTap: () => _openSplit(m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _SplitSummary(state: s, onTap: () => _openSplit(s.mode)),
              if (s.error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    s.error!,
                    style: text.bodyMedium?.copyWith(
                      color: c.negative,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              BrutalInput(
                key: const ValueKey('note'),
                hint: 'Add a note',
                controller: _notes,
                prefix: const Icon(Symbols.sticky_note_2),
                onChanged: _form.setNotes,
              ),
              const SizedBox(height: 12),
              _Field(
                semanticLabel: 'Add photo',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photos are coming soon')),
                ),
                color: c.bg,
                child: const Row(
                  children: [
                    Icon(Symbols.photo_camera),
                    SizedBox(width: 8),
                    Text('Add photo'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BrutalSurface(
      color: enabled ? context.ez.green : EzColors.disabled,
      borderWidth: kPillBorder,
      radius: 999,
      shadowOffset: 3,
      showShadow: enabled,
      isButton: true,
      semanticLabel: 'Save',
      onTap: enabled ? onTap : null,
      constraints: const BoxConstraints(minWidth: kMinTap, minHeight: kMinTap),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Center(
        widthFactor: 1,
        child: Text(
          'Save',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: onAccent, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _GroupLine extends ConsumerWidget {
  const _GroupLine({required this.groupId, required this.memberCount});

  final int groupId;
  final int memberCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(groupProvider(groupId)).value?.name ?? '';
    final icon =
        ref.watch(groupIconProvider(groupId)).value ?? defaultGroupIcon;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        const Text('In'),
        const SizedBox(width: 8),
        Flexible(
          child: BrutalSurface(
            color: context.ez.amber,
            borderWidth: kPillBorder,
            radius: 999,
            shadowOffset: 2,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CategoryIcon(icon, onAccent, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(
                      color: onAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('all $memberCount members', style: text.bodySmall),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category, required this.onTap});

  final Category? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = category;
    return BrutalSurface(
      color: cat == null
          ? context.ez.card
          : parseHexColor(cat.color, context.ez.amber),
      borderWidth: kPillBorder,
      radius: 999,
      shadowOffset: 2,
      isButton: true,
      semanticLabel: 'Category ${cat?.name ?? ''}'.trim(),
      onTap: onTap,
      constraints: const BoxConstraints(minHeight: kMinTap),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cat != null) CategoryIcon(cat.icon, onAccent, size: 18),
          if (cat != null) const SizedBox(width: 6),
          Flexible(
            child: Text(
              cat?.name ?? 'Category',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: onAccent, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable bordered field, like Paid by and the date.
class _Field extends StatelessWidget {
  const _Field({
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.color,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return BrutalSurface(
      color: color ?? context.ez.card,
      borderWidth: kCardBorder,
      radius: 10,
      showShadow: false,
      isButton: true,
      semanticLabel: semanticLabel,
      onTap: onTap,
      constraints: const BoxConstraints(minHeight: kMinTap),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: child,
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget leading;
  final String label;
  final bool selected;
  final void Function(BuildContext) onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => onTap(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTap + 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected) const Icon(Symbols.check),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who is in, the per-person share, and who owes whom. Tapping it opens the
/// full split.
class _SplitSummary extends StatelessWidget {
  const _SplitSummary({required this.state, required this.onTap});

  final ExpenseFormState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final text = Theme.of(context).textTheme;
    final others = [
      for (final id in s.included)
        if (id != s.meId) s.member(id)!,
    ];
    final names = others.isNotEmpty
        ? others.map(userName).join(', ')
        : s.included.isEmpty
        ? 'No one yet'
        : 'Only you';
    return BrutalCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  names,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _headline(s),
                softWrap: false,
                style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (_detail(s).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _detail(s),
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

String _headline(ExpenseFormState s) {
  if (s.paise == null) return '';
  switch (s.mode) {
    case SplitMode.equal:
      if (s.included.isEmpty) return '';
      // Shares can differ by a paisa; the larger one is shown.
      final top = s.shares.values.reduce((a, b) => a > b ? a : b);
      return '${formatRupees(top)} each';
    case SplitMode.percent:
      return s.percentRemaining == 0
          ? 'By percent'
          : '${percentLabel(s.percentRemaining.abs())} ${s.percentRemaining > 0 ? 'left' : 'over'}';
    case SplitMode.exact:
      return s.exactRemaining == 0
          ? 'By amount'
          : '${formatRupees(s.exactRemaining.abs())} ${s.exactRemaining > 0 ? 'left' : 'over'}';
  }
}

String _detail(ExpenseFormState s) {
  if (s.paise == null) return 'Enter an amount to see the split';
  if (s.included.isEmpty) return 'Pick at least one person';
  if (!s.splitValid) return 'Finish the split to save';
  final shares = s.shares;
  if (s.payerId == s.meId) {
    final others = [
      for (final id in s.included)
        if (id != s.meId) id,
    ];
    if (others.isEmpty) return 'Only you are in this split';
    final owed = others.fold<int>(0, (a, id) => a + (shares[id] ?? 0));
    final n = others.length;
    return '$n ${n == 1 ? 'person owes' : 'people owe'} you ${formatRupees(owed)}';
  }
  final payer = s.member(s.payerId);
  if (payer == null || !s.included.contains(s.meId)) return '';
  return 'You owe ${userName(payer)} ${formatRupees(shares[s.meId] ?? 0)}';
}
