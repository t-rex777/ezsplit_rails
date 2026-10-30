import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/analytics_repository.dart';
import '../../data/models.dart';
import '../../domain/analytics.dart';
import '../../state/analytics.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_pill.dart';
import '../../widgets/brutal_sheet.dart';
import '../groups/group_widgets.dart';

/// Scope and category filters. Changes apply only on Apply.
Future<void> showAnalyticsFilters(
  BuildContext context, {
  required List<CategorySpend> categories,
}) => showBrutalSheet<void>(
  context,
  title: 'Filters',
  child: _FiltersForm(categories: categories),
);

class _FiltersForm extends ConsumerStatefulWidget {
  const _FiltersForm({required this.categories});

  final List<CategorySpend> categories;

  @override
  ConsumerState<_FiltersForm> createState() => _FiltersFormState();
}

class _FiltersFormState extends ConsumerState<_FiltersForm> {
  late AnalyticsScope _scope = ref.read(analyticsFiltersProvider).scope;
  late Set<String> _hidden = {...ref.read(analyticsFiltersProvider).hidden};

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final heading = text.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    final keys = [for (final cat in widget.categories) categoryKey(cat.name)];
    final shown = keys.where((k) => !_hidden.contains(k)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Show expenses from', style: heading),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in AnalyticsScope.values)
              BrutalPill(
                label: s.label,
                selected: s == _scope,
                onTap: () => setState(() => _scope = s),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text('Categories', style: heading)),
            TextButton(
              onPressed: () => setState(() => _hidden = {}),
              style: TextButton.styleFrom(
                foregroundColor: c.ink,
                minimumSize: const Size(kMinTap, kMinTap),
              ),
              child: const Text('Select all'),
            ),
            TextButton(
              onPressed: () => setState(() => _hidden = {...keys}),
              style: TextButton.styleFrom(
                foregroundColor: c.ink,
                minimumSize: const Size(kMinTap, kMinTap),
              ),
              child: const Text('Clear'),
            ),
          ],
        ),
        if (widget.categories.isEmpty)
          Text('No categories with spending yet.', style: text.bodyMedium)
        else
          // Material, not a coloured box, so the tiles' ripples show.
          Material(
            color: c.card,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kCardRadius),
              side: BorderSide(color: c.line, width: kCardBorder),
            ),
            child: Column(
              children: [
                for (var i = 0; i < widget.categories.length; i++)
                  CheckboxListTile(
                    key: ValueKey('filter-${keys[i]}'),
                    value: !_hidden.contains(keys[i]),
                    onChanged: (on) => setState(
                      () => on == true
                          ? _hidden.remove(keys[i])
                          : _hidden.add(keys[i]),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: c.ink,
                    checkColor: c.bg,
                    title: Row(
                      children: [
                        IconTile(
                          icon: widget.categories[i].icon,
                          color: parseHexColor(
                            widget.categories[i].color,
                            c.amber,
                          ),
                          size: 34,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(widget.categories[i].name)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        BrutalButton(
          label: widget.categories.isEmpty
              ? 'Apply'
              : 'Apply · $shown of ${keys.length} categories',
          onPressed: shown == 0 && keys.isNotEmpty
              ? null
              : () {
                  ref
                      .read(analyticsFiltersProvider.notifier)
                      .set(AnalyticsFilters(scope: _scope, hidden: _hidden));
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}
