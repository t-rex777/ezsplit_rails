import 'package:ezsplit_mobile/data/analytics_repository.dart';
import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/widgets/brutal_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

extension on CategorySpend {
  CategorySpend copyWithPaise(int paise) =>
      CategorySpend(name: name, icon: icon, color: color, paise: paise);
}

const food = CategorySpend(
  name: 'Food',
  icon: 'restaurant',
  color: '#EF9F27',
  paise: 0,
);

AnalyticsMonth month(int m, {int food = 0, int travel = 0, int rent = 0}) {
  final cats = [
    if (food > 0)
      CategorySpend(
        name: 'Food',
        icon: 'restaurant',
        color: '#EF9F27',
        paise: food,
      ),
    if (travel > 0)
      CategorySpend(
        name: 'Travel',
        icon: 'flight',
        color: '#AFA9EC',
        paise: travel,
      ),
    if (rent > 0)
      CategorySpend(name: 'Rent', icon: 'home', color: '#5DCAA5', paise: rent),
  ]..sort((a, b) => b.paise.compareTo(a.paise));
  return AnalyticsMonth(
    month: DateTime(2026, m),
    totalPaise: cats.fold(0, (s, c) => s + c.paise),
    categories: cats,
  );
}

FakeAnalyticsRepository sampleRepo() => FakeAnalyticsRepository(
  byScope: {
    AnalyticsScope.all: [
      month(8, food: 400000, travel: 200000, rent: 248000),
      month(9, food: 400000, travel: 300000, rent: 300000),
      month(10, food: 500000, travel: 400000, rent: 340000),
    ],
    AnalyticsScope.personal: [month(10, food: 98000)],
  },
);

Future<ProviderContainer> pumpAnalytics(
  WidgetTester tester,
  FakeAnalyticsRepository repo,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(
    tester,
    FakeAuthRepository(current: testUser),
    extraOverrides: repoOverrides(
      FakeGroupsRepository(),
      FakeUsersRepository(),
      analytics: repo,
    ),
  );
  routerOf(c).go('/analytics');
  await tester.pumpAndSettle();
  return c;
}

