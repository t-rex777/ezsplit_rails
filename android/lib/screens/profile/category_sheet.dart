import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/categories_repository.dart';
import '../../data/models.dart';
import '../../state/group_detail.dart';
import '../../state/summary.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_input.dart';
import '../../widgets/brutal_sheet.dart';
import '../../widgets/category_icon.dart';
import '../groups/group_widgets.dart';

/// The icons a category can use: the Material Symbols name and its label.
const categoryIconChoices = [
  ('local_cafe', 'Coffee'),
  ('directions_car', 'Car'),
  ('redeem', 'Gift'),
  ('movie', 'Movie'),
  ('favorite', 'Health'),
  ('more_horiz', 'More'),
  ('restaurant', 'Food'),
  ('flight', 'Travel'),
  ('home', 'Home'),
  ('shopping_cart', 'Shopping'),
  ('bolt', 'Bills'),
  ('local_taxi', 'Taxi'),
];

/// The palette colors as `#RRGGBB`, with their names.
const categoryColorChoices = [
  ('#FAC775', 'Amber'),
  ('#AFA9EC', 'Lilac'),
  ('#5DCAA5', 'Mint'),
  ('#F4C0D1', 'Pink'),
  ('#B5D4F4', 'Blue'),
  ('#F5C4B3', 'Peach'),
];

/// Adds a category, or edits [existing]. Returns true once it is saved.
Future<bool> showCategorySheet(
  BuildContext context, {
  Category? existing,
}) async {
  final saved = await showBrutalSheet<bool>(
    context,
    title: existing == null ? 'New category' : 'Edit category',
    // Dragging could close the sheet while the save is posting.
    enableDrag: false,
    child: _CategoryForm(existing: existing),
  );
  return saved ?? false;
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.existing});

  final Category? existing;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  late final TextEditingController _name;
  late String _icon;
  late String _color;
  bool _posting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _icon = e?.icon ?? categoryIconChoices.first.$1;
    _color = e?.color.toUpperCase() ?? categoryColorChoices.first.$1;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => _name.text.trim().isNotEmpty && !_posting;

  Future<void> _save() async {
    final repo = ref.read(categoriesRepositoryProvider);
    // Captured now: the sheet may be gone when the save ends.
    final container = ProviderScope.containerOf(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    final existing = widget.existing;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      if (existing == null) {
        await repo.create(name: name, icon: _icon, color: _color);
      } else {
        await repo.update(existing.id, name: name, icon: _icon, color: _color);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _error = errorMessage(e);
      });
      return;
    }
    refreshCategoryViews(container);
    if (mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_posting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrutalInput(
            label: 'Name',
            controller: _name,
            textInputAction: TextInputAction.done,
            errorText: _error,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 16),
          Text(
            'Icon',
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, label) in categoryIconChoices)
                BrutalSurface(
                  color: name == _icon ? c.ink : c.card,
                  borderWidth: kCardBorder,
                  radius: kCardRadius,
                  shadowOffset: 3,
                  showShadow: name == _icon,
                  isButton: true,
                  semanticLabel: '$label icon',
                  onTap: _posting ? null : () => setState(() => _icon = name),
                  constraints: const BoxConstraints(
                    minWidth: kMinTap + 4,
                    minHeight: kMinTap + 4,
                  ),
                  child: Center(
                    child: CategoryIcon(name, name == _icon ? c.bg : c.ink),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Color',
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (hex, label) in categoryColorChoices)
                _Swatch(
                  label: label,
                  color: parseHexColor(hex, c.amber),
                  selected: hex == _color,
                  onTap: _posting ? null : () => setState(() => _color = hex),
                ),
            ],
          ),
          const SizedBox(height: 20),
          BrutalButton(
            label: widget.existing == null ? 'Add category' : 'Save',
            onPressed: _canSave ? _save : null,
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: kMinTap,
          height: kMinTap,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: c.line, width: kCardBorder),
                boxShadow: selected
                    ? [BoxShadow(offset: const Offset(3, 3), color: c.line)]
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 18, color: onAccent)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reloads everything that shows categories: the lists and pickers, the
/// group expenses, and the dashboard's category totals.
void refreshCategoryViews(ProviderContainer container) {
  container
    ..invalidate(categoriesProvider)
    ..invalidate(groupExpensesProvider)
    ..invalidate(monthlySummaryProvider);
}
