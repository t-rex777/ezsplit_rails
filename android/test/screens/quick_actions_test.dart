import 'dart:convert';

import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/state/expense_form.dart';
import 'package:ezsplit_mobile/state/quick_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

const rent = QuickAction(
  id: 'a1',
  name: 'Rent',
  paise: 2500000,
  groupId: 1,
  groupName: 'Goa trip',
  categoryId: 2,
  categoryIcon: 'hotel',
  payerId: 2,
  splitType: SplitType.percentage,
  included: [2, 3, 4],
  percents: {2: 4000, 3: 3000, 4: 3000},
);

final prefsKey = quickActionsKey(milisha.id);

Map<String, Object> stored(List<QuickAction> actions) => {
  prefsKey: jsonEncode([for (final a in actions) a.toJson()]),
};

class Setup {
  Setup({List<User> members = const [milisha, riya, arjun]})
    : groups = FakeGroupsRepository(
        groups: [makeGroup(1, 'Goa trip', members: members, ownerId: 2)],
      );

  final FakeGroupsRepository groups;
  final expenses = FakeExpensesRepository();
}

Future<ProviderContainer> open(
  WidgetTester tester,
  Setup s, {
  String path = '/home',
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(
    tester,
    FakeAuthRepository(current: milisha),
    extraOverrides: detailOverrides(
      groups: s.groups,
      expenses: s.expenses,
      balances: FakeBalancesRepository(goaBalances()),
      categories: FakeCategoriesRepository(const [foodCategory, stayCategory]),
    ),
  );
  if (path != '/home') {
    routerOf(c).go(path);
    await tester.pumpAndSettle();
  }
  return c;
}

Finder field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(field(key)).controller!.text;

Future<List<QuickAction>> saved() async {
  final raw = (await SharedPreferences.getInstance()).getString(prefsKey);
  if (raw == null) return [];
  return [
    for (final j in jsonDecode(raw) as List)
      QuickAction.fromJson(j as Map<String, dynamic>),
  ];
}

ExpenseFormState useForm(ProviderContainer c, String id, {int? groupId = 1}) =>
    c.read(
      expenseFormProvider((
        groupId: groupId,
        expenseId: null,
        quickActionId: id,
        editsQuickAction: false,
      )),
    );

void main() {
  test('a quick action survives a JSON round trip', () {
    final back = QuickAction.fromJson(
      jsonDecode(jsonEncode(rent.toJson())) as Map<String, dynamic>,
    );
    expect(back.toJson(), rent.toJson());
    expect(back.percents, {2: 4000, 3: 3000, 4: 3000});
  });

  group('Dashboard', () {
    testWidgets('with none saved, shows the empty card that opens the form', (
      tester,
    ) async {
      final c = await open(tester, Setup());
      expect(find.text('Quick actions'), findsOneWidget);
      await tester.tap(find.text('Add a quick action'));
      await tester.pumpAndSettle();
      expect(find.text('New quick action'), findsOneWidget);
      // Close returns to the dashboard under it.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(locationOf(c), '/home');
      expect(find.text('Add a quick action'), findsOneWidget);
    });

    testWidgets('shows a tile per saved quick action', (tester) async {
      await open(tester, Setup(), prefs: stored([rent]));
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('₹25,000'), findsOneWidget);
      expect(find.text('Goa trip · By %'), findsOneWidget);
      expect(find.text('Hold one to edit'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('a broken stored list shows the empty card, not an error', (
      tester,
    ) async {
      await open(tester, Setup(), prefs: {prefsKey: 'not json'});
      expect(find.text('Add a quick action'), findsOneWidget);
    });

    testWidgets("another user's quick actions are not shown", (tester) async {
      await open(
        tester,
        Setup(),
        prefs: {
          quickActionsKey(99): jsonEncode([rent.toJson()]),
        },
      );
      expect(find.text('Rent'), findsNothing);
      expect(find.text('Add a quick action'), findsOneWidget);
    });
  });

  group('Using a quick action', () {
    testWidgets('a tap fills the form and Add saves the expense', (
      tester,
    ) async {
      final s = Setup();
      await open(tester, s, prefs: stored([rent]));
      await tester.tap(find.text('Rent'));
      await tester.pumpAndSettle();

      expect(find.text('From quick action'), findsOneWidget);
      expect(fieldText(tester, 'description'), 'Rent');
      expect(fieldText(tester, 'amount'), '25000');
      expect(find.text('Stay'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final e = s.expenses.created.single;
      expect(e.name, 'Rent');
      expect(e.paise, 2500000);
      expect(e.groupId, 1);
      expect(e.categoryId, 2);
      expect(e.payerId, 2);
      expect(e.splitType, SplitType.percentage);
      expect(
        {for (final d in e.distribution) d.key: d.value},
        {2: 4000, 3: 3000, 4: 3000},
      );
      expect(find.text('From quick action'), findsNothing);
      expect(find.text('Hold one to edit'), findsOneWidget);
    });

    testWidgets('fields can be changed before adding', (tester) async {
      final s = Setup();
      await open(tester, s, path: '/home/quick/a1', prefs: stored([rent]));
      await tester.enterText(field('amount'), '26000');
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(s.expenses.created.single.paise, 2600000);
      // The quick action itself is not changed by one use.
      expect((await saved()).single.paise, 2500000);
    });

    testWidgets('someone who left the group drops out of the split', (
      tester,
    ) async {
      final s = Setup(members: const [milisha, riya]);
      final c = await open(
        tester,
        s,
        path: '/home/quick/a1',
        prefs: stored([rent]),
      );
      final f = useForm(c, 'a1');
      expect(f.included, [2, 3]);
      // 30% is unassigned, so the user has to finish the split first.
      expect(f.percentRemaining, 3000);
      expect(f.canSave, isFalse);
      expect(find.text('Finish the split to save'), findsOneWidget);
    });

    testWidgets('a payer who left the group falls back to you', (tester) async {
      const paidByArjun = QuickAction(
        id: 'a2',
        name: 'Cook',
        paise: 450000,
        groupId: 1,
        groupName: 'Goa trip',
        categoryId: 1,
        categoryIcon: 'restaurant',
        payerId: 4,
        splitType: SplitType.equal,
        included: [2, 3, 4],
      );
      final c = await open(
        tester,
        Setup(members: const [milisha, riya]),
        path: '/home/quick/a2',
        prefs: stored([paidByArjun]),
      );
      final f = useForm(c, 'a2');
      expect(f.payerId, milisha.id);
      expect(f.included, [2, 3]);
      expect(f.canSave, isTrue);
    });

    testWidgets('when everyone in the split left, it splits equally', (
      tester,
    ) async {
      const gone = QuickAction(
        id: 'a3',
        name: 'Old',
        paise: 10000,
        groupId: 1,
        groupName: 'Goa trip',
        categoryId: 1,
        categoryIcon: 'restaurant',
        payerId: 2,
        splitType: SplitType.exact,
        included: [8, 9],
        exact: {8: 5000, 9: 5000},
      );
      final c = await open(
        tester,
        Setup(),
        path: '/home/quick/a3',
        prefs: stored([gone]),
      );
      final f = useForm(c, 'a3');
      expect(f.mode, SplitMode.equal);
      expect(f.included, [2, 3, 4]);
      expect(f.canSave, isTrue);
    });

    testWidgets('a missing category falls back to an existing one', (
      tester,
    ) async {
      const oldCategory = QuickAction(
        id: 'a4',
        name: 'Gym',
        paise: 150000,
        groupId: null,
        groupName: 'Personal',
        categoryId: 77,
        categoryIcon: 'bolt',
        payerId: 2,
        splitType: SplitType.equal,
        included: [2],
      );
      final c = await open(
        tester,
        Setup(),
        path: '/home/quick/a4',
        prefs: stored([oldCategory]),
      );
      expect(useForm(c, 'a4', groupId: null).categoryId, foodCategory.id);
    });

    testWidgets('a deleted quick action says so', (tester) async {
      await open(tester, Setup(), path: '/home/quick/nope');
      expect(find.text('This quick action was deleted.'), findsOneWidget);
    });

    testWidgets('a failed save keeps the form open with the error', (
      tester,
    ) async {
      final s = Setup()..expenses.saveError = Exception('offline');
      final c = await open(
        tester,
        s,
        path: '/home/quick/a1',
        prefs: stored([rent]),
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('From quick action'), findsOneWidget);
      expect(useForm(c, 'a1').error, isNotNull);
    });
  });

  group('Creating and editing', () {
    testWidgets('a new group quick action is saved and shown as a tile', (
      tester,
    ) async {
      final c = await open(tester, Setup(), path: '/home/quick/new');
      // A quick action has no date, note or photo.
      expect(find.text('Today'), findsNothing);
      expect(find.text('Add a note'), findsNothing);
      expect(find.text('Add photo'), findsNothing);
      expect(find.text('Personal'), findsOneWidget);

      await tester.tap(find.text('Group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Goa trip').last);
      await tester.pumpAndSettle();
      expect(find.text('3 members'), findsOneWidget);

      await tester.enterText(field('description'), 'Rent');
      await tester.enterText(field('amount'), '25000');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(locationOf(c), '/home');
      final a = (await saved()).single;
      expect(a.name, 'Rent');
      expect(a.paise, 2500000);
      expect(a.groupId, 1);
      expect(a.groupName, 'Goa trip');
      expect(a.splitType, SplitType.equal);
      expect(a.included, [2, 3, 4]);
      expect(a.categoryIcon, 'restaurant');
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Goa trip · Equally'), findsOneWidget);
    });

    testWidgets('Save stays off until the form is complete', (tester) async {
      await open(tester, Setup(), path: '/home/quick/new');
      await tester.enterText(field('description'), 'Rent');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('New quick action'), findsOneWidget);
      expect(await saved(), isEmpty);
    });

    testWidgets('a personal quick action adds a personal expense', (
      tester,
    ) async {
      final s = Setup();
      await open(tester, s, path: '/home/quick/new');
      await tester.enterText(field('description'), 'Gym');
      await tester.enterText(field('amount'), '1500');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final a = (await saved()).single;
      expect(a.groupId, isNull);
      expect(find.text('Personal'), findsWidgets);

      await tester.tap(find.text('Gym'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      final e = s.expenses.created.single;
      expect(e.groupId, isNull);
      expect(e.paise, 150000);
      expect(e.payerId, milisha.id);
    });

    testWidgets('hold, Edit, change the amount: same quick action updated', (
      tester,
    ) async {
      await open(tester, Setup(), prefs: stored([rent]));
      await tester.longPress(find.text('Rent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit quick action'));
      await tester.pumpAndSettle();
      expect(find.text('Edit quick action'), findsOneWidget);
      expect(fieldText(tester, 'amount'), '25000');

      await tester.enterText(field('amount'), '26000');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final a = (await saved()).single;
      expect(a.id, 'a1');
      expect(a.paise, 2600000);
      expect(a.splitType, SplitType.percentage);
      expect(a.percents, {2: 4000, 3: 3000, 4: 3000});
      expect(find.text('₹26,000'), findsOneWidget);
    });

    testWidgets('moving to another group starts the split over', (
      tester,
    ) async {
      final c = await open(
        tester,
        Setup(),
        path: '/home/quick/a1/edit',
        prefs: stored([rent]),
      );
      await tester.tap(find.text('Group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal').last);
      await tester.pumpAndSettle();
      final f = c.read(
        expenseFormProvider((
          groupId: 1,
          expenseId: null,
          quickActionId: 'a1',
          editsQuickAction: true,
        )),
      );
      expect(f.groupId, isNull);
      expect(f.mode, SplitMode.equal);
      expect(f.included, [milisha.id]);
      expect(f.name, 'Rent');
    });

    testWidgets('hold, Delete, confirm: the tile is gone', (tester) async {
      await open(tester, Setup(), prefs: stored([rent]));
      await tester.longPress(find.text('Rent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete quick action'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Rent?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await saved(), isEmpty);
      expect(find.text('Add a quick action'), findsOneWidget);
    });

    testWidgets('hold, Delete, cancel: the tile stays', (tester) async {
      await open(tester, Setup(), prefs: stored([rent]));
      await tester.longPress(find.text('Rent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete quick action'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await saved()).single.id, 'a1');
      expect(find.text('Rent'), findsOneWidget);
    });

    testWidgets('Close on a new quick action goes back without saving', (
      tester,
    ) async {
      final c = await open(tester, Setup(), path: '/home/quick/new');
      await tester.enterText(field('description'), 'Rent');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(locationOf(c), '/home');
      expect(await saved(), isEmpty);
    });
  });
}
