import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';

import '../../data/analytics_repository.dart';
import '../../data/models.dart';
import '../../domain/analytics.dart';
import '../../domain/money.dart';
import '../../state/analytics.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/category_icon.dart';
import '../groups/group_widgets.dart';
import 'charts.dart';
import 'filters_sheet.dart';

/// Fill for each category key. Server colours are light-palette pastels, so
/// dark mode cycles its own fills by rank, as the dashboard does.
Map<String, Color> categoryColors(
  BuildContext context,
  List<CategorySpend> ranked,
) {
  final c = context.ez;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final darkFills = [c.green, c.peach, c.mint, c.lilac];
  return {
    for (var i = 0; i < ranked.length; i++)
      categoryKey(ranked[i].name): dark
          ? darkFills[i % darkFills.length]
          : parseHexColor(ranked[i].color, c.amber),
  };
}

String monthTitle(DateTime month) => DateFormat('MMMM y').format(month);

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  /// The picked month, kept by date so it survives a reload.
  DateTime? _picked;

  Future<void> _refresh(AnalyticsScope scope) async {
    ref.invalidate(analyticsMonthsProvider(scope));
    try {
      await ref.read(analyticsMonthsProvider(scope).future);
    } catch (_) {
      // The screen shows its own error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(analyticsFiltersProvider);
    final async = ref.watch(analyticsMonthsProvider(filters.scope));
    final text = Theme.of(context).textTheme;
    final all = async.value;

    Widget body;
    if (all == null && async.hasError) {
      body = SizedBox(
        height: 420,
        child: RetryMessage(
          message: errorMessage(async.error!),
          onRetry: () => ref.invalidate(analyticsMonthsProvider(filters.scope)),
        ),
      );
    } else if (all == null) {
      body = Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              color: context.ez.ink,
              strokeWidth: 3,
            ),
          ),
        ),
      );
    } else {
      final months = withoutCategories(all, filters.hidden);
      final ranked = rankedCategories(months);
      if (ranked.isEmpty) {
        body = _Empty(scope: filters.scope);
      } else {
        final index = _picked == null
            ? null
            : months.indexWhere((m) => m.month == _picked);
        final picked = index == null || index < 0 ? null : index;
        final colors = categoryColors(context, ranked);
        body = Opacity(
          opacity: async.isLoading ? 0.5 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChartCard(
                months: months,
                ranked: ranked,
                colors: colors,
                picked: picked,
                onSelect: (i) => setState(
                  () => _picked = i == picked ? null : months[i].month,
                ),
              ),
              const SizedBox(height: 16),
              if (picked == null)
                _Overview(months: months)
              else
                _MonthCard(
                  months: months,
                  index: picked,
                  colors: colors,
                  onClose: () => setState(() => _picked = null),
                ),
            ],
          ),
        );
      }
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(filters.scope),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 24, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Analytics',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _FiltersButton(
                    filters: filters,
                    onTap: () => showAnalyticsFilters(
                      context,
                      categories: rankedCategories(all ?? const []),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.filters, required this.onTap});

  final AnalyticsFilters filters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final badges = [
      if (filters.scope != AnalyticsScope.all) filters.scope.label,
      if (filters.hidden.isNotEmpty) '${filters.hidden.length} hidden',
    ];
    return BrutalSurface(
      color: c.card,
      borderWidth: kPillBorder,
      radius: 999,
      shadowOffset: 3,
      isButton: true,
      onTap: onTap,
      semanticLabel: badges.isEmpty
          ? 'Filters'
          : 'Filters, ${badges.join(', ')}',
      constraints: const BoxConstraints(minHeight: kMinTap),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.tune, size: 20, color: c.ink),
          const SizedBox(width: 6),
          Text(
            'Filters',
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          for (final b in badges) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: c.ink,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                b,
                style: text.labelSmall?.copyWith(
                  color: c.bg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.months,
    required this.ranked,
    required this.colors,
    required this.picked,
    required this.onSelect,
  });

  final List<AnalyticsMonth> months;
  final List<CategorySpend> ranked;
  final Map<String, Color> colors;
  final int? picked;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final change = changePercent(months, months.length - 1);
    return BrutalCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Your share by month',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (change != null)
                  _TrendBadge(
                    percent: change,
                    previous: months[months.length - 2].month,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          MonthlyBarChart(
            months: months,
            order: [for (final c in ranked) categoryKey(c.name)],
            colors: colors,
            selected: picked,
            onSelect: onSelect,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final c in ranked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Swatch(color: colors[categoryKey(c.name)]!, size: 12),
                      const SizedBox(width: 5),
                      Text(c.name, style: text.labelSmall),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.percent, required this.previous});

  final int percent;
  final DateTime previous;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final up = percent > 0;
    final flat = percent == 0;
    final label = flat
        ? 'Same as ${DateFormat('MMM').format(previous)}'
        : '${percent.abs()}% vs ${DateFormat('MMM').format(previous)}';
    return Semantics(
      label:
          '${flat
              ? 'No change'
              : up
              ? 'Up ${percent.abs()}%'
              : 'Down ${percent.abs()}%'} '
          'from ${monthTitle(previous)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: up ? c.peach : c.mint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.line, width: kPillBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              flat
                  ? Symbols.trending_flat
                  : up
                  ? Symbols.trending_up
                  : Symbols.trending_down,
              size: 18,
              color: onAccent,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: onAccent, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.size = 14});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: context.ez.line, width: 1.5),
    ),
  );
}

/// Shown while no month is picked.
class _Overview extends StatelessWidget {
  const _Overview({required this.months});

