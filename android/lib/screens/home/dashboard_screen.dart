import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';
import '../../domain/money.dart';
import '../../state/session.dart';
import '../../state/summary.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/category_icon.dart';
import '../groups/group_widgets.dart';
import '../personal/personal_screen.dart';

const double _minBarFraction = 0.04;

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String monthName(DateTime d) => _monthNames[d.month - 1];

DateTime _firstOf(DateTime d) => DateTime(d.year, d.month);

Color? _parseHex(String hex) {
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex.trim());
  if (m == null) return null;
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

/// Bar length relative to the largest category; the largest fills the track.
double barFraction(int paise, int maxPaise) {
  if (paise <= 0 || maxPaise <= 0) return 0;
  return (paise / maxPaise).clamp(_minBarFraction, 1.0);
}

String _symbol(String code) => switch (code.toUpperCase()) {
  'USD' => r'$',
  'EUR' => '€',
  'GBP' => '£',
  _ => code,
};

String _foreignAmount(String currency, int paise) {
  final whole = (paise.abs() ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final cents = paise.abs() % 100;
  final number = cents == 0
      ? whole
      : '$whole.${cents.toString().padLeft(2, '0')}';
  final symbol = _symbol(currency);
  // A code is not a symbol, so it gets a space before the number.
  return symbol == currency.toUpperCase()
      ? '$symbol $number'
      : '$symbol$number';
}

String otherCurrencyLine(OtherCurrencyTotals t) {
  final parts = [
    if (t.youOwePaise > 0)
      'you owe ${_foreignAmount(t.currency, t.youOwePaise)}',
    if (t.owedToYouPaise > 0)
      'owed to you ${_foreignAmount(t.currency, t.owedToYouPaise)}',
  ];
  return '${t.currency}: ${parts.join(', ')}';
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final DateTime _current = _firstOf(ref.read(nowProvider));
  late DateTime _month = _current;

  /// The last month that loaded, kept on screen while the next one loads.
  MonthlySummary? _shown;

  bool get _atCurrent => !_month.isBefore(_current);

  void _step(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  Future<void> _refresh() async {
    ref.invalidate(monthlySummaryProvider(_month));
    try {
      await ref.read(monthlySummaryProvider(_month).future);
    } catch (_) {
      // The screen shows its own error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(monthlySummaryProvider(_month));
    if (summary.hasValue) _shown = summary.requireValue;
    final failed = summary.hasError && !summary.isLoading;
    final loading = summary.isLoading;
    // After a failed refresh the provider still holds its last good value.
    final data = failed
        ? (summary.hasValue ? summary.requireValue : null)
        : _shown;
    final text = Theme.of(context).textTheme;
    final name = ref.watch(sessionProvider).value?.firstName ?? '';
    final initials = name.isEmpty ? '' : name[0].toUpperCase();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 24, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name.isEmpty ? 'Hey' : 'Hey $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Avatar(initials, context.ez.lilac, size: 44),
                ],
              ),
              const SizedBox(height: 16),
              _ShareCard(
                month: _month,
                atCurrent: _atCurrent,
                data: data,
                dimmed: loading || failed,
                onPrevious: () => _step(-1),
                onNext: _atCurrent ? null : () => _step(1),
              ),
              if (loading && data == null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        color: context.ez.ink,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              if (failed && data == null)
                SizedBox(
                  height: 260,
                  child: RetryMessage(
                    message: errorMessage(summary.error!),
                    onRetry: () =>
                        ref.invalidate(monthlySummaryProvider(_month)),
                  ),
                ),
              if (failed && data != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _InlineError(
                    message: errorMessage(summary.error!),
                    onRetry: () =>
                        ref.invalidate(monthlySummaryProvider(_month)),
                  ),
                ),
              if (data != null)
                Opacity(
                  opacity: loading || failed ? 0.5 : 1,
                  child: _Body(data: data, selected: _month),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.month,
    required this.atCurrent,
    required this.data,
    required this.dimmed,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool atCurrent;
  final MonthlySummary? data;
  final bool dimmed;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = TextStyle(color: onAccent, fontWeight: FontWeight.w500);
    return BrutalCard(
      color: context.ez.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${monthName(month)} ${month.year}',
                  style: text.bodyLarge?.merge(label),
                ),
              ),
              _Arrow(
                icon: Symbols.chevron_left,
                label: 'Previous month',
                onTap: onPrevious,
              ),
              const SizedBox(width: 4),
              _Arrow(
                icon: Symbols.chevron_right,
                label: 'Next month',
                onTap: onNext,
              ),
            ],
          ),
          if (data != null)
            Opacity(
              opacity: dimmed ? 0.5 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatRupees(data!.mySharePaise),
                      softWrap: false,
                      style: text.displaySmall?.copyWith(
                        color: onAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                        height: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    'Your share this month',
                    style: text.bodyLarge?.merge(label),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The icon is dark, so dark mode needs the cream fill, not the dark card.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BrutalSurface(
      color: dark ? context.ez.ink : context.ez.card,
      borderWidth: kPillBorder,
      radius: 8,
      shadowOffset: 0,
      showShadow: false,
      isButton: true,
      semanticLabel: label,
      onTap: onTap,
      constraints: const BoxConstraints(minWidth: kMinTap, minHeight: kMinTap),
      child: Center(
        child: Icon(icon, color: onTap == null ? EzColors.disabled : onAccent),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data, required this.selected});

  final MonthlySummary data;

  /// Names the month if data.month is malformed.
  final DateTime selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.ez;
    final parts = data.month.split('-');
    final y = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final m = parts.length == 2 ? int.tryParse(parts[1]) : null;
    final month = monthName(
      y != null && m != null && m >= 1 && m <= 12 ? DateTime(y, m) : selected,
    );
    final others = [
      for (final t in data.otherCurrencies)
        if (t.youOwePaise > 0 || t.owedToYouPaise > 0) t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _AmountCard(
                label: 'You owe',
                paise: data.youOwePaise,
                color: c.peach,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _AmountCard(
                label: 'Owed to you',
                paise: data.owedToYouPaise,
                color: c.mint,
              ),
            ),
          ],
        ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Other currencies', style: text.bodySmall),
          for (final t in others)
            Text(otherCurrencyLine(t), style: text.bodyMedium),
        ],
        const SizedBox(height: 20),
        _PersonalCard(data: data, month: month),
        const SizedBox(height: 20),
        Text(
          'By category',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (data.categories.isEmpty)
          BrutalCard(
            child: Text('No expenses in $month', style: text.bodyLarge),
          )
        else
          _Categories(categories: data.categories),
      ],
    );
  }
}

