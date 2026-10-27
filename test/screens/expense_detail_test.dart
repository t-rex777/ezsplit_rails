import 'dart:async';

import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

const _shares = [
  Share(userId: 2, paise: 60000),
  Share(userId: 3, paise: 60000),
  Share(userId: 4, paise: 60000),
  Share(userId: 5, paise: 60000),
  Share(userId: 6, paise: 60000),
];

const sam6 = User(
  id: 6,
  firstName: 'Sam',
  lastName: 'Rao',
  email: 'sam6@example.com',
);

Expense dinner({int creatorId = 3, User payer = riya, String? notes}) =>
    makeExpense(
      1,
      'Dinner',
      paise: 300000,
      payer: payer,
      mine: -60000,
      creatorId: creatorId,
      shares: _shares,
      notes: notes,
    );

class Setup {
  Setup(Expense e) {
    expenses.details[e.id] = e;
  }

  final groups = FakeGroupsRepository(
    groups: [
      makeGroup(
        1,
        'Goa trip',
        members: const [milisha, riya, arjun, neha, sam6],
        ownerId: 2,
      ),
    ],
  );
  final expenses = FakeExpensesRepository();
  final balances = FakeBalancesRepository(goaBalances());
}

Future<ProviderContainer> open(WidgetTester tester, Setup s) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(
    tester,
    FakeAuthRepository(current: milisha),
    extraOverrides: detailOverrides(
      groups: s.groups,
      expenses: s.expenses,
      balances: s.balances,
    ),
  );
  routerOf(c).go('/expenses/1');
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('shows the expense, who paid and each share in words', (
    tester,
  ) async {
    await open(tester, Setup(dinner(notes: 'Includes the 10% service charge')));
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('₹3,000'), findsOneWidget);
    expect(find.text('Goa trip · Food · 24 Oct 2026'), findsOneWidget);
    expect(find.text('Added by Riya'), findsOneWidget);
    expect(find.text('Riya paid ₹3,000'), findsOneWidget);
    expect(find.text('split equally, 5 people'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('owe ₹600'), findsOneWidget);
    expect(find.text('owes ₹600'), findsNWidgets(3));
    expect(find.text('Includes the 10% service charge'), findsOneWidget);
  });

  testWidgets('has no paid or unpaid tags and no mark-paid action', (
    tester,
  ) async {
    await open(tester, Setup(dinner()));
    expect(find.text('paid'), findsNothing);
    expect(find.text('unpaid'), findsNothing);
    expect(find.textContaining('Mark my share'), findsNothing);
  });

  testWidgets('hides Edit and Delete when I am not the creator', (
    tester,
  ) async {
    await open(tester, Setup(dinner(creatorId: 3)));
    expect(find.bySemanticsLabel('Edit expense'), findsNothing);
    expect(find.bySemanticsLabel('Delete expense'), findsNothing);
  });

  testWidgets('shows Edit and Delete to the creator', (tester) async {
    await open(tester, Setup(dinner(creatorId: 2, payer: milisha)));
    expect(find.bySemanticsLabel('Edit expense'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete expense'), findsOneWidget);
    expect(find.text('You paid ₹3,000'), findsOneWidget);
    expect(find.text('Added by You'), findsOneWidget);
  });

  testWidgets('Edit opens the filled-in form', (tester) async {
    final c = await open(tester, Setup(dinner(creatorId: 2)));
    await tester.tap(find.bySemanticsLabel('Edit expense'));
    await tester.pumpAndSettle();
    expect(find.text('Edit expense'), findsOneWidget);
    expect(
      routerOf(c).routerDelegate.currentConfiguration.last.matchedLocation,
      '/expenses/1/edit',
    );
  });

  testWidgets('See group balances opens the Balances view', (tester) async {
    final c = await open(tester, Setup(dinner()));
    await tester.tap(find.text('See group balances'));
    await tester.pumpAndSettle();
    expect(locationOf(c), '/groups/1?view=balances');
    expect(find.text('Simplest way to settle'), findsOneWidget);
  });

  testWidgets('Delete asks first, then deletes and returns to the group', (
    tester,
  ) async {
    final s = Setup(dinner(creatorId: 2));
    final c = await open(tester, s);
    await tester.tap(find.bySemanticsLabel('Delete expense'));
    await tester.pumpAndSettle();
    expect(s.expenses.deleted, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(s.expenses.deleted, isEmpty);
    await tester.tap(find.bySemanticsLabel('Delete expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(s.expenses.deleted, [1]);
    expect(locationOf(c), '/groups/1');
  });

  testWidgets('a failed delete shows the message and stays', (tester) async {
    final s = Setup(dinner(creatorId: 2));
    s.expenses.deleteError = const ApiError(
      status: 404,
      message: 'Expense not found',
    );
    final c = await open(tester, s);
    await tester.tap(find.bySemanticsLabel('Delete expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Expense not found'), findsOneWidget);
    expect(locationOf(c), '/expenses/1');
  });

  testWidgets('a second delete tap while posting does nothing', (tester) async {
    final s = Setup(dinner(creatorId: 2));
    s.expenses.saveGate = Completer<void>();
    await open(tester, s);
    await tester.tap(find.bySemanticsLabel('Delete expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Delete expense'));
    await tester.pump();
    expect(s.expenses.deleted, [1]);
    s.expenses.saveGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('an expense I cannot see shows the server message', (
    tester,
  ) async {
    final s = Setup(dinner());
    s.expenses.details.clear();
    await open(tester, s);
    expect(find.text('Expense not found'), findsOneWidget);
  });

  testWidgets('the tab bar is hidden on the detail and the edit form', (
    tester,
  ) async {
    final c = await open(tester, Setup(dinner(creatorId: 2)));
    expect(find.text('Profile'), findsNothing);
    routerOf(c).go('/expenses/1/edit');
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNothing);
    expect(find.text('Edit expense'), findsOneWidget);
  });

  testWidgets('after a delete, Back on the group goes to the groups list', (
    tester,
  ) async {
    final c = await open(tester, Setup(dinner(creatorId: 2)));
    await tester.tap(find.bySemanticsLabel('Delete expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(locationOf(c), '/groups/1');
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(locationOf(c), '/groups');
  });
}
