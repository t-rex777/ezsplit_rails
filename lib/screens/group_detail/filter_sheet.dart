import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/expenses_repository.dart';
import '../../data/models.dart';
import '../../state/group_detail.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_pill.dart';
import '../../widgets/brutal_sheet.dart';

/// Returns the filters to apply, or null when dismissed.
Future<ExpenseFilters?> showFilterSheet(
  BuildContext context, {
  required int groupId,
  required ExpenseFilters current,
}) => showBrutalSheet<ExpenseFilters>(
  context,
  title: 'Filter and sort',
  child: _FilterForm(groupId: groupId, current: current),
);

const _sortLabels = {
  ExpenseSort.newest: 'Newest',
  ExpenseSort.oldest: 'Oldest',
  ExpenseSort.amountDesc: 'Amount high',
  ExpenseSort.amountAsc: 'Amount low',
};

class _FilterForm extends ConsumerStatefulWidget {
  const _FilterForm({required this.groupId, required this.current});

  final int groupId;
  final ExpenseFilters current;

  @override
  ConsumerState<_FilterForm> createState() => _FilterFormState();
}

class _FilterFormState extends ConsumerState<_FilterForm> {
  late ExpenseFilters _pending = widget.current;
  Timer? _debounce;
  int? _count;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _countSoon();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _change(ExpenseFilters next) {
    setState(() {
      _pending = next;
      _count = null;
    });
    _countSoon();
  }

  /// A dry run of page 1 with the pending filters; only its meta total is used.
  void _countSoon() {
    _debounce?.cancel();
    final mine = ++_request;
    if (_pending.onlyUnsettled) return;
    final pending = _pending;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final page = await ref
            .read(expensesRepositoryProvider)
            .list(pending.toQuery(widget.groupId, page: 1));
        // A newer change has started its own count; ignore this late answer.
        if (mounted && mine == _request) setState(() => _count = page.total);
      } catch (_) {
        // The button falls back to "Show expenses".
      }
    });
  }

  void _toggleCategory(int id) {
    final ids = [..._pending.categoryIds];
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    ids.sort();
    _change(_pending.copyWith(categoryIds: ids));
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _pending.from != null && _pending.to != null
          ? DateTimeRange(start: _pending.from!, end: _pending.to!)
          : null,
    );
    if (picked == null || !mounted) return;
    _change(_pending.copyWith(from: () => picked.start, to: () => picked.end));
  }

  String get _buttonLabel {
    final n = _count;
    if (_pending.onlyUnsettled || n == null) return 'Show expenses';
    return 'Show $n ${n == 1 ? 'expense' : 'expenses'}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final f = _pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: () => _change(ExpenseFilters(q: _pending.q)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kMinTap,
                  minWidth: kMinTap,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    'Reset',
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _Section(
          'Sort by',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _sortLabels.entries)
                BrutalPill(
                  label: e.value,
                  selected: f.sort == e.key,
                  onTap: () => _change(f.copyWith(sort: e.key)),
                ),
            ],
          ),
        ),
        if (categories.isNotEmpty)
          _Section(
            'Category',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in categories)
                  BrutalPill(
                    label: c.name,
                    selected: f.categoryIds.contains(c.id),
                    onTap: () => _toggleCategory(c.id),
                  ),
              ],
            ),
          ),
        _Section(
          'Paid by',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BrutalPill(
                label: 'Anyone',
                selected: f.paidBy == null,
                onTap: () => _change(f.copyWith(paidBy: () => null)),
              ),
              BrutalPill(
                label: 'Me',
                selected: f.paidBy == PaidBy.me,
                onTap: () => _change(f.copyWith(paidBy: () => PaidBy.me)),
              ),
              BrutalPill(
                label: 'Others',
                selected: f.paidBy == PaidBy.others,
                onTap: () => _change(f.copyWith(paidBy: () => PaidBy.others)),
              ),
            ],
          ),
        ),
        _Section(
          'Date',
          BrutalCard(
            onTap: _pickDates,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Symbols.calendar_month),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _dateRangeLabel(f.from, f.to),
                    style: text.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          toggled: f.onlyUnsettled,
          child: InkWell(
            onTap: () => _change(f.copyWith(onlyUnsettled: !f.onlyUnsettled)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kMinTap),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Only unsettled',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: Switch(value: f.onlyUnsettled, onChanged: (_) {}),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        BrutalButton(
          label: _buttonLabel,
          onPressed: () => Navigator.of(context).pop(_pending),
        ),
      ],
    );
  }
}

String _dateRangeLabel(DateTime? from, DateTime? to) {
  if (from == null || to == null) return 'Any date';
  final fmt = DateFormat('MMM d, y');
  return '${fmt.format(from)} – ${fmt.format(to)}';
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
