import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/state/summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

Expense personal(int id, String name, {int paise = 54000, String? notes}) =>
    makeExpense(
      id,
      name,
      paise: paise,
      payer: milisha,
      mine: 0,
      shares: [Share(userId: milisha.id, paise: paise)],
      creatorId: milisha.id,
      notes: notes,
      groupId: null,
    );

MonthlySummary octoberWithPersonal() => const MonthlySummary(
  month: '2026-10',
  mySharePaise: 124000,
  youOwePaise: 0,
  owedToYouPaise: 0,
  categories: [],
  otherCurrencies: [],
  personalPaise: 124000,
  personalCount: 6,
);

class Setup {
  final groups = FakeGroupsRepository(
    groups: [
      makeGroup(1, 'Goa trip', members: const [milisha, riya], ownerId: 2),
    ],
  );
  final expenses = FakeExpensesRepository();
  final summary = FakeSummaryRepository(
    byMonth: {'2026-10': octoberWithPersonal()},
  );
  final categories = FakeCategoriesRepository(const [foodCategory]);
}

Future<ProviderContainer> open(
  WidgetTester tester,
  Setup s,
  String path,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(
    tester,
    FakeAuthRepository(current: milisha),
    extraOverrides: [
      ...detailOverrides(
        groups: s.groups,
        expenses: s.expenses,
        balances: FakeBalancesRepository(const []),
        categories: s.categories,
        summary: s.summary,
      ),
      nowProvider.overrideWithValue(DateTime(2026, 10, 30)),
    ],
  );
  routerOf(c).go(path);
  await tester.pumpAndSettle();
  return c;
}

/// The top route, including one opened with push.
String pushedLocation(ProviderContainer c) =>
    routerOf(c).routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  group('Models', () {
    test('summary reads personal totals and defaults them to zero', () {
      final base = {
        'month': '2026-10',
        'my_share': '0.0',
        'you_owe': '0.0',
        'owed_to_you': '0.0',
        'categories': <dynamic>[],
        'other_currencies': <dynamic>[],
      };
      final withPersonal = MonthlySummary.fromJson({
        ...base,
        'personal_total': '720.5',
        'personal_count': 2,
      });
      expect(withPersonal.personalPaise, 72050);
      expect(withPersonal.personalCount, 2);
      final without = MonthlySummary.fromJson(base);
      expect(without.personalPaise, 0);
      expect(without.personalCount, 0);
    });

    test('isPersonalFor needs no group, me as payer, and only my share', () {
      expect(personal(1, 'Coffee').isPersonalFor(milisha.id), isTrue);
      expect(personal(1, 'Coffee').isPersonalFor(riya.id), isFalse);
      final shared = makeExpense(
        2,
        'Cab',
        payer: milisha,
        shares: [
          Share(userId: milisha.id, paise: 1),
          Share(userId: riya.id, paise: 1),
        ],
        groupId: null,
      );
      expect(shared.isPersonalFor(milisha.id), isFalse);
      final inGroup = makeExpense(
        3,
        'Dinner',
        payer: milisha,
        shares: [Share(userId: milisha.id, paise: 1)],
      );
      expect(inGroup.isPersonalFor(milisha.id), isFalse);
    });

    test('a personal query asks the server for personal=true', () {
      expect(const ExpenseQuery(personal: true).toQuery(), {
        'personal': 'true',
      });
    });
  });

  testWidgets('Home shows the personal card and See all opens the list', (
    tester,
  ) async {
    final s = Setup()..expenses.expenses = [personal(7, 'Groceries')];
    final c = await open(tester, s, '/home');

    expect(find.text('₹1,240 spent alone'), findsOneWidget);
    expect(find.text('6 expenses in October · no group'), findsOneWidget);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(locationOf(c), '/home/personal');
    expect(find.text('Groceries'), findsOneWidget);
    expect(s.expenses.queries.last.personal, isTrue);
    expect(s.expenses.queries.last.groupId, isNull);
  });

  testWidgets('the list shows an empty state with a way to add', (
    tester,
  ) async {
    final c = await open(tester, Setup(), '/home/personal');
    expect(find.text('No personal expenses yet'), findsOneWidget);
    await tester.tap(find.text('Add personal expense'));
    await tester.pumpAndSettle();
    expect(pushedLocation(c), '/home/personal/new');
  });

  testWidgets('the form has no payer or split and saves without a group', (
    tester,
  ) async {
    final s = Setup();
    final c = await open(tester, s, '/home/personal');
    await tester.tap(find.bySemanticsLabel('Add personal expense').first);
    await tester.pumpAndSettle();

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Paid by'), findsNothing);
    expect(find.text('Equally'), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('description')),
        matching: find.byType(TextField),
      ),
      'Groceries',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('amount')),
        matching: find.byType(TextField),
      ),
      '540',
    );
    await tester.pump();
    expect(find.text('You paid ₹540 for yourself'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final sent = s.expenses.created.single;
    expect(sent.groupId, isNull);
    expect(sent.payerId, milisha.id);
    expect(sent.paise, 54000);
    expect(sent.toJson()['expense']['distribution'], [
      {'user_id': milisha.id, 'amount': '540.00'},
    ]);
    expect(locationOf(c), '/home/personal');
  });

  testWidgets('a personal expense can be edited from its detail screen', (
    tester,
  ) async {
    final s = Setup()..expenses.expenses = [personal(7, 'Groceries')];
    final c = await open(tester, s, '/expenses/7');

    expect(find.textContaining('Personal'), findsOneWidget);
    expect(find.text('Only you. Nobody owes anything.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Edit expense'));
    await tester.pumpAndSettle();
    expect(pushedLocation(c), '/expenses/7/edit');
    expect(find.text('Paid by'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final sent = s.expenses.updated.single;
    expect(sent.id, 7);
    expect(sent.expense.groupId, isNull);
  });

  testWidgets('deleting a personal expense returns to the personal list', (
    tester,
  ) async {
    final s = Setup()..expenses.expenses = [personal(7, 'Groceries')];
    final c = await open(tester, s, '/expenses/7');

    await tester.tap(find.bySemanticsLabel('Delete expense'));
    await tester.pumpAndSettle();
    expect(
      find.text("It's removed from your personal spending."),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(s.expenses.deleted, [7]);
    expect(locationOf(c), '/home/personal');
  });
}
