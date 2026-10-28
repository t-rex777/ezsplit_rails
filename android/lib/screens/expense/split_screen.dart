import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';
import '../../domain/money.dart';
import '../../state/expense_form.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_pill.dart';
import '../groups/group_widgets.dart';
import 'expense_form_screen.dart';

/// 3333 -> "33.33%", 500 -> "5%", 550 -> "5.5%".
String percentLabel(int hundredths) {
  final whole = hundredths ~/ 100;
  final frac = hundredths % 100;
  if (frac == 0) return '$whole%';
  final digits = frac
      .toString()
      .padLeft(2, '0')
      .replaceFirst(RegExp(r'0$'), '');
  return '$whole.$digits%';
}

/// Typed percent such as "33.3" to hundredths (3330). Empty is 0.
int percentFromText(String t) {
  final parts = t.trim().split('.');
  final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
  final frac = parts.length > 1
      ? int.tryParse(parts[1].padRight(2, '0').substring(0, 2)) ?? 0
      : 0;
  return whole * 100 + frac;
}

/// Typed rupees to paise. Empty or zero is 0.
int exactFromText(String t) => parseRupees(t) ?? 0;

/// Up to 3 digits and 2 decimals, never above 100.
class _PercentFormatter extends TextInputFormatter {
  static final _allowed = RegExp(r'^\d{0,3}(\.\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!_allowed.hasMatch(newValue.text)) return oldValue;
    return percentFromText(newValue.text) > 10000 ? oldValue : newValue;
  }
}

/// The full split: who is in and what each person owes, for the current mode.
class SplitScreen extends ConsumerWidget {
  const SplitScreen({super.key, required this.formKey});