/// Spending outside any group, with a way into the list and the form.
class _PersonalCard extends StatelessWidget {
  const _PersonalCard({required this.data, required this.month});

  final MonthlySummary data;
  final String month;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.ez;
    final n = data.personalCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Personal',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/home/personal'),
              style: TextButton.styleFrom(
                foregroundColor: c.ink,
                minimumSize: const Size(kMinTap, kMinTap),
              ),
              child: const Text(
                'See all',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        BrutalCard(
          onTap: () => context.go('/home/personal'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.lilac,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.line, width: kPillBorder),
                ),
                child: const Icon(Symbols.person, color: onAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatRupees(data.personalPaise)} spent alone',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$n ${n == 1 ? 'expense' : 'expenses'} in $month · no group',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AddPersonalButton(
                onTap: () => context.push('/home/personal/new'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.label,
    required this.paise,
    required this.color,
  });

  final String label;
  final int paise;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BrutalCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodyLarge?.copyWith(color: onAccent)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupees(paise),
              softWrap: false,
              style: text.headlineSmall?.copyWith(
                color: onAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.categories});

  final List<CategorySpend> categories;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Server colours are light-palette pastels; dark mode uses its own fills.
    final darkFills = [c.green, c.peach, c.mint, c.lilac];
    final maxPaise = categories.fold<int>(
      0,
      (m, e) => e.paise > m ? e.paise : m,
    );
    return BrutalCard(
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _CategoryRow(
              category: categories[i],
              fraction: barFraction(categories[i].paise, maxPaise),
              fill: dark
                  ? darkFills[i % darkFills.length]
                  : _parseHex(categories[i].color) ?? c.amber,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.fraction,
    required this.fill,
  });

  final CategorySpend category;
  final double fraction;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = context.ez.ink;
    final line = context.ez.line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              ExcludeSemantics(
                child: CategoryIcon(category.icon, ink, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge,
                ),
              ),
              const SizedBox(width: 8),
              // The amount shrinks to fit; the name gives way first.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatRupees(category.paise),
                    softWrap: false,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ExcludeSemantics(
          child: Container(
            height: 14,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.ez.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: line, width: kPillBorder),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                key: ValueKey('bar-${category.name}'),
                widthFactor: fraction,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    border: fraction > 0 && fraction < 1
                        ? Border(
                            right: BorderSide(color: line, width: kPillBorder),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message)),
        const SizedBox(width: 8),
        BrutalButton(label: 'Try again', onPressed: onRetry),
      ],
    );
  }
}
