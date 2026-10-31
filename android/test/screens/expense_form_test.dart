import 'dart:async';

import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/domain/money.dart';
import 'package:ezsplit_mobile/domain/split.dart';
import 'package:ezsplit_mobile/state/expense_form.dart';
import 'package:ezsplit_mobile/state/summary.dart';
import 'package:ezsplit_mobile/widgets/brutal_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

const sam6 = User(
  id: 6,
  firstName: 'Sam',
  lastName: 'Rao',
  email: 'sam6@example.com',
);

class Setup {
  Setup({List<User>? members, List<Category>? categories})
    : groups = FakeGroupsRepository(
        groups: [
          makeGroup(
            1,
            'Goa trip',
            members: members ?? const [milisha, riya, arjun, neha, sam6],
            ownerId: 2,
          ),
        ],
      ),
      categories = FakeCategoriesRepository(
        categories ?? const [foodCategory, stayCategory],
      );

  final FakeGroupsRepository groups;
  final FakeCategoriesRepository categories;
  final expenses = FakeExpensesRepository();
  final balances = FakeBalancesRepository(goaBalances());
  final summary = FakeSummaryRepository();
}

Future<ProviderContainer> open(
  WidgetTester tester,
  Setup s, {
  String path = '/groups/1/expenses/new',
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(
    tester,
    FakeAuthRepository(current: milisha),
    extraOverrides: detailOverrides(
      groups: s.groups,
      expenses: s.expenses,
      balances: s.balances,
      categories: s.categories,
      summary: s.summary,
    ),
  );
  routerOf(c).go(path);
  await tester.pumpAndSettle();
  return c;
}

Finder field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(field(key), text);
  await tester.pump();
}

Future<void> fillBasics(WidgetTester tester, {String amount = '3000'}) async {
  await type(tester, 'description', 'Dinner');
  await type(tester, 'amount', amount);
}

ExpenseFormState formState(ProviderContainer c, [int? expenseId]) =>
    c.read(expenseFormProvider(expenseFormKey(1, expenseId: expenseId)));

bool enabled(WidgetTester tester, String label) =>
    tester
        .widget<BrutalButton>(find.widgetWithText(BrutalButton, label))
        .onPressed !=
    null;