  final List<AnalyticsMonth> months;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final highest = highestMonth(months)!;
    final counted = months.length > 12 ? 12 : months.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _StatCard(
                label: 'Monthly average',
                value: formatRupees(averagePaise(months)),
                detail: counted == 1 ? 'last month' : 'last $counted months',
                color: c.green,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _StatCard(
                label: 'Highest month',
                value: formatRupees(highest.totalPaise),
                detail: monthTitle(highest.month),
                color: c.mint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Symbols.touch_app, color: c.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tap a month to see its categories.',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = TextStyle(color: onAccent);
    return BrutalCard(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall?.merge(style)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              softWrap: false,
              style: text.titleLarge
                  ?.merge(style)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(detail, style: text.labelSmall?.merge(style)),
        ],
      ),
    );
  }
}

/// The picked month: a donut and its categories, largest first.
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.months,
    required this.index,
    required this.colors,
    required this.onClose,
  });

  final List<AnalyticsMonth> months;
  final int index;
  final Map<String, Color> colors;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final month = months[index];
    final split = foldSmall(month.categories);
    final total = month.totalPaise;
    final before = index > 0 ? months[index - 1] : null;
    final diff = before == null ? null : total - before.totalPaise;
    String percent(int paise) =>
        total <= 0 ? '0%' : '${(paise * 100 / total).round()}%';
    final others = month.otherCurrencyCount;

    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthTitle(month.month),
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              BrutalSurface(
                color: c.card,
                borderWidth: kPillBorder,
                radius: 10,
                showShadow: false,
                isButton: true,
                semanticLabel: 'Close month',
                onTap: onClose,
                constraints: const BoxConstraints(
                  minWidth: kMinTap,
                  minHeight: kMinTap,
                ),
                child: Center(child: Icon(Symbols.close, color: c.ink)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (total <= 0)
            Text(
              'No spending in ${monthTitle(month.month)}.',
              style: text.bodyLarge,
            )
          else ...[
            Center(
              child: Semantics(
                label:
                    '${monthTitle(month.month)} by category: '
                    '${[for (final s in split.big) '${s.name} ${percent(s.paise)}', if (split.otherCount > 0) 'Other ${percent(split.otherPaise)}'].join(', ')}',
                excludeSemantics: true,
                child: Donut(
                  slices: [
                    for (final s in split.big)
                      (paise: s.paise, color: colors[categoryKey(s.name)]!),
                    if (split.otherCount > 0)
                      (paise: split.otherPaise, color: EzColors.disabled),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Your share', style: text.labelSmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatRupees(total),
                          softWrap: false,
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (diff != null && diff != 0)
                        Text(
                          '${diff > 0 ? '↑' : '↓'} ${formatRupees(diff.abs())} vs ${DateFormat('MMM').format(before!.month)}',
                          style: text.labelSmall,
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (others > 0)
            Text(
              '$others ${others == 1 ? 'expense' : 'expenses'} in other currencies not counted',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            Divider(color: c.line, thickness: kPillBorder, height: 2),
            for (final s in split.big)
              _CategoryRow(
                name: s.name,
                icon: s.icon,
                color: colors[categoryKey(s.name)]!,
                percent: percent(s.paise),
                paise: s.paise,
                onTap: () => context.push(
                  Uri(
                    path: '/analytics/category',
                    queryParameters: {
                      'month': DateFormat('y-MM').format(month.month),
                      'name': s.name,
                    },
                  ).toString(),
                ),
              ),
            if (split.otherCount > 0)
              _CategoryRow(
                name: 'Other · ${split.otherCount} small',
                icon: 'more_horiz',
                color: EzColors.disabled,
                percent: percent(split.otherPaise),
                paise: split.otherPaise,
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.icon,
    required this.color,
    required this.percent,
    required this.paise,
    this.onTap,
  });

  final String name;
  final String icon;
  final Color color;
  final String percent;
  final int paise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinTap + 4),
      child: Row(
        children: [
          _Swatch(color: color),
          const SizedBox(width: 10),
          ExcludeSemantics(child: CategoryIcon(icon, c.ink, size: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Text(percent, style: text.bodySmall),
          const SizedBox(width: 10),
          Text(
            formatRupees(paise),
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(
            width: 24,
            child: onTap == null
                ? null
                : Icon(Symbols.chevron_right, size: 20, color: c.ink),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$name, $percent, ${formatRupees(paise)}',
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.scope});

  final AnalyticsScope scope;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final message = switch (scope) {
      AnalyticsScope.all => 'Add an expense in a group or on your own, and your spending shows up here.',
      AnalyticsScope.groups => 'You have no group expenses yet. Change the filters to see personal spending.',
      AnalyticsScope.personal => 'You have no personal expenses yet. Add one, or change the filters to see group spending.',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Transform.rotate(
            angle: -0.1,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: c.lilac,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.line, width: kCardBorder),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(kShadowOffset, kShadowOffset),
                    color: c.line,
                  ),
                ],
              ),
              child: const Icon(Symbols.bar_chart, size: 44, color: onAccent),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No spending to show',
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
          ),
          if (scope != AnalyticsScope.all) ...[
            const SizedBox(height: 20),
            Consumer(
              builder: (context, ref, _) => BrutalButton(
                label: 'Show all',
                onPressed: () => ref
                    .read(analyticsFiltersProvider.notifier)
                    .set(
                      AnalyticsFilters(
                        hidden: ref.read(analyticsFiltersProvider).hidden,
                      ),
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
