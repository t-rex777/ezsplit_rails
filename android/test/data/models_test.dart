import 'dart:convert';
import 'dart:io';

import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/jsonapi.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

JsonApiDoc doc(String name) => JsonApiDoc(
  jsonDecode(File('test/fixtures/$name').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  test('groups.json parses into Groups with members and money in paise', () {
    final d = doc('groups.json');
    final groups = [for (final r in d.list) Group.fromJson(r, d.index)];
    expect(groups, hasLength(2));
    final goa = groups.first;
    expect(goa.id, 1);
    expect(goa.name, 'Goa trip');
    expect(goa.description, 'October beach trip');
    expect(goa.ownerId, 2);
    expect(goa.members.map((m) => m.firstName), [
      'Milisha',
      'Riya',
      'Arjun',
      'Neha',
    ]);
    expect(goa.myNetPaise, 475000);
    expect(goa.lastActivityAt, DateTime.utc(2026, 10, 27, 17, 46, 59, 48));
    expect(groups.last.description, isNull);
    expect(groups.last.myNetPaise, -25000);
  });

  test('group.json parses a single Group', () {
    final d = doc('group.json');
    final g = Group.fromJson(d.data, d.index);
    expect(g.members, hasLength(4));
    expect(g.members.first.initials, 'MS');
  });

  test('categories.json parses into Categories', () {
    final d = doc('categories.json');
    final cats = [for (final r in d.list) Category.fromJson(r)];
    expect(cats.map((c) => c.name), ['Food', 'Travel', 'Stay']);
    expect(cats.first.icon, 'restaurant');
    expect(cats.first.color, '#FAC775');
    expect(cats.first.id, 1);
  });

  test('expenses.json parses; shares add up to the amount', () {
    final d = doc('expenses.json');
    final expenses = [for (final r in d.list) Expense.fromJson(r, d.index)];
    expect(expenses.map((e) => e.name), [
      'Cab to airport',
      'Beach dinner',
      'Hotel',
    ]);
    for (final e in expenses) {
      expect(
        e.shares.fold<int>(0, (a, s) => a + s.paise),
        e.paise,
        reason: e.name,
      );
    }
    final cab = expenses.first;
    expect(cab.paise, 100000);
    expect(cab.currency, 'INR');
    expect(cab.splitType, SplitType.equal);
    expect(cab.date, DateTime(2026, 10, 26));
    expect(cab.notes, isNull);
    expect(cab.payer.firstName, 'Arjun');
    expect(cab.groupId, 1);
    expect(cab.category.name, 'Travel');
    expect(cab.creatorId, 4);
    expect(cab.myAmountPaise, -25000);
    expect(cab.shares.map((s) => s.userId), [2, 3, 4, 5]);
    expect(expenses.last.myAmountPaise, 225000);
  });

  test('expense.json and expense_created_detail.json parse', () {
    final d = doc('expense.json');
    final e = Expense.fromJson(d.data, d.index);
    expect(e.name, 'Hotel');
    expect(e.shares, hasLength(4));

    final c = doc('expense_created_detail.json');
    final created = Expense.fromJson(c.data, c.index);
    expect(created.splitType, SplitType.percentage);
    expect(created.notes, 'Morning');
    expect(created.shares.map((s) => s.paise), [3333, 3333, 3334]);
    expect(created.shares.fold<int>(0, (a, s) => a + s.paise), created.paise);
  });

  test('expense_create.json has no included payer, so it throws ApiError', () {
    final d = doc('expense_create.json');
    expect(
      () => parseOrThrow(() => Expense.fromJson(d.data, d.index)),
      throwsA(
        isA<ApiError>().having(
          (e) => e.message,
          'message',
          'Something went wrong. Try again.',
        ),
      ),
    );
  });

  test('expenses_filtered.json carries page meta', () {
    final d = doc('expenses_filtered.json');
    final page = d.page((r) => Expense.fromJson(r, d.index));
    expect(page.items, hasLength(1));
    expect(page.total, 1);
    expect(page.page, 1);
    expect(page.nextPage, isNull);
  });

  test('balances.json and group_balances.json parse into BalanceRows', () {
    final rows = [
      for (final r in doc('balances.json').rawList) BalanceRow.fromJson(r),
    ];
    expect(rows.map((r) => r.paise), [125000, 200000, 125000]);
    expect(rows.first.userId, 3);
    expect(rows.first.firstName, 'Riya');
    expect(rows.first.currency, 'INR');

    final group = [
      for (final r in doc('group_balances.json').rawList)
        BalanceRow.fromJson(r),
    ];
    expect(group.map((r) => r.paise), [475000, -25000, -225000, -225000]);
  });

  test('settlement_create.json parses into a Settlement', () {
    final s = Settlement.fromJson(doc('settlement_create.json').data);
    expect(s.id, 2);
    expect(s.payerId, 2);
    expect(s.payeeId, 3);
    expect(s.paise, 10000);
    expect(s.groupId, 1);
    expect(s.settledOn, DateTime(2026, 10, 27));
  });

  test('summary.json parses into a MonthlySummary', () {
    final s = MonthlySummary.fromJson(
      jsonDecode(File('test/fixtures/summary.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(s.month, '2026-10');
    expect(s.mySharePaise, 350000);
    expect(s.youOwePaise, 0);
    expect(s.owedToYouPaise, 450000);
    expect(s.categories.map((c) => c.name), ['Stay', 'Food', 'Travel']);
    expect(s.categories.first.paise, 225000);
    expect(s.categories.first.icon, 'hotel');
    expect(s.otherCurrencies, isEmpty);
  });

  test('group_totals.json parses into GroupTotals', () {
    final t = GroupTotals.fromJson(
      jsonDecode(File('test/fixtures/group_totals.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(t.totalSpentPaise, 1300000);
    expect(t.mySharePaise, 325000);
    expect(t.iPaidPaise, 900000);
    expect(t.categories.first.name, 'Stay');
    expect(t.paidBy.map((p) => p.userId), [2, 3, 4]);
    expect(t.paidBy.first.firstName, 'Milisha');
    expect(t.paidBy.first.paise, 900000);
  });

  test('friends.json, users_search.json, me.json parse into Users', () {
    final f = doc('friends.json');
    final friends = [for (final r in f.list) User.fromJson(r)];
    expect(friends.map((u) => u.firstName), ['Riya', 'Arjun', 'Neha']);
    expect(friends.first.phone, isNull);
    expect(friends.first.dob, isNull);
    expect(User.fromJson(doc('users_search.json').list.single).id, 3);
    expect(
      User.fromJson(doc('me.json').data).email,
      'milisha.demo@example.com',
    );
  });

  test('group_memberships.json parses active memberships', () {
    final d = doc('group_memberships.json');
    final all = [for (final r in d.list) Membership.fromJson(r)];
    expect(all.map((m) => (m.id, m.userId)), [
      (1, 2),
      (2, 3),
      (3, 4),
      (4, 5),
      (7, 6),
    ]);
    expect(all.map((m) => m.active), [true, true, true, true, false]);
  });

  group('NewExpense.toJson', () {
    NewExpense make(SplitType type, List<MapEntry<int, int>> dist, int paise) =>
        NewExpense(
          name: 'Dinner',
          paise: paise,
          date: DateTime(2026, 10, 27),
          payerId: 2,
          groupId: 1,
          categoryId: 3,
          splitType: type,
          notes: 'n',
          distribution: dist,
        );

    test('equal sends client-computed amounts', () {
      final json = make(SplitType.equal, [
        const MapEntry(1, 1),
        const MapEntry(2, 1),
        const MapEntry(3, 1),
      ], 10000).toJson();
      final e = json['expense'] as Map<String, dynamic>;
      expect(e['distribution'], [
        {'user_id': 1, 'amount': '33.34'},
        {'user_id': 2, 'amount': '33.33'},
        {'user_id': 3, 'amount': '33.33'},
      ]);
      expect(e['amount'], '100.00');
      expect(e['currency'], 'INR');
      expect(e['split_type'], 'equal');
      expect(e['expense_date'], '2026-10-27');
      expect(e['payer_id'], 2);
      expect(e['group_id'], 1);
      expect(e['category_id'], 3);
      expect(e['notes'], 'n');
      expect(e['name'], 'Dinner');
    });

    test('percentage sends the percents', () {
      final e =
          make(SplitType.percentage, [
                const MapEntry(1, 3333),
                const MapEntry(2, 3333),
                const MapEntry(3, 3334),
              ], 10000).toJson()['expense']
              as Map<String, dynamic>;
      expect(e['split_type'], 'percentage');
      expect(e['distribution'], [
        {'user_id': 1, 'amount': '33.33'},
        {'user_id': 2, 'amount': '33.33'},
        {'user_id': 3, 'amount': '33.34'},
      ]);
    });

    test('percentage formats whole hundredths with 2 decimals', () {
      final e =
          make(SplitType.percentage, [
                const MapEntry(1, 5000),
                const MapEntry(2, 30),
                const MapEntry(3, 4970),
              ], 10000).toJson()['expense']
              as Map<String, dynamic>;
      expect((e['distribution'] as List).map((d) => (d as Map)['amount']), [
        '50.00',
        '0.30',
        '49.70',
      ]);
    });

    test('exact sends paise as API strings', () {
      final e =
          make(SplitType.exact, [
                const MapEntry(1, 2550),
                const MapEntry(2, 7450),
              ], 10000).toJson()['expense']
              as Map<String, dynamic>;
      expect(e['split_type'], 'exact');
      expect(e['distribution'], [
        {'user_id': 1, 'amount': '25.50'},
        {'user_id': 2, 'amount': '74.50'},
      ]);
    });
  });
}
