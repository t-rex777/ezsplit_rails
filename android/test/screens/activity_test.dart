import 'package:ezsplit_mobile/data/activities_repository.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/state/expense_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

const _oldShares = [
  SnapshotShare(userId: 2, name: 'Milisha Saran', paise: 80000),
  SnapshotShare(userId: 3, name: 'Riya Kapoor', paise: 80000),
  SnapshotShare(userId: 4, name: 'Arjun Mehta', paise: 80000),
];
const _newShares = [
  SnapshotShare(userId: 2, name: 'Milisha Saran', paise: 75000),
  SnapshotShare(userId: 3, name: 'Riya Kapoor', paise: 150000),
  SnapshotShare(userId: 4, name: 'Arjun Mehta', paise: 75000),
];

final _edit = makeActivity(
  3,
  ActivityAction.updated,
  actor: riya,
  expenseId: 10,
  before: makeSnapshot(
    'Beach dinner',
    paise: 240000,
    payer: milisha,
    shares: _oldShares,
  ),
  after: makeSnapshot('Beach dinner', paise: 300000, shares: _newShares),
  changedFields: const ['amount', 'payer', 'shares'],
);

final _delete = makeActivity(
  2,
  ActivityAction.deleted,
  actor: arjun,
  expenseId: 11,
  before: makeSnapshot(
    'Cab to airport',
    paise: 100000,
    payer: arjun,
    shares: const [
      SnapshotShare(userId: 2, name: 'Milisha Saran', paise: 50000),
      SnapshotShare(userId: 4, name: 'Arjun Mehta', paise: 50000),
    ],
  ),
);

final _mine = makeActivity(
  1,
  ActivityAction.created,
  actor: milisha,
  expenseId: 12,
  at: DateTime.now().subtract(const Duration(days: 1)),
  after: makeSnapshot('Coffee', paise: 10000, payer: milisha),
);

final _friend = makeActivity(
  4,
  ActivityAction.created,
  actor: arjun,
  groupId: null,
  expenseId: 13,
  after: makeSnapshot('Movie tickets', paise: 60000, groupName: null),
);

final _paid = makePayment(
  5,
  payer: riya,
  payee: milisha,
  paise: 50000,
  notes: 'UPI',
);

Future<(ProviderContainer, FakeActivitiesRepository)> open(
  WidgetTester tester, {
  List<ActivityEntry>? entries,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final activities = FakeActivitiesRepository(
    entries: entries ?? [_paid, _edit, _delete, _friend, _mine],
  );
  final c = await pumpApp(
    tester,
    FakeAuthRepository(current: milisha),
    extraOverrides: detailOverrides(
      groups: FakeGroupsRepository(
        groups: [makeGroup(1, 'Goa trip'), makeGroup(2, 'Flat 302')],
      ),
      expenses: FakeExpensesRepository()
        ..details[10] = makeExpense(10, 'Beach dinner', paise: 300000),
      balances: FakeBalancesRepository(goaBalances()),
      activities: activities,
    ),
  );
  routerOf(c).go('/activity');
  await tester.pumpAndSettle();
  return (c, activities);
}

Finder rich(String text) => find.text(text, findRichText: true);

void main() {
  testWidgets('lists who did what, where and when, under day headers', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Activity'), findsWidgets);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(rich('Riya edited Beach dinner'), findsOneWidget);
    expect(rich('Arjun deleted Cab to airport'), findsOneWidget);
    expect(rich('You added Coffee'), findsOneWidget);
    expect(find.text('Goa trip'), findsWidgets);
    expect(find.text('No group'), findsOneWidget);
    expect(find.text('₹2,400'), findsOneWidget);
    expect(find.text('₹3,000'), findsOneWidget);
  });

  testWidgets('an edit opens what changed, before and after', (tester) async {
    await open(tester);
    await tester.tap(rich('Riya edited Beach dinner'));
    await tester.pumpAndSettle();
    expect(find.text('What changed'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Paid by'), findsOneWidget);
    expect(find.text('Split'), findsOneWidget);
    expect(find.text('₹2,400'), findsNWidgets(2));
    expect(find.text('₹3,000'), findsNWidgets(2));
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Riya'), findsWidgets);
    expect(find.text('Full expense before the edit'), findsOneWidget);
    expect(
      find.text('Unchanged: name, date, category, notes.'),
      findsOneWidget,
    );
    expect(find.text('Open expense'), findsOneWidget);
  });

  testWidgets('a delete shows the expense that was removed', (tester) async {
    await open(tester);
    await tester.tap(rich('Arjun deleted Cab to airport'));
    await tester.pumpAndSettle();
    expect(find.text('The expense that was removed'), findsOneWidget);
    expect(find.text('Paid by Arjun'), findsOneWidget);
    expect(find.text('You · ₹500'), findsOneWidget);
    expect(find.text('Arjun · ₹500'), findsOneWidget);
    expect(
      find.text('This expense no longer counts toward balances.'),
      findsOneWidget,
    );
    expect(find.text('Open expense'), findsNothing);
  });

  testWidgets('a settle-up reads as who paid whom', (tester) async {
    await open(tester);
    expect(rich('Riya paid You'), findsOneWidget);
    expect(find.text('₹500'), findsOneWidget);

    await tester.tap(rich('Riya paid You'));
    await tester.pumpAndSettle();
    expect(find.text('The payment'), findsOneWidget);
    expect(find.text('From Riya to You'), findsOneWidget);
    expect(find.text('₹500'), findsNWidgets(2));
    expect(find.text('Paid on 29 Oct 2026'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(
      find.text('This records a payment. No money moves in the app.'),
      findsOneWidget,
    );
    expect(find.text('Open expense'), findsNothing);
  });

  testWidgets('Open expense goes to the expense', (tester) async {
    final (c, _) = await open(tester);
    await tester.tap(rich('Riya edited Beach dinner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open expense'));
    await tester.pumpAndSettle();
    expect(
      routerOf(c).routerDelegate.currentConfiguration.last.matchedLocation,
      '/expenses/10',
    );
  });

  testWidgets('filter chips ask for one group or friend expenses', (
    tester,
  ) async {
    final (_, repo) = await open(tester);
    expect(repo.calls.last, const AllActivity());

    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, const FriendActivity());
    expect(rich('Arjun added Movie tickets'), findsOneWidget);
    expect(rich('Riya edited Beach dinner'), findsNothing);

    await tester.tap(find.text('Flat 302'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, const GroupActivity(2));
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(
      find.text(
        'When anyone in Flat 302 adds, edits, or deletes an expense, it shows up here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the empty state with no activity', (tester) async {
    await open(tester, entries: const []);
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(
      find.text(
        'When anyone in your groups adds, edits, or deletes an expense, it shows up here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reloads after an expense changes', (tester) async {
    final (c, repo) = await open(tester);
    final before = repo.calls.length;
    invalidateAfterExpenseChange(c.invalidate, 1);
    await tester.pumpAndSettle();
    expect(repo.calls.length, before + 1);
  });
}
