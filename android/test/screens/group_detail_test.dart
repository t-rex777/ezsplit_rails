import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ezsplit_mobile/data/jsonapi.dart' show JsonApiDoc;
import 'package:ezsplit_mobile/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ezsplit_mobile/screens/group_detail/balances_view.dart';
import 'package:ezsplit_mobile/state/group_detail.dart';
import 'package:ezsplit_mobile/theme/app_theme.dart';
import 'package:ezsplit_mobile/widgets/brutal_card.dart';
import 'package:ezsplit_mobile/state/summary.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

class Setup {
  Setup({List<Expense>? expenses, List<BalanceRow>? balances, int? pageSize})
    : expenses = FakeExpensesRepository(
        expenses: expenses ?? [makeExpense(1, 'Dinner')],
        pageSize: pageSize,
      ),
      balances = FakeBalancesRepository(balances ?? goaBalances());

  final groups = FakeGroupsRepository(
    groups: [
      makeGroup(
        1,
        'Goa trip',
        members: const [milisha, riya, arjun, neha],
        ownerId: 2,
      ),
    ],
  );
  final FakeExpensesRepository expenses;
  final FakeBalancesRepository balances;
  final settlements = FakeSettlementsRepository();
  final summary = FakeSummaryRepository();
}

Future<ProviderContainer> open(
  WidgetTester tester,
  Setup s, {
  String path = '/groups/1',
}) async {
  tester.view.physicalSize = const Size(600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(
    tester,
    FakeAuthRepository(current: milisha),
    extraOverrides: detailOverrides(
      groups: s.groups,
      expenses: s.expenses,
      balances: s.balances,
      settlements: s.settlements,
      summary: s.summary,
    ),
  );
  routerOf(c).go(path);
  await tester.pumpAndSettle();
  return c;
}

void main() {
  group('Group detail header', () {
    testWidgets('shows my net from my balance row', (tester) async {
      await open(tester, Setup());
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text("you're owed overall"), findsOneWidget);
      expect(find.text('₹1,850'), findsOneWidget);
    });

    testWidgets('view query opens the Balances view', (tester) async {
      await open(tester, Setup(), path: '/groups/1?view=balances');
      expect(find.text('Simplest way to settle'), findsOneWidget);
    });
  });

  group('Group not found', () {
    testWidgets('a group that fails to load says so, with retry and no Add', (
      tester,
    ) async {
      final s = Setup()..groups.groups = [];
      await open(tester, s, path: '/groups/9');
      expect(find.text('Group not found'), findsOneWidget);
      expect(find.byTooltip('Add expense'), findsNothing);
      expect(find.bySemanticsLabel('Add expense'), findsNothing);
      expect(find.text('Dinner'), findsNothing);
      final gets = s.groups.gets;

      s.groups.groups = [
        makeGroup(9, 'Late group', members: const [milisha]),
      ];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(s.groups.gets, greaterThan(gets));
      expect(find.text('Group not found'), findsNothing);
      expect(find.text('Late group'), findsOneWidget);
    });

    testWidgets('a non-numeric id is not found and makes no request', (
      tester,
    ) async {
      final s = Setup();
      await open(tester, s, path: '/groups/abc');
      expect(find.text('Group not found'), findsOneWidget);
      expect(s.groups.gets, 0);
      expect(s.expenses.queries, isEmpty);
      expect(s.balances.calls, 0);
      expect(find.text('Try again'), findsNothing);
    });
  });

  group('Expenses view', () {
    testWidgets('a group with no expenses offers to add the first', (
      tester,
    ) async {
      await open(tester, Setup(expenses: []));
      expect(find.text('Add the first expense'), findsOneWidget);
    });

    testWidgets('rows are grouped by date with a word on each amount', (
      tester,
    ) async {
      await open(
        tester,
        Setup(
          expenses: [
            makeExpense(1, 'Dinner', paise: 300000, mine: -60000),
            makeExpense(
              2,
              'Hotel',
              paise: 900000,
              payer: milisha,
              mine: 720000,
              date: DateTime(2026, 10, 23),
            ),
          ],
        ),
      );
      expect(find.text('Oct 24'), findsOneWidget);
      expect(find.text('Oct 23'), findsOneWidget);
      expect(find.text('you owe'), findsOneWidget);
      expect(find.text('you lent'), findsOneWidget);
      expect(find.text('paid ₹3,000'), findsOneWidget);
      expect(find.text('Riya'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('search is debounced 300 ms and sent as q', (tester) async {
      final s = Setup();
      await open(tester, s);
      s.expenses.queries.clear();
      await tester.enterText(find.byType(TextField), 'din');
      await tester.pump(const Duration(milliseconds: 200));
      expect(s.expenses.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(s.expenses.queries.map((q) => q.q), ['din']);
    });

    testWidgets('the next page loads near the bottom', (tester) async {
      final s = Setup(
        expenses: [for (var i = 1; i <= 6; i++) makeExpense(i, 'Item $i')],
        pageSize: 3,
      );
      await open(tester, s);
      expect(s.expenses.queries.map((q) => q.page), contains(2));
      await tester.dragUntilVisible(
        find.text('Item 6'),
        find.byType(Scrollable).last,
        const Offset(0, -200),
      );
      expect(find.text('Item 6'), findsOneWidget);
    });

    testWidgets('reaching the bottom twice asks for page 2 once', (
      tester,
    ) async {
      final s = Setup(
        expenses: [for (var i = 1; i <= 6; i++) makeExpense(i, 'Item $i')],
        pageSize: 3,
      );
      await open(tester, s);
      final list = find.byType(Scrollable).last;
      await tester.drag(list, const Offset(0, -2000));
      await tester.drag(list, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(s.expenses.queries.where((q) => q.page == 2), hasLength(1));
      expect(s.expenses.queries.where((q) => (q.page ?? 1) > 2), isEmpty);
    });

    testWidgets('no next page means no further request', (tester) async {
      final s = Setup(expenses: [makeExpense(1, 'A'), makeExpense(2, 'B')]);
      await open(tester, s);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(s.expenses.queries, hasLength(1));
    });

    testWidgets('changing the search starts again at page 1', (tester) async {
      final s = Setup(
        expenses: [for (var i = 1; i <= 6; i++) makeExpense(i, 'Item $i')],
        pageSize: 3,
      );
      await open(tester, s);
      expect(s.expenses.queries.map((q) => q.page), contains(2));
      await tester.enterText(find.byType(TextField).first, 'item');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        s.expenses.queries.any((q) => q.q == 'item' && q.page == null),
        isTrue,
      );
    });

    testWidgets('changing a filter starts again at page 1', (tester) async {
      final s = Setup(
        expenses: [for (var i = 1; i <= 6; i++) makeExpense(i, 'Item $i')],
        pageSize: 3,
      );
      await open(tester, s);
      await tester.tap(find.bySemanticsLabel('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oldest'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Show'));
      await tester.pumpAndSettle();
      expect(
        s.expenses.queries.any(
          (q) => q.sort == ExpenseSort.oldest && q.page == null,
        ),
        isTrue,
      );
    });

    testWidgets('Only unsettled hides expenses where my amount is 0', (
      tester,
    ) async {
      final s = Setup(
        expenses: [
          makeExpense(1, 'Dinner'),
          makeExpense(2, 'Not mine', mine: 0),
        ],
      );
      await open(tester, s);
      expect(find.text('Not mine'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Only unsettled'));
      await tester.pumpAndSettle();
      expect(find.text('Show expenses'), findsOneWidget);
      await tester.tap(find.text('Show expenses'));
      await tester.pumpAndSettle();
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Not mine'), findsNothing);
    });

    testWidgets('tapping a row opens the expense', (tester) async {
      await open(tester, Setup());
      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();
      expect(find.text('Expense detail'), findsOneWidget);
      expect(find.text('Riya paid ₹1,000'), findsOneWidget);
    });

    testWidgets('the floating button adds an expense in this group', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final c = await open(tester, Setup());
      await tester.tap(find.bySemanticsLabel('Add expense'));
      await tester.pumpAndSettle();
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.text('all 4 members'), findsOneWidget);
      expect(
        routerOf(c).routerDelegate.currentConfiguration.last.matchedLocation,
        '/groups/1/expenses/new',
      );
    });
  });

  group('Long names and crore amounts', () {
    const long = User(
      id: 9,
      firstName: 'Bartholomew-Alexander-Montgomery-Featherstonehaugh',
      lastName: 'Kapoor',
      email: 'long@example.com',
    );

    testWidgets('expense rows ellipsize names and keep amounts whole', (
      tester,
    ) async {
      await open(
        tester,
        Setup(
          expenses: [
            makeExpense(
              1,
              'A very long expense name that keeps going and going past the edge',
              paise: 1000000000,
              payer: long,
              mine: -250000000,
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('you owe'), findsOneWidget);
      expect(find.text('₹25,00,000'), findsOneWidget);
      expect(find.text('paid ₹1,00,00,000'), findsOneWidget);
    });

    testWidgets('balance rows and transfers do not overflow', (tester) async {
      await open(
        tester,
        Setup(
          balances: [
            balanceRow(milisha, 1000000000),
            BalanceRow(
              userId: 9,
              firstName: long.firstName,
              lastName: long.lastName,
              currency: 'INR',
              paise: -1000000000,
            ),
          ],
        ),
        path: '/groups/1?view=balances',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('gets ₹1,00,00,000'), findsOneWidget);
      expect(find.text('₹1,00,00,000'), findsWidgets);
    });
  });

  group('Filter sheet', () {
    testWidgets('Amount high sorts by amount_desc', (tester) async {
      final s = Setup();
      await open(tester, s);
      await tester.tap(find.bySemanticsLabel('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amount high'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Show'));
      await tester.pumpAndSettle();
      expect(s.expenses.queries.last.sort, ExpenseSort.amountDesc);
      expect(s.expenses.queries.last.groupId, 1);
    });

    testWidgets('the button shows the dry-run total, debounced', (
      tester,
    ) async {
      final s = Setup();
      s.expenses.totalOverride = 12;
      await open(tester, s);
      s.expenses.queries.clear();
      await tester.tap(find.bySemanticsLabel('Filter'));
      await tester.pumpAndSettle();
      s.expenses.queries.clear();
      await tester.tap(find.text('Me'));
      await tester.tap(find.text('Others'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.expenses.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(s.expenses.queries, hasLength(1));
      expect(s.expenses.queries.single.paidBy, PaidBy.others);
      expect(s.expenses.queries.single.page, 1);
      expect(find.text('Show 12 expenses'), findsOneWidget);
    });

    testWidgets('categories narrow the query', (tester) async {
      final s = Setup();
      await open(tester, s);
      await tester.tap(find.bySemanticsLabel('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Show'));
      await tester.pumpAndSettle();
      expect(s.expenses.queries.last.categoryIds, [2]);
    });

    testWidgets('Reset clears filters but keeps the search text', (
      tester,
    ) async {
      final s = Setup();
      await open(tester, s);
      await tester.enterText(find.byType(TextField).first, 'din');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amount high'));
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Show'));
      await tester.pumpAndSettle();
      expect(s.expenses.queries.last.q, 'din');
      expect(s.expenses.queries.last.sort, isNull);
      final box = tester.widget<TextField>(find.byType(TextField).first);
      expect(box.controller!.text, 'din');
    });

    testWidgets('applying uses a search typed just before opening', (
      tester,
    ) async {
      final s = Setup();
      await open(tester, s);
      await tester.enterText(find.byType(TextField).first, 'din');
      await tester.tap(find.bySemanticsLabel('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amount high'));
      await tester.tap(find.textContaining('Show'));
      await tester.pumpAndSettle();
      expect(s.expenses.queries.last.q, 'din');
      expect(s.expenses.queries.last.sort, ExpenseSort.amountDesc);
    });

    testWidgets('dismissing the sheet still applies a pending search', (
      tester,
    ) async {
      final s = Setup();
      await open(tester, s);
      await tester.enterText(find.byType(TextField).first, 'din');
      await tester.tap(find.bySemanticsLabel('Filter'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(300, 20));
      await tester.pumpAndSettle();
      expect(s.expenses.queries.last.q, 'din');
    });

    testWidgets('Reset clears the pending filters', (tester) async {
      final s = Setup();
      await open(tester, s);
      await tester.tap(find.bySemanticsLabel('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amount high'));
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Show'));
      await tester.pumpAndSettle();
      expect(s.expenses.queries.last.sort, isNull);
    });
  });

  group('Balances view', () {
    testWidgets('lists gets and owes, and the simplest way to settle', (
      tester,
    ) async {
      await open(tester, Setup(), path: '/groups/1?view=balances');
      expect(find.text('gets ₹1,850'), findsOneWidget);
      expect(find.text('gets ₹900'), findsOneWidget);
      expect(find.text('owes ₹450'), findsOneWidget);
      expect(find.text('owes ₹2,300'), findsOneWidget);
      expect(find.text('Neha → You'), findsOneWidget);
      expect(find.text('Neha → Riya'), findsOneWidget);
      expect(find.text('Arjun → Riya'), findsOneWidget);
      expect(find.text('₹1,850'), findsWidgets);
      expect(find.text('₹450'), findsNWidgets(2));
    });

    testWidgets('the recorded fixture renders without error', (tester) async {
      final json = jsonDecode(
        File('test/fixtures/group_balances.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final rows = [
        for (final r in JsonApiDoc(json).rawList) BalanceRow.fromJson(r),
      ];
      await open(
        tester,
        Setup(balances: rows),
        path: '/groups/1?view=balances',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Simplest way to settle'), findsOneWidget);
      expect(find.text('gets ₹4,750'), findsOneWidget);
    });

    testWidgets('nets that do not sum to 0 hide the plan, not crash', (
      tester,
    ) async {
      await open(
        tester,
        Setup(balances: [balanceRow(milisha, 1000), balanceRow(riya, -400)]),
        path: '/groups/1?view=balances',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('gets ₹10'), findsOneWidget);
      expect(find.text('Simplest way to settle'), findsNothing);
      expect(find.text('Settle up'), findsNothing);
    });

    testWidgets('everyone settled shows no plan', (tester) async {
      await open(
        tester,
        Setup(balances: [balanceRow(milisha, 0), balanceRow(riya, 0)]),
        path: '/groups/1?view=balances',
      );
      expect(find.text("Everyone's settled up"), findsOneWidget);
      expect(find.text('Settle up'), findsNothing);
    });

    testWidgets('after a full settle-up the members show as settled up', (
      tester,
    ) async {
      await open(tester, Setup(balances: []), path: '/groups/1?view=balances');
      expect(find.text("Everyone's settled up"), findsOneWidget);
      expect(find.text('Riya'), findsOneWidget);
      expect(find.text('Neha'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Settle up'), findsNothing);
    });

    testWidgets('no rows and no group shows only the settled state', (
      tester,
    ) async {
      final s = Setup(balances: [])..groups.groups = [];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overridesFor(FakeAuthRepository(current: milisha)),
            ...detailOverrides(
              groups: s.groups,
              expenses: s.expenses,
              balances: s.balances,
            ),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const Scaffold(body: BalancesView(groupId: 1)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Everyone's settled up"), findsOneWidget);
      expect(find.byType(BrutalCard), findsNothing);
    });

    testWidgets('pull to refresh reloads the balances', (tester) async {
      final s = Setup();
      await open(tester, s, path: '/groups/1?view=balances');
      final before = s.balances.calls;
      await tester.fling(
        find.text('Simplest way to settle'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(s.balances.calls, greaterThan(before));
      expect(find.text('Simplest way to settle'), findsOneWidget);
    });
  });

  group('Settle up', () {
    testWidgets('owed money: asks the other person to record it', (
      tester,
    ) async {
      await open(tester, Setup(), path: '/groups/1?view=balances');
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      expect(find.text('Ask Neha to record it'), findsOneWidget);
      expect(find.text('Record payment'), findsNothing);
      expect(
        find.text('This records a payment. No money moves in the app.'),
        findsOneWidget,
      );
    });

    testWidgets('an amount over the full amount is rejected', (tester) async {
      await open(tester, Setup(), path: '/groups/1?view=balances');
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Part of it'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '2000');
      await tester.pump();
      expect(find.text("That's more than Neha owes"), findsOneWidget);
    });

    testWidgets('over the amount I owe says so, and Record stays off', (
      tester,
    ) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      await open(tester, s, path: '/groups/1?view=balances');
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Part of it'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '2000');
      await tester.pump();
      expect(find.text("That's more than you owe"), findsOneWidget);
      await tester.tap(find.text('Record payment'), warnIfMissed: false);
      await tester.pump();
      expect(s.settlements.created, isEmpty);
    });

    testWidgets('empty and zero disable Record', (tester) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      await open(tester, s, path: '/groups/1?view=balances');
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Part of it'));
      await tester.pump();
      for (final text in ['', '0']) {
        await tester.enterText(find.byType(TextField).last, text);
        await tester.pump();
        await tester.tap(find.text('Record payment'));
        await tester.pump();
        expect(s.settlements.created, isEmpty, reason: 'text "$text"');
      }
    });

    testWidgets('recording a payment posts it and reloads', (tester) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      final c = await open(tester, s, path: '/groups/1?view=balances');
      // Keep a list alive, as it would be after visiting Expenses.
      c.listen(groupExpensesProvider((1, const ExpenseFilters())), (_, _) {});
      await tester.pumpAndSettle();
      final loads = s.balances.calls;
      final expenseLoads = s.expenses.queries.length;
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      expect(find.text('You pay Neha'), findsOneWidget);
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      expect(s.settlements.created, hasLength(1));
      expect(s.settlements.created.single.payeeId, 5);
      expect(s.settlements.created.single.paise, 185000);
      expect(s.settlements.created.single.groupId, 1);
      expect(s.balances.calls, greaterThan(loads));
      expect(s.expenses.queries.length, greaterThan(expenseLoads));
      expect(find.text('Payment recorded'), findsOneWidget);
      expect(find.text('Record payment'), findsNothing);
    });

    testWidgets('recording a payment reloads the dashboard summary', (
      tester,
    ) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      final c = await open(tester, s, path: '/groups/1?view=balances');
      c.listen(monthlySummaryProvider(DateTime(2026, 10)), (_, _) {});
      await tester.pumpAndSettle();
      expect(s.summary.requested, ['2026-10']);
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      expect(s.summary.requested, ['2026-10', '2026-10']);
    });

    testWidgets('the reload still happens if the sheet is popped mid-post', (
      tester,
    ) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      s.settlements.gate = Completer<void>();
      final c = await open(tester, s, path: '/groups/1?view=balances');
      c.listen(groupExpensesProvider((1, const ExpenseFilters())), (_, _) {});
      await tester.pumpAndSettle();
      final loads = s.balances.calls;
      final expenseLoads = s.expenses.queries.length;
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record payment'));
      await tester.pump();
      // Force the sheet away, as if it were disposed.
      Navigator.of(tester.element(find.text('Record payment'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Record payment'), findsNothing);
      s.settlements.gate!.complete();
      await tester.pumpAndSettle();
      expect(s.balances.calls, greaterThan(loads));
      expect(s.expenses.queries.length, greaterThan(expenseLoads));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sheet cannot be dismissed while posting', (tester) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      s.settlements.gate = Completer<void>();
      await open(tester, s, path: '/groups/1?view=balances');
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record payment'));
      await tester.pump();
      await tester.tapAt(const Offset(300, 20));
      await tester.pumpAndSettle();
      expect(find.text('Record payment'), findsOneWidget);
      s.settlements.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Payment recorded'), findsOneWidget);
    });

    testWidgets('an amount that does not parse says why', (tester) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      await open(tester, s, path: '/groups/1?view=balances');
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Part of it'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '10.555');
      await tester.pump();
      expect(find.text('Use up to 2 decimals'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '0');
      await tester.pump();
      expect(find.text('Enter more than ₹0'), findsOneWidget);
    });

    testWidgets('a part payment posts the typed amount', (tester) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      await open(tester, s, path: '/groups/1?view=balances');
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Part of it'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '1,000.50');
      await tester.pump();
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      expect(s.settlements.created.single.paise, 100050);
    });

    testWidgets('Record cannot be submitted twice while posting', (
      tester,
    ) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      s.settlements.gate = Completer<void>();
      await open(tester, s, path: '/groups/1?view=balances');
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record payment'));
      await tester.pump();
      await tester.tap(find.text('Record payment'));
      await tester.pump();
      expect(s.settlements.created, hasLength(1));
      s.settlements.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Payment recorded'), findsOneWidget);
    });

    testWidgets('a failed post shows the error and stays open', (tester) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      s.settlements.error = Exception('boom');
      await open(tester, s, path: '/groups/1?view=balances');
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Record payment'), findsOneWidget);
    });

    testWidgets('the amount field stops at 12 digits before the point', (
      tester,
    ) async {
      final s = Setup(
        balances: [balanceRow(milisha, -185000), balanceRow(neha, 185000)],
      );
      await open(tester, s, path: '/groups/1?view=balances');
      await tester.tap(find.text('Settle up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Part of it'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '1234567890123');
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller!.text, isEmpty);
    });
  });

  group('Totals view', () {
    testWidgets('shows the server totals', (tester) async {
      final s = Setup();
      s.groups.totalsResult = const GroupTotals(
        totalSpentPaise: 4260000,
        mySharePaise: 852000,
        iPaidPaise: 1037000,
        categories: [
          CategorySpend(
            name: 'Stay',
            icon: 'hotel',
            color: '#5DCAA5',
            paise: 1800000,
          ),
        ],
        paidBy: [
          PayerTotal(
            userId: 3,
            firstName: 'Riya',
            lastName: 'Kapoor',
            paise: 1823000,
          ),
          PayerTotal(
            userId: 2,
            firstName: 'Milisha',
            lastName: 'Saran',
            paise: 1037000,
          ),
        ],
      );
      await open(tester, s, path: '/groups/1?view=totals');
      expect(find.text('Group spent'), findsOneWidget);
      expect(find.text('₹42,600'), findsOneWidget);
      expect(find.text('₹8,520'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(find.text('₹18,000'), findsOneWidget);
      expect(find.text('Riya'), findsOneWidget);
      expect(find.text('₹18,230'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });
  });
}
