@Tags(['live'])
library;

import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/auth_repository.dart';
import 'package:ezsplit_mobile/data/balances_repository.dart';
import 'package:ezsplit_mobile/data/categories_repository.dart';
import 'package:ezsplit_mobile/data/expenses_repository.dart';
import 'package:ezsplit_mobile/data/groups_repository.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/data/settlements_repository.dart';
import 'package:ezsplit_mobile/data/summary_repository.dart';
import 'package:ezsplit_mobile/data/users_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Talks to a real Rails server with demo data loaded. See README, "Live API test".
const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3100',
);
const _inviteToken = String.fromEnvironment('INVITE_TOKEN');
const _password = 'password123';

class _Session {
  _Session()
    : jar = CookieJar(),
      dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          headers: apiHeaders,
          followRedirects: false,
          validateStatus: (s) => s != null && s < 400,
        ),
      ) {
    dio.interceptors.add(CookieManager(jar));
    api = ApiClient(dio, cookieJar: jar);
    auth = AuthRepository(api, jar);
    users = UsersRepository(api);
    groups = GroupsRepository(api);
    expenses = ExpensesRepository(api);
    balances = BalancesRepository(api);
    settlements = SettlementsRepository(api);
    summary = SummaryRepository(api);
    categories = CategoriesRepository(api);
  }

  final CookieJar jar;
  final Dio dio;
  late final ApiClient api;
  late final AuthRepository auth;
  late final UsersRepository users;
  late final GroupsRepository groups;
  late final ExpensesRepository expenses;
  late final BalancesRepository balances;
  late final SettlementsRepository settlements;
  late final SummaryRepository summary;
  late final CategoriesRepository categories;
}

void main() {
  setUpAll(() {
    // flutter_test swaps in a client that fails every request.
    HttpOverrides.global = null;
  });

  test('money flow: group, expense, balances, settle up, clean up', () async {
    final me = _Session();
    final user = await me.auth.login('milisha.demo@example.com', _password);
    expect(user.email, 'milisha.demo@example.com');

    final friends = await me.users.friends();
    final riya = friends.firstWhere((f) => f.firstName == 'Riya');

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final created = await me.groups.create('Live test $stamp', null);
    final groupId = created.id;
    try {
      final withRiya = await me.groups.addMembers(groupId, [riya.id]);
      expect(
        withRiya.members.map((m) => m.id),
        containsAll([user.id, riya.id]),
      );

      final categories = await me.categories.list();
      final expense = await me.expenses.create(
        NewExpense(
          name: 'Live dinner',
          paise: 300000,
          date: DateTime.now(),
          payerId: user.id,
          groupId: groupId,
          categoryId: categories.first.id,
          splitType: SplitType.percentage,
          distribution: [MapEntry(user.id, 60), MapEntry(riya.id, 40)],
        ),
      );
      final reloaded = await me.expenses.get(expense.id);
      expect(reloaded.paise, 300000);
      expect(reloaded.shares.fold<int>(0, (a, s) => a + s.paise), 300000);
      final byUser = {for (final s in reloaded.shares) s.userId: s.paise};
      expect(byUser, {user.id: 180000, riya.id: 120000});

      var rows = await me.balances.forGroup(groupId);
      expect(rows.firstWhere((r) => r.userId == user.id).paise, 120000);
      expect(rows.firstWhere((r) => r.userId == riya.id).paise, -120000);

      // The API records the signed-in user as payer, so Riya settles herself.
      final riyaSession = _Session();
      await riyaSession.auth.login('riya.demo@example.com', _password);
      final settlement = await riyaSession.settlements.create(
        payeeId: user.id,
        paise: 120000,
        settledOn: DateTime.now(),
        groupId: groupId,
      );
      expect(settlement.payerId, riya.id);
      expect(settlement.payeeId, user.id);
      expect(settlement.paise, 120000);
      await riyaSession.auth.logout();

      rows = await me.balances.forGroup(groupId);
      // A settled group has no balance rows at all.
      expect(rows.where((r) => r.paise != 0), isEmpty);

      final month = await me.summary.month(DateTime.now());
      expect(month.month, isNotEmpty);
      expect(month.mySharePaise, greaterThanOrEqualTo(180000));

      final totals = await me.groups.totals(groupId);
      expect(totals.totalSpentPaise, 300000);
      expect(totals.mySharePaise, 180000);
      expect(totals.iPaidPaise, 300000);
    } finally {
      // The server refuses to delete a group that has expenses or settlements,
      // and the API cannot delete a settlement. So the settled group stays.
      final left = await me.expenses.list(ExpenseQuery(groupId: groupId));
      for (final e in left.items) {
        await me.expenses.delete(e.id);
      }
      try {
        await me.groups.delete(groupId);
      } on ApiError catch (e) {
        expect(e.status, 422);
        expect(e.message, contains('dependent settlements exist'));
      }
    }

    // An empty group can be deleted by its owner.
    final empty = await me.groups.create('Live test empty $stamp', null);
    await me.groups.delete(empty.id);
    await expectLater(
      me.groups.get(empty.id),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 404)),
    );

    await me.auth.logout();
    await expectLater(
      me.groups.list(),
      throwsA(
        isA<ApiError>().having((e) => e.isUnauthorized, 'isUnauthorized', true),
      ),
    );
  });

  test('invite acceptance for sam.demo@example.com', () async {
    // --run-skipped would override a `skip:` argument, so guard in the body.
    if (_inviteToken.isEmpty) {
      markTestSkipped(
        'Set --dart-define=INVITE_TOKEN=... (single-use) to run.',
      );
      return;
    }
    final s = _Session();
    final user = await s.auth.acceptInvite(
      token: _inviteToken,
      email: 'sam.demo@example.com',
      firstName: 'Sam',
      lastName: 'Demo',
      phone: '9000000000',
      dob: DateTime(1995, 5, 5),
      password: _password,
    );
    expect(user.email, 'sam.demo@example.com');
  });
}