Finder saveButton() => find.bySemanticsLabel('Save');

Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  group('Amount and description', () {
    testWidgets('1500.555 asks for up to 2 decimals and blocks Save', (
      tester,
    ) async {
      final c = await open(tester, Setup());
      await fillBasics(tester, amount: '1500.555');
      expect(find.text('Use up to 2 decimals'), findsOneWidget);
      expect(formState(c).canSave, isFalse);
      expect(formState(c).amountError, 'Use up to 2 decimals');
    });

    testWidgets('0 asks for an amount above zero', (tester) async {
      final c = await open(tester, Setup());
      await fillBasics(tester, amount: '0');
      expect(find.text('Enter an amount above ₹0'), findsOneWidget);
      expect(formState(c).canSave, isFalse);
    });

    testWidgets('an empty amount shows no error but cannot save', (
      tester,
    ) async {
      final c = await open(tester, Setup());
      await type(tester, 'description', 'Dinner');
      expect(formState(c).amountError, isNull);
      expect(formState(c).canSave, isFalse);
    });

    testWidgets('commas are fine and the amount stops at 12 digits', (
      tester,
    ) async {
      final c = await open(tester, Setup());
      await fillBasics(tester, amount: '1,500');
      expect(formState(c).paise, 150000);
      expect(formState(c).canSave, isTrue);
      await type(tester, 'amount', '1234567890123');
      expect(formState(c).amountText, '1,500');
    });

    testWidgets('an empty description blocks Save', (tester) async {
      final c = await open(tester, Setup());
      await type(tester, 'amount', '3000');
      expect(formState(c).canSave, isFalse);
      await type(tester, 'description', '   ');
      expect(formState(c).canSave, isFalse);
      await type(tester, 'description', 'Dinner');
      expect(formState(c).canSave, isTrue);
    });
  });

  group('Defaults', () {
    testWidgets('the group is filled in, everyone is in, I paid, today', (
      tester,
    ) async {
      final c = await open(tester, Setup());
      expect(find.text('Goa trip'), findsOneWidget);
      expect(find.text('all 5 members'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      final s = formState(c);
      expect(s.included, [2, 3, 4, 5, 6]);
      expect(s.payerId, 2);
      expect(s.mode, SplitMode.equal);
      expect(s.categoryId, 1);
    });

    testWidgets('the last used category is the default', (tester) async {
      final c = await open(tester, Setup(), prefs: {'last_category_id': 2});
      expect(formState(c).categoryId, 2);
      expect(find.text('Stay'), findsOneWidget);
    });

    testWidgets('an unknown saved category falls back to the first', (
      tester,
    ) async {
      final c = await open(tester, Setup(), prefs: {'last_category_id': 77});
      expect(formState(c).categoryId, 1);
    });
  });

  group('Equal split', () {
    testWidgets('shows the share and who owes me', (tester) async {
      await open(tester, Setup());
      await fillBasics(tester);
      expect(find.text('₹600 each'), findsOneWidget);
      expect(find.text('4 people owe you ₹2,400'), findsOneWidget);
      expect(find.text('Riya, Arjun, Neha, Sam'), findsOneWidget);
    });

    testWidgets('a paisa difference shows the larger share', (tester) async {
      await open(tester, Setup(members: const [milisha, riya, arjun]));
      await fillBasics(tester, amount: '1000');
      expect(find.text('₹333.34 each'), findsOneWidget);
      expect(find.text('2 people owe you ₹666.66'), findsOneWidget);
    });

    testWidgets('when someone else paid it says what I owe them', (
      tester,
    ) async {
      final c = await open(tester, Setup());
      await fillBasics(tester);
      await tester.tap(find.text('Paid by'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riya').last);
      await tester.pumpAndSettle();
      expect(formState(c).payerId, 3);
      expect(find.text('You owe Riya ₹600'), findsOneWidget);
    });

    testWidgets('leaving someone out changes the share', (tester) async {
      final c = await open(tester, Setup());
      await fillBasics(tester);
      await tester.tap(find.text('₹600 each'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sam'));
      await tester.pumpAndSettle();
      expect(formState(c).included, [2, 3, 4, 5]);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('₹750 each'), findsOneWidget);
    });
  });

  group('Split by percent', () {
    Future<void> toPercent(WidgetTester tester) async {
      await tester.tap(find.text('By %'));
      await tester.pumpAndSettle();
    }

    testWidgets('40/30/20/5 is 5% left and cannot be finished', (tester) async {
      final c = await open(
        tester,
        Setup(members: const [milisha, riya, arjun, neha]),
      );
      await fillBasics(tester);
      await toPercent(tester);
      expect(find.text('Split ₹3,000'), findsOneWidget);
      await type(tester, 'percent-2', '40');
      await type(tester, 'percent-3', '30');
      await type(tester, 'percent-4', '20');
      await type(tester, 'percent-5', '5');
      expect(find.text('5% left'), findsOneWidget);
      expect(enabled(tester, 'Done'), isFalse);
      expect(formState(c).canSave, isFalse);
      await type(tester, 'percent-5', '10');
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('₹300'), findsWidgets);
      expect(enabled(tester, 'Done'), isTrue);
      expect(formState(c).canSave, isTrue);
    });

    testWidgets('over 100 says how much over', (tester) async {
      await open(tester, Setup(members: const [milisha, riya]));
      await fillBasics(tester);
      await toPercent(tester);
      await type(tester, 'percent-2', '60');
      await type(tester, 'percent-3', '50');
      expect(find.text('10% over'), findsOneWidget);
    });

    testWidgets('33.33 / 33.33 / 33.34 is a valid split', (tester) async {
      final c = await open(
        tester,
        Setup(members: const [milisha, riya, arjun]),
      );
      await fillBasics(tester, amount: '100');
      await toPercent(tester);
      await type(tester, 'percent-2', '33.33');
      await type(tester, 'percent-3', '33.33');
      await type(tester, 'percent-4', '33.34');
      expect(formState(c).percents, {2: 3333, 3: 3333, 4: 3334});
      expect(formState(c).canSave, isTrue);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('saving sends a percentage split with the percents', (
      tester,
    ) async {
      final s = Setup(members: const [milisha, riya, arjun]);
      await open(tester, s);
      await fillBasics(tester, amount: '100');
      await toPercent(tester);
      await type(tester, 'percent-2', '33.33');
      await type(tester, 'percent-3', '33.33');
      await type(tester, 'percent-4', '33.34');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tapSave(tester);
      final body = s.expenses.created.single.toJson()['expense'] as Map;
      expect(body['split_type'], 'percentage');
      expect(body['amount'], '100.00');
      expect(body['group_id'], 1);
      expect(body['payer_id'], 2);
      expect(body['distribution'], [
        {'user_id': 2, 'amount': '33.33'},
        {'user_id': 3, 'amount': '33.33'},
        {'user_id': 4, 'amount': '33.34'},
      ]);
    });

    testWidgets('the server 422 about percentages is shown as is', (
      tester,
    ) async {
      final s = Setup(members: const [milisha, riya]);
      s.expenses.saveError = const ApiError(
        status: 422,
        message: 'Total percentage must equal 100',
      );
      await open(tester, s);
      await fillBasics(tester);
      await toPercent(tester);
      await type(tester, 'percent-2', '50');
      await type(tester, 'percent-3', '50');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tapSave(tester);
      expect(find.text('Total percentage must equal 100'), findsOneWidget);
      expect(find.text('Add expense'), findsOneWidget);
    });
  });

  group('Split by exact amount', () {
    Future<void> toExact(WidgetTester tester) async {
      await tester.tap(find.text('Exact'));
      await tester.pumpAndSettle();
    }

    testWidgets('1,000 + 1,200 + 500 of 3,000 leaves 300 to assign', (
      tester,
    ) async {
      final c = await open(
        tester,
        Setup(members: const [milisha, riya, arjun, neha]),
      );
      await fillBasics(tester);
      await toExact(tester);
      expect(find.text('₹3,000 left to assign'), findsOneWidget);
      await type(tester, 'exact-2', '1000');
      await type(tester, 'exact-3', '1200');
      await type(tester, 'exact-4', '500');
      expect(find.text('₹300 left to assign'), findsOneWidget);
      expect(find.text('₹2,700 of ₹3,000'), findsOneWidget);
      expect(find.text('Assign ₹300 more'), findsOneWidget);
      expect(enabled(tester, 'Assign ₹300 more'), isFalse);
      expect(formState(c).canSave, isFalse);
    });

    testWidgets('going over says how much over', (tester) async {
      await open(tester, Setup(members: const [milisha, riya]));
      await fillBasics(tester);
      await toExact(tester);
      await type(tester, 'exact-2', '2000');
      await type(tester, 'exact-3', '1200');
      expect(find.text('₹200 over'), findsOneWidget);
      expect(find.text('Remove ₹200'), findsOneWidget);
    });

    testWidgets('tapping Neha leaves her out', (tester) async {
      final c = await open(
        tester,
        Setup(members: const [milisha, riya, arjun, neha]),
      );
      await fillBasics(tester);
      await toExact(tester);
      expect(formState(c).included, contains(5));
      await tester.tap(find.text('Neha'));
      await tester.pumpAndSettle();
      expect(formState(c).included, [2, 3, 4]);
      expect(find.text('left out'), findsOneWidget);
      await tester.tap(find.text('Neha'));
      await tester.pumpAndSettle();
      expect(formState(c).included, [2, 3, 4, 5]);
    });

    testWidgets('a matching split can be finished and saved in paise', (
      tester,
    ) async {
      final s = Setup(members: const [milisha, riya]);
      await open(tester, s);
      await fillBasics(tester, amount: '100.50');
      await toExact(tester);
      await type(tester, 'exact-2', '25.25');
      await type(tester, 'exact-3', '75.25');
      expect(find.text('All assigned'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tapSave(tester);
      final body = s.expenses.created.single.toJson()['expense'] as Map;
      expect(body['split_type'], 'exact');
      expect(body['distribution'], [
        {'user_id': 2, 'amount': '25.25'},
        {'user_id': 3, 'amount': '75.25'},
      ]);
    });

    testWidgets('By % and Exact need an amount first', (tester) async {
      await open(tester, Setup());
      await tester.tap(find.text('Exact'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount first'), findsOneWidget);
      expect(find.textContaining('Split'), findsNothing);
    });
  });

  group('Saving', () {
    testWidgets('an equal split saves and writes the last category', (
      tester,
    ) async {
      final s = Setup();
      final c = await open(tester, s);
      await fillBasics(tester);
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay').last);
      await tester.pumpAndSettle();
      await type(tester, 'note', 'Beach shack');
      await tapSave(tester);
      final body = s.expenses.created.single.toJson()['expense'] as Map;
      expect(body['split_type'], 'equal');
      expect(body['category_id'], 2);
      expect(body['notes'], 'Beach shack');
      expect(body['name'], 'Dinner');
      expect((body['distribution'] as List).map((d) => (d as Map)['amount']), [
        '600.00',
        '600.00',
        '600.00',
        '600.00',
        '600.00',
      ]);
      expect(
        (await SharedPreferences.getInstance()).getInt('last_category_id'),
        2,
      );
      expect(locationOf(c), '/groups/1');
    });

    testWidgets(
      'a failed save keeps the form and does not remember the category',
      (tester) async {
        final s = Setup();
        s.expenses.saveError = const ApiError(
          status: 422,
          message: "Name can't be blank",
        );
        final c = await open(tester, s);
        await fillBasics(tester);
        await tapSave(tester);
        expect(find.text("Name can't be blank"), findsOneWidget);
        expect(formState(c).posting, isFalse);
        expect(
          (await SharedPreferences.getInstance()).getInt('last_category_id'),
          isNull,
        );
      },
    );

    testWidgets('Save is disabled while posting so it cannot double submit', (
      tester,
    ) async {
      final s = Setup();
      s.expenses.saveGate = Completer<void>();
      await open(tester, s);
      await fillBasics(tester);
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(s.expenses.created, hasLength(1));
      s.expenses.saveGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the form cannot be closed while posting', (tester) async {
      final s = Setup();
      s.expenses.saveGate = Completer<void>();
      final c = await open(tester, s);
      await fillBasics(tester);
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(locationOf(c), '/groups/1/expenses/new');
      s.expenses.saveGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('saving reloads the group lists', (tester) async {
      final s = Setup();
      await open(tester, s);
      final before = s.balances.calls;
      await fillBasics(tester);
      await tapSave(tester);
      expect(s.balances.calls, greaterThan(before));
    });
  });

  group('Dashboard', () {
    testWidgets('saving an expense reloads the dashboard summary', (
      tester,
    ) async {
      final s = Setup();
      final c = await open(tester, s);
      c.listen(monthlySummaryProvider(DateTime(2026, 10)), (_, _) {});
      await tester.pumpAndSettle();
      expect(s.summary.requested, ['2026-10']);
      await fillBasics(tester);
      await tapSave(tester);
      expect(s.summary.requested, ['2026-10', '2026-10']);
    });
  });

  group('Layout', () {
    const long = User(
      id: 9,
      firstName: 'Bartholomew-Alexander-Montgomery-Featherstonehaugh',
      lastName: 'Kapoor',
      email: 'long@example.com',
    );

    testWidgets('the form and split screens fit a narrow phone', (
      tester,
    ) async {
      final s = Setup(members: const [milisha, riya, long]);
      await open(tester, s);
      tester.view.physicalSize = const Size(420, 800);
      await tester.pumpAndSettle();
      await fillBasics(tester, amount: '100000000');
      expect(find.textContaining('₹1,00,00,000'), findsNothing);
      for (final label in ['By %', 'Exact', 'Equally']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text('Split ₹10,00,00,000'), findsOneWidget);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tab bar is hidden behind the form and the detail', (
      tester,
    ) async {
      final c = await open(tester, Setup(), path: '/groups/1');
      expect(find.text('Profile'), findsOneWidget);
      routerOf(c).go('/groups/1/expenses/new');
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsNothing);
    });
  });

  group('Photo', () {
    testWidgets('the photo button only shows a toast', (tester) async {
      final s = Setup();
      await open(tester, s);
      await tester.tap(find.text('Add photo'));
      await tester.pump();
      expect(find.text('Photos are coming soon'), findsOneWidget);
      expect(s.expenses.created, isEmpty);
    });
  });

  group('Edit', () {
    Expense existing() => makeExpense(
      7,
      'Hotel',
      paise: 900000,
      payer: riya,
      mine: -300000,
      creatorId: 2,
      category: stayCategory,
      splitType: SplitType.exact,
      notes: 'Two nights',
      date: DateTime(2026, 10, 20),
      shares: const [
        Share(userId: 2, paise: 300000),
        Share(userId: 3, paise: 400000),
        Share(userId: 4, paise: 200000),
      ],
    );

    testWidgets('opens filled in from the expense and updates it', (
      tester,
    ) async {
      final s = Setup();
      s.expenses.details[7] = existing();
      final c = await open(tester, s, path: '/expenses/7/edit');
      expect(find.text('Edit expense'), findsOneWidget);
      final st = formState(c, 7);
      expect(st.name, 'Hotel');
      expect(st.paise, 900000);
      expect(st.categoryId, 2);
      expect(st.payerId, 3);
      expect(st.mode, SplitMode.exact);
      expect(st.included, [2, 3, 4]);
      expect(st.exact, {2: 300000, 3: 400000, 4: 200000});
      expect(find.text('20 Oct 2026'), findsOneWidget);
      await type(tester, 'description', 'Hotel stay');
      await tapSave(tester);
      final u = s.expenses.updated.single;
      expect(u.id, 7);
      expect((u.expense.toJson()['expense'] as Map)['name'], 'Hotel stay');
      expect(s.expenses.created, isEmpty);
    });

    testWidgets('an equal expense opens as equal with the same people', (
      tester,
    ) async {
      final s = Setup();
      s.expenses.details[7] = makeExpense(
        7,
        'Dinner',
        paise: 90000,
        payer: milisha,
        creatorId: 2,
        shares: const [
          Share(userId: 2, paise: 30000),
          Share(userId: 3, paise: 30000),
          Share(userId: 4, paise: 30000),
        ],
      );
      final c = await open(tester, s, path: '/expenses/7/edit');
      expect(formState(c, 7).mode, SplitMode.equal);
      expect(formState(c, 7).included, [2, 3, 4]);
      expect(find.text('₹300 each'), findsOneWidget);
    });

    testWidgets('a percent expense opens with percents that add to 100', (
      tester,
    ) async {
      final s = Setup();
      s.expenses.details[7] = makeExpense(
        7,
        'Cab',
        paise: 10000,
        payer: milisha,
        creatorId: 2,
        splitType: SplitType.percentage,
        shares: const [
          Share(userId: 2, paise: 3333),
          Share(userId: 3, paise: 3333),
          Share(userId: 4, paise: 3334),
        ],
      );
      final c = await open(tester, s, path: '/expenses/7/edit');
      expect(formState(c, 7).percents, {2: 3333, 3: 3333, 4: 3334});
      expect(formState(c, 7).canSave, isTrue);
    });

    testWidgets('a missing expense shows the server message', (tester) async {
      final s = Setup();
      await open(tester, s, path: '/expenses/99/edit');
      expect(find.text('Expense not found'), findsOneWidget);
    });
  });

  group('Edit round trip', () {
    // Saves an untouched edit and returns the payload's distribution.
    Future<NewExpense> saveUntouched(WidgetTester tester, Expense e) async {
      final s = Setup(members: const [milisha, riya, arjun]);
      s.expenses.details[e.id] = e;
      await open(tester, s, path: '/expenses/${e.id}/edit');
      await tapSave(tester);
      return s.expenses.updated.single.expense;
    }

    Map<int, int> storedShares(Expense e) => {
      for (final x in e.shares) x.userId: x.paise,
    };

    List<int> storedOrder(Expense e) => [for (final x in e.shares) x.userId];

    // What the server computes from the payload (build_shares).
    Map<int, int> serverShares(NewExpense n) {
      final d = (n.toJson()['expense'] as Map)['distribution'] as List;
      return switch (n.splitType) {
        SplitType.equal => splitEqual(n.paise, [
          for (final x in d) (x as Map)['user_id'] as int,
        ]),
        SplitType.percentage => splitByWeights(n.paise, [
          for (final x in d)
            MapEntry(
              (x as Map)['user_id'] as int,
              double.parse(x['amount'] as String),
            ),
        ]),
        SplitType.exact => {
          for (final x in d)
            (x as Map)['user_id'] as int: paiseFromApi(x['amount'] as String),
        },
      };
    }

    List<int> payloadOrder(NewExpense n) => [
      for (final x in (n.toJson()['expense'] as Map)['distribution'] as List)
        (x as Map)['user_id'] as int,
    ];

    testWidgets('equal: the extra paisa stays on the same person', (
      tester,
    ) async {
      // The extra paisa sits on Riya, who is not first in member order.
      final e = makeExpense(
        7,
        'Dinner',
        paise: 100000,
        payer: milisha,
        creatorId: 2,
        shares: const [
          Share(userId: 3, paise: 33334),
          Share(userId: 2, paise: 33333),
          Share(userId: 4, paise: 33333),
        ],
      );
      final n = await saveUntouched(tester, e);
      expect(payloadOrder(n), storedOrder(e));
      expect(serverShares(n), storedShares(e));
    });

    testWidgets('percentage 33.33 / 33.33 / 33.34 reproduces the shares', (
      tester,
    ) async {
      final e = makeExpense(
        7,
        'Cab',
        paise: 10000,
        payer: milisha,
        creatorId: 2,
        splitType: SplitType.percentage,
        shares: const [
          Share(userId: 4, paise: 3334),
          Share(userId: 3, paise: 3333),
          Share(userId: 2, paise: 3333),
        ],
      );
      final n = await saveUntouched(tester, e);
      expect(payloadOrder(n), storedOrder(e));
      expect(serverShares(n), storedShares(e));
    });

    testWidgets('percentage 50 / 25 / 25 with a leftover paisa', (
      tester,
    ) async {
      final e = makeExpense(
        7,
        'Cab',
        paise: 10001,
        payer: milisha,
        creatorId: 2,
        splitType: SplitType.percentage,
        shares: const [
          Share(userId: 3, paise: 5001),
          Share(userId: 2, paise: 2500),
          Share(userId: 4, paise: 2500),
        ],
      );
      final n = await saveUntouched(tester, e);
      expect(payloadOrder(n), storedOrder(e));
      expect(serverShares(n), storedShares(e));
    });

    testWidgets('exact reproduces the amounts in the same order', (
      tester,
    ) async {
      final e = makeExpense(
        7,
        'Hotel',
        paise: 10000,
        payer: milisha,
        creatorId: 2,
        splitType: SplitType.exact,
        shares: const [
          Share(userId: 3, paise: 4001),
          Share(userId: 4, paise: 3000),
          Share(userId: 2, paise: 2999),
        ],
      );
      final n = await saveUntouched(tester, e);
      expect(payloadOrder(n), storedOrder(e));
      expect(serverShares(n), storedShares(e));
    });
  });

  group('Split edge cases', () {
    testWidgets('turning someone off and on again in By % resets them to 0', (
      tester,
    ) async {
      final c = await open(
        tester,
        Setup(members: const [milisha, riya, arjun, neha]),
      );
      await fillBasics(tester);
      await tester.tap(find.text('By %'));
      await tester.pumpAndSettle();
      expect(formState(c).percents, {2: 2500, 3: 2500, 4: 2500, 5: 2500});
      await tester.tap(find.text('Riya'));
      await tester.pumpAndSettle();
      expect(formState(c).included, [2, 4, 5]);
      expect(find.text('25% left'), findsOneWidget);
      await tester.tap(find.text('Riya'));
      await tester.pumpAndSettle();
      expect(formState(c).included, [2, 3, 4, 5]);
      expect(formState(c).percents[3], isNull);
      expect(find.text('25% left'), findsOneWidget);
      await type(tester, 'percent-3', '25');
      expect(find.text('100%'), findsOneWidget);
      expect(formState(c).canSave, isTrue);
    });

    testWidgets('a split with only me sends one share', (tester) async {
      final s = Setup(members: const [milisha, riya]);
      final c = await open(tester, s);
      await fillBasics(tester, amount: '100');
      await tester.tap(find.text('₹50 each'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riya'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Only you are in this split'), findsOneWidget);
      expect(formState(c).canSave, isTrue);
      await tapSave(tester);
      final body = s.expenses.created.single.toJson()['expense'] as Map;
      expect(body['distribution'], [
        {'user_id': 2, 'amount': '100.00'},
      ]);
    });

    testWidgets('someone else paid and I am out: no "You owe" line', (
      tester,
    ) async {
      final s = Setup(members: const [milisha, riya, arjun]);
      final c = await open(tester, s);
      await fillBasics(tester, amount: '100');
      await tester.tap(find.text('Paid by'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riya').last);
      await tester.pumpAndSettle();
      expect(find.text('You owe Riya ₹33.34'), findsOneWidget);
      await tester.tap(find.text('₹33.34 each'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You owe'), findsNothing);
      expect(find.text('₹50 each'), findsOneWidget);
      expect(formState(c).included, [3, 4]);
      await tapSave(tester);
      final body = s.expenses.created.single.toJson()['expense'] as Map;
      expect(body['payer_id'], 3);
      expect((body['distribution'] as List).map((d) => (d as Map)['user_id']), [
        3,
        4,
      ]);
    });

    testWidgets('a 12-digit amount splits by percent and still adds up', (
      tester,
    ) async {
      final c = await open(
        tester,
        Setup(members: const [milisha, riya, arjun]),
      );
      await fillBasics(tester, amount: '999999999999.99');
      await tester.tap(find.text('By %'));
      await tester.pumpAndSettle();
      await type(tester, 'percent-2', '33.33');
      await type(tester, 'percent-3', '33.33');
      await type(tester, 'percent-4', '33.34');
      final shares = formState(c).shares;
      expect(shares.values.fold<int>(0, (a, b) => a + b), 99999999999999);
      expect(shares[4], 33339999999999);
      expect(formState(c).canSave, isTrue);
    });

    testWidgets('saving reloads the group, its expenses and balances', (
      tester,
    ) async {
      final s = Setup();
      await open(tester, s, path: '/groups/1');
      await tester.tap(find.bySemanticsLabel('Add expense'));
      await tester.pumpAndSettle();
      final lists = s.expenses.queries.length;
      final groupGets = s.groups.gets;
      final balances = s.balances.calls;
      await fillBasics(tester);
      await tapSave(tester);
      expect(s.expenses.queries.length, greaterThan(lists));
      expect(s.groups.gets, greaterThan(groupGets));
      expect(s.balances.calls, greaterThan(balances));
    });
  });
}