/// The page list, not the sideways chart.
final page = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Future<void> applyFilters(WidgetTester tester) async {
  await tester.tap(find.textContaining('Apply'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a bar per month, the trend and the overview', (
    tester,
  ) async {
    await pumpAnalytics(tester, sampleRepo());

    for (final m in ['2026-08', '2026-09', '2026-10']) {
      expect(find.byKey(ValueKey('bar-$m')), findsOneWidget, reason: m);
    }
    // October ₹12,400 against September ₹10,000.
    expect(find.text('24% vs Sep'), findsOneWidget);
    expect(find.text('Monthly average'), findsOneWidget);
    expect(find.text('₹10,293'), findsOneWidget);
    expect(find.text('Highest month'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Tap a month to see its categories.'), findsOneWidget);
  });

  testWidgets('tapping a month shows its pie and categories, and closes', (
    tester,
  ) async {
    await pumpAnalytics(tester, sampleRepo());

    await tester.tap(find.byKey(const ValueKey('bar-2026-09')));
    await tester.pumpAndSettle();

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('₹10,000'), findsOneWidget);
    expect(find.text('↑ ₹1,520 vs Aug'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(InkWell, 'Rent'),
      200,
      scrollable: page,
    );
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('Tap a month to see its categories.'), findsNothing);

    await tester.scrollUntilVisible(
      find.byIcon(Symbols.close),
      -200,
      scrollable: page,
    );
    await tester.tap(find.byIcon(Symbols.close));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsNothing);
    expect(find.text('Tap a month to see its categories.'), findsOneWidget);
  });

  testWidgets('a category row opens that month\'s expenses', (tester) async {
    final repo = sampleRepo()
      ..expenseRows = [
        AnalyticsExpense(
          id: 9,
          name: 'Beach dinner',
          date: DateTime(2026, 10, 27),
          mySharePaise: 135000,
          groupName: 'Goa trip',
        ),
        AnalyticsExpense(
          id: 10,
          name: 'Groceries',
          date: DateTime(2026, 10, 24),
          mySharePaise: 98000,
        ),
      ];
    await pumpAnalytics(tester, repo);

    await tester.tap(find.byKey(const ValueKey('bar-2026-10')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(InkWell, 'Food'),
      200,
      scrollable: page,
    );
    await tester.drag(page, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Food'));
    await tester.pumpAndSettle();

    expect(repo.expenseRequests.single, (
      month: DateTime(2026, 10),
      category: 'Food',
      scope: AnalyticsScope.all,
    ));
    expect(find.text('₹2,330'), findsOneWidget);
    expect(find.text('Beach dinner'), findsOneWidget);
    expect(find.text('27 Oct · Goa trip'), findsOneWidget);
    expect(find.text('24 Oct · No group'), findsOneWidget);
  });

  testWidgets('the Personal scope reloads and marks the Filters button', (
    tester,
  ) async {
    final repo = sampleRepo();
    await pumpAnalytics(tester, repo);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BrutalPill, 'Personal'));
    await tester.pump();
    await applyFilters(tester);

    expect(repo.requested.last, AnalyticsScope.personal);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.byKey(const ValueKey('bar-2026-08')), findsNothing);
    expect(find.byKey(const ValueKey('bar-2026-10')), findsOneWidget);
  });

  testWidgets('unticking a category takes it out of the totals', (
    tester,
  ) async {
    await pumpAnalytics(tester, sampleRepo());

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Apply · 3 of 3 categories'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-food')));
    await tester.pump();
    expect(find.text('Apply · 2 of 3 categories'), findsOneWidget);
    await applyFilters(tester);

    expect(find.text('1 hidden'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bar-2026-10')));
    await tester.pumpAndSettle();
    // ₹12,400 without ₹5,000 of food.
    expect(find.text('₹7,400'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(InkWell, 'Rent'),
      200,
      scrollable: page,
    );
    expect(find.text('Food'), findsNothing);
  });

  testWidgets('Clear disables Apply, Select all brings it back', (
    tester,
  ) async {
    await pumpAnalytics(tester, sampleRepo());
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Apply · 0 of 3 categories'), findsOneWidget);
    await tester.tap(find.textContaining('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Apply · 0 of 3 categories'), findsOneWidget);

    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('Apply · 3 of 3 categories'), findsOneWidget);
  });

  testWidgets('an empty scope offers a way back to all spending', (
    tester,
  ) async {
    final repo = FakeAnalyticsRepository(
      byScope: {
        AnalyticsScope.all: [month(10, food: 1000)],
      },
    );
    await pumpAnalytics(tester, repo);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BrutalPill, 'Groups'));
    await tester.pump();
    await applyFilters(tester);

    expect(find.text('No spending to show'), findsOneWidget);
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bar-2026-10')), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (tester) async {
    final repo = sampleRepo()..error = const ApiError(message: 'Server down');
    await pumpAnalytics(tester, repo);
    expect(find.text('Server down'), findsOneWidget);

    repo.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bar-2026-10')), findsOneWidget);
  });

  testWidgets('a picked old month stays in view after a filter change', (
    tester,
  ) async {
    final long = [
      for (var i = 0; i < 24; i++)
        AnalyticsMonth(
          month: DateTime(2024, 11 + i),
          totalPaise: 100000 + i * 1000,
          categories: [food.copyWithPaise(100000 + i * 1000)],
        ),
    ];
    await pumpAnalytics(
      tester,
      FakeAnalyticsRepository(
        byScope: {AnalyticsScope.all: long, AnalyticsScope.personal: long},
      ),
    );
    const first = ValueKey('bar-2024-11');
    expect(find.byKey(first).hitTestable(), findsNothing);
    await tester.fling(
      find.byKey(const ValueKey('bar-2026-10')),
      const Offset(2000, 0),
      3000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(first));
    await tester.pumpAndSettle();
    expect(find.text('November 2024'), findsOneWidget);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BrutalPill, 'Personal'));
    await tester.pump();
    await applyFilters(tester);

    expect(find.text('November 2024'), findsOneWidget);
    expect(find.byKey(first).hitTestable(), findsOneWidget);
  });
}