  final ExpenseFormKey formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(expenseFormProvider(formKey));
    final form = ref.read(expenseFormProvider(formKey).notifier);
    final text = Theme.of(context).textTheme;
    final total = s.paise;
    final bar = _statusBar(context, s);
    final action = _action(s);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Symbols.arrow_back),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      total == null ? 'Split' : 'Split ${formatRupees(total)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                      onTap: () => form.setMode(m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    BrutalCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < s.members.length; i++)
                            _PersonRow(
                              key: ValueKey('row-${s.members[i].id}'),
                              user: s.members[i],
                              state: s,
                              first: i == 0,
                              onToggle: () =>
                                  form.toggleIncluded(s.members[i].id),
                              onPercent: (h) =>
                                  form.setPercent(s.members[i].id, h),
                              onExact: (p) => form.setExact(s.members[i].id, p),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    bar,
                    const SizedBox(height: 12),
                    Text(
                      'Tap a person to leave them out of this expense.',
                      style: text.bodyMedium,
                    ),
                    if (s.splitValid && total != null) ...[
                      const SizedBox(height: 16),
                      _WhoOwesWhom(state: s),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BrutalButton(
                label: action.$1,
                color: context.ez.green,
                onPressed: action.$2 ? () => Navigator.of(context).pop() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The button label, and whether the split can be finished.
  (String, bool) _action(ExpenseFormState s) {
    if (s.paise == null || s.included.isEmpty) return ('Done', false);
    switch (s.mode) {
      case SplitMode.equal:
        return ('Done', true);
      case SplitMode.percent:
        return ('Done', s.percentRemaining == 0);
      case SplitMode.exact:
        final left = s.exactRemaining;
        if (left > 0) return ('Assign ${formatRupees(left)} more', false);
        if (left < 0) return ('Remove ${formatRupees(-left)}', false);
        return ('Done', true);
    }
  }

  Widget _statusBar(BuildContext context, ExpenseFormState s) {
    final c = context.ez;
    final (String left, String right, bool ok) = _status(s);
    if (left.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: BrutalSurface(
        color: ok ? c.mint : c.peach,
        borderWidth: kCardBorder,
        radius: 10,
        showShadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                left,
                style: const TextStyle(
                  color: onAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (ok && s.mode == SplitMode.percent)
              const Icon(Symbols.check, size: 18, color: onAccent),
            Text(
              right,
              softWrap: false,
              style: const TextStyle(
                color: onAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Left text, right text, and whether the split adds up. Left is empty when
  /// there is nothing to say (an equal split).
  (String, String, bool) _status(ExpenseFormState s) {
    if (s.included.isEmpty) return ('Pick at least one person', '', false);
    switch (s.mode) {
      case SplitMode.equal:
        return ('', '', true);
      case SplitMode.percent:
        final left = s.percentRemaining;
        if (left == 0) return ('Total', '100%', true);
        return (
          '${percentLabel(left.abs())} ${left > 0 ? 'left' : 'over'}',
          '${percentLabel(s.percentSum)} of 100%',
          false,
        );
      case SplitMode.exact:
        final total = s.paise;
        if (total == null) return ('', '', false);
        final left = s.exactRemaining;
        if (left == 0) return ('All assigned', formatRupees(total), true);
        return (
          '${formatRupees(left.abs())} ${left > 0 ? 'left to assign' : 'over'}',
          '${formatRupees(s.exactSum)} of ${formatRupees(total)}',
          false,
        );
    }
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    super.key,
    required this.user,
    required this.state,
    required this.first,
    required this.onToggle,
    required this.onPercent,
    required this.onExact,
  });

  final User user;
  final ExpenseFormState state;
  final bool first;
  final VoidCallback onToggle;
  final ValueChanged<int> onPercent;
  final ValueChanged<int> onExact;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final s = state;
    final isIn = s.included.contains(user.id);
    final name = personLabel(user, s.meId);
    final muted = c.ink.withValues(alpha: 0.6);
    final share = s.shares[user.id];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: first
            ? null
            : Border(
                top: BorderSide(color: c.line, width: kPillBorder),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: isIn ? 'Leave out $name' : 'Include $name',
              excludeSemantics: true,
              onTap: onToggle,
              child: InkWell(
                onTap: onToggle,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: kMinTap + 12),
                  child: Row(
                    children: [
                      Opacity(
                        opacity: isIn ? 1 : 0.5,
                        child: Avatar(
                          user.initials.isEmpty ? '?' : user.initials,
                          isIn ? tintFor(context, user.id) : c.card,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isIn ? c.ink : muted,
                            decoration: isIn
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!isIn)
            Text('left out', style: TextStyle(color: muted, fontSize: 13))
          else ...[
            if (s.mode != SplitMode.exact && share != null)
              Text(
                formatRupees(share),
                softWrap: false,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            if (s.mode == SplitMode.percent) ...[
              const SizedBox(width: 10),
              _NumField(
                key: ValueKey('percent-${user.id}'),
                label: '$name percent',
                width: 84,
                suffix: '%',
                initial: s.percents[user.id] == null || s.percents[user.id] == 0
                    ? ''
                    : percentLabel(s.percents[user.id]!).replaceAll('%', ''),
                formatters: [_PercentFormatter()],
                onChanged: (t) => onPercent(percentFromText(t)),
              ),
            ],
            if (s.mode == SplitMode.exact) ...[
              _NumField(
                key: ValueKey('exact-${user.id}'),
                label: '$name amount',
                width: 120,
                prefix: '₹',
                initial: (s.exact[user.id] ?? 0) == 0
                    ? ''
                    : paiseToApi(s.exact[user.id]!)
                          .replaceFirst(RegExp(r'\.00$'), ''),
                formatters: const [RupeesInputFormatter(maxDecimals: 2)],
                onChanged: (t) => onExact(exactFromText(t)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// A small right-aligned number box. It keeps its own text while typing; the
/// row gets a new one (with its text from the state) when the mode changes or
/// the person is added back.
class _NumField extends StatefulWidget {
  const _NumField({
    super.key,
    required this.label,
    required this.width,
    required this.initial,
    required this.formatters,
    required this.onChanged,
    this.prefix,
    this.suffix,
  });

  final String label;
  final double width;
  final String initial;
  final String? prefix;
  final String? suffix;
  final List<TextInputFormatter> formatters;
  final ValueChanged<String> onChanged;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return SizedBox(
      width: widget.width,
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTap),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.line, width: kCardBorder),
        ),
        child: Row(
          children: [
            if (widget.prefix != null)
              Text(
                widget.prefix!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            Expanded(
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: widget.formatters,
                onChanged: widget.onChanged,
                cursorColor: c.ink,
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: TextStyle(color: c.ink.withValues(alpha: 0.4)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (widget.suffix != null)
              Text(
                widget.suffix!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}

class _WhoOwesWhom extends StatelessWidget {
  const _WhoOwesWhom({required this.state});

  final ExpenseFormState state;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final payer = s.member(s.payerId);
    if (payer == null) return const SizedBox.shrink();
    final payerName = payer.id == s.meId ? 'you' : userName(payer);
    final owing = [
      for (final id in s.included)
        if (id != s.payerId && (s.shares[id] ?? 0) > 0) id,
    ];
    if (owing.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who owes whom',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        BrutalCard(
          child: Column(
            children: [
              for (final id in owing)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${personLabel(s.member(id)!, s.meId)} ${id == s.meId ? 'owe' : 'owes'} $payerName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatRupees(s.shares[id]!),
                        softWrap: false,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
