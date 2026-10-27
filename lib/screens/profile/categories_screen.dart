import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/categories_repository.dart';
import '../../data/models.dart';
import '../../state/group_detail.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_sheet.dart';
import '../groups/group_widgets.dart';
import 'category_sheet.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  Future<void> _options(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final choice = await showBrutalSheet<String>(
      context,
      title: category.name,
      child: Builder(
        builder: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrutalButton(
              label: 'Edit',
              icon: Symbols.edit,
              onPressed: () => Navigator.of(ctx).pop('edit'),
            ),
            const SizedBox(height: 12),
            BrutalButton(
              label: 'Delete',
              icon: Symbols.delete,
              color: ctx.ez.peach,
              onPressed: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'edit') {
      await showCategorySheet(context, existing: category);
    } else if (choice == 'delete') {
      final repo = ref.read(categoriesRepositoryProvider);
      final container = ProviderScope.containerOf(context);
      final deleted = await confirmAndRun(
        context,
        title: 'Delete ${category.name}?',
        body: "It disappears from your category list. The server may refuse if expenses use it.",
        confirmLabel: 'Delete',
        destructive: true,
        action: () => repo.delete(category.id),
      );
      if (deleted) refreshCategoryViews(container);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final categories = ref.watch(categoriesProvider);
    final list = categories.value;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to profile',
                    constraints: const BoxConstraints(
                      minWidth: kMinTap,
                      minHeight: kMinTap,
                    ),
                    onPressed: () => _back(context),
                    icon: const Icon(Symbols.arrow_back),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Categories',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  BrutalSurface(
                    color: c.green,
                    borderWidth: kPillBorder,
                    radius: 999,
                    shadowOffset: 3,
                    isButton: true,
                    semanticLabel: 'Add category',
                    onTap: () => showCategorySheet(context),
                    constraints: const BoxConstraints(
                      minWidth: kMinTap,
                      minHeight: kMinTap,
                    ),
                    child: const Center(
                      child: Icon(Symbols.add, color: onAccent),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list != null
                  ? _CategoryList(
                      categories: list,
                      onOptions: (cat) => _options(context, ref, cat),
                    )
                  : categories.hasError
                  ? RetryMessage(
                      message: errorMessage(categories.error!),
                      onRetry: () => ref.invalidate(categoriesProvider),
                    )
                  : Center(child: CircularProgressIndicator(color: c.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories, required this.onOptions});

  final List<Category> categories;
  final ValueChanged<Category> onOptions;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    if (categories.isEmpty) {
      return const Center(child: Text('No categories yet. Add one.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final cat = categories[i];
        return BrutalCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              IconTile(
                icon: cat.icon,
                color: parseHexColor(cat.color, c.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: '${cat.name} options',
                constraints: const BoxConstraints(
                  minWidth: kMinTap,
                  minHeight: kMinTap,
                ),
                onPressed: () => onOptions(cat),
                icon: const Icon(Symbols.more_vert),
              ),
            ],
          ),
        );
      },
    );
  }
}
