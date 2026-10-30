import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/money.dart';
import '../../state/analytics.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_card.dart';
import '../groups/group_widgets.dart';
import 'analytics_screen.dart' show monthTitle;

/// My share of one category in one month, expense by expense.
class AnalyticsCategoryScreen extends ConsumerWidget {
  const AnalyticsCategoryScreen({
    super.key,
    required this.month,
    required this.name,
  });

  final DateTime month;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final scope = ref.watch(analyticsFiltersProvider).scope;
    final key = (month: month, category: name, scope: scope);
    final async = ref.watch(analyticsExpensesProvider(key));
    final rows = async.value;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(
        child: switch ((rows, async.hasError)) {
          (null, true) => RetryMessage(
            message: errorMessage(async.error!),
            onRetry: () => ref.invalidate(analyticsExpensesProvider(key)),
          ),
          (null, false) => Center(
            child: CircularProgressIndicator(color: c.ink, strokeWidth: 3),
          ),
          (final list?, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 24, 24),
            children: [
              BrutalCard(
                color: c.amber,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatWholeRupees(
                        list.fold(0, (sum, e) => sum + e.mySharePaise),
                      ),
                      style: text.headlineMedium?.copyWith(
                        color: onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Your share · ${monthTitle(month)}',
                      style: text.bodyMedium?.copyWith(color: onAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${scope.label} expenses · ${list.length} in ${DateFormat('MMMM').format(month)}',
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              if (list.isEmpty)
                BrutalCard(
                  child: Text(
                    'No $name expenses in ${monthTitle(month)}.',
                    style: text.bodyLarge,
                  ),
                )
              else
                BrutalCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0)
                          Divider(
                            color: c.line,
                            thickness: kPillBorder,
                            height: 2,
                          ),
                        InkWell(
                          onTap: () => context.push('/expenses/${list[i].id}'),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 56),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        list[i].name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${DateFormat('d MMM').format(list[i].date)} · ${list[i].groupName ?? 'No group'}',
                                        style: text.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatRupees(list[i].mySharePaise),
                                  style: text.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Icon(
                                  Symbols.chevron_right,
                                  size: 20,
                                  color: c.ink,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        },
      ),
    );
  }
}
