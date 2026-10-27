import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ezsplit_mobile/data/api_client.dart';
import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/balances_repository.dart';
import 'package:ezsplit_mobile/data/categories_repository.dart';
import 'package:ezsplit_mobile/data/expenses_repository.dart';
import 'package:ezsplit_mobile/data/groups_repository.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/data/settlements_repository.dart';
import 'package:ezsplit_mobile/data/summary_repository.dart';
import 'package:ezsplit_mobile/data/users_repository.dart';
import 'package:ezsplit_mobile/state/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync());

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiClient api;
  late List<RequestOptions> sent;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = DioAdapter(dio: dio);
    sent = [];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent.add(o);
          h.next(o);
        },
      ),
    );
    api = ApiClient(dio);
  });

  group('ExpensesRepository', () {
    test('list sends sort and category_ids[] and parses a Page', () async {
      adapter.onGet(
        '/expenses',
        (s) => s.reply(200, fixture('expenses_filtered.json')),
        queryParameters: {
          'sort': 'amount_desc',
          'category_ids[]': [4],
        },
      );
      final page = await ExpensesRepository(api).list(
        const ExpenseQuery(sort: ExpenseSort.amountDesc, categoryIds: [4]),
      );
      final query = Uri.decodeFull(sent.single.uri.query);
      expect(query, contains('sort=amount_desc'));
      expect(query, contains('category_ids[]=4'));
      expect(page.items.single.name, 'Beach dinner');
    });

    test('list sends every filter by its server name', () async {
      adapter.onGet(
        '/expenses',
        (s) => s.reply(200, fixture('expenses_filtered.json')),
        queryParameters: {
          'group_id': 1,
          'q': 'dinner',
          'paid_by': 'others',
          'from': '2026-10-01',
          'to': '2026-10-31',
          'page': 2,
        },
      );
      await ExpensesRepository(api).list(
        ExpenseQuery(
          groupId: 1,
          q: 'dinner',
          paidBy: PaidBy.others,
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 31),
          page: 2,
        ),
      );
      final query = Uri.decodeFull(sent.single.uri.query);
      for (final part in [
        'group_id=1',
        'q=dinner',
        'paid_by=others',
        'from=2026-10-01',
        'to=2026-10-31',
        'page=2',
      ]) {
        expect(query, contains(part));
      }
      expect(query, isNot(contains('sort=')));
    });

    test('get parses a detailed expense', () async {
      adapter.onGet(
        '/expenses/1',
        (s) => s.reply(200, fixture('expense.json')),
      );
      final e = await ExpensesRepository(api).get(1);
      expect(e.name, 'Hotel');
      expect(e.shares, hasLength(4));
    });

    test('create posts the payload, then fetches the detail', () async {
      adapter
        ..onPost(
          '/expenses',
          (s) => s.reply(200, fixture('expense_create.json')),
          data: Matchers.any,
        )
        ..onGet(
          '/expenses/5',
          (s) => s.reply(200, fixture('expense_created_detail.json')),
        );
      final e = await ExpensesRepository(api).create(
        NewExpense(
          name: 'Coffee',
          paise: 10000,
          date: DateTime(2026, 10, 27),
          payerId: 2,
          groupId: 1,
          categoryId: 2,
          splitType: SplitType.percentage,
          notes: 'Morning',
          distribution: const [
            MapEntry(2, 33.33),
            MapEntry(3, 33.33),
            MapEntry(4, 33.34),
          ],
        ),
      );
      expect(sent.first.method, 'POST');
      final body = sent.first.data as Map<String, dynamic>;
      expect((body['expense'] as Map)['split_type'], 'percentage');
      expect(sent.last.path, '/expenses/5');
      expect(e.shares.map((s) => s.paise), [3333, 3333, 3334]);
    });

    test('update patches, then fetches the detail', () async {
      adapter
        ..onPatch(
          '/expenses/5',
          (s) => s.reply(200, fixture('expense_create.json')),
          data: Matchers.any,
        )
        ..onGet(
          '/expenses/5',
          (s) => s.reply(200, fixture('expense_created_detail.json')),
        );
      await ExpensesRepository(api).update(
        5,
        NewExpense(
          name: 'Coffee',
          paise: 10000,
          date: DateTime(2026, 10, 27),
          payerId: 2,
          categoryId: 2,
          splitType: SplitType.equal,
          distribution: const [MapEntry(2, 1), MapEntry(3, 1)],
        ),
      );
      expect(sent.first.method, 'PATCH');
      final e = (sent.first.data as Map)['expense'] as Map;
      expect(e['group_id'], isNull);
      expect(e['distribution'], [
        {'user_id': 2, 'amount': '50.00'},
        {'user_id': 3, 'amount': '50.00'},
      ]);
    });

    test('delete calls DELETE', () async {
      adapter.onDelete(
        '/expenses/5',
        (s) => s.reply(200, {'message': 'Expense was successfully deleted'}),
      );
      await ExpensesRepository(api).delete(5);
      expect(sent.single.method, 'DELETE');
    });

    test('a 2xx with an unexpected shape throws ApiError', () async {
      adapter.onGet('/expenses/1', (s) => s.reply(200, {'data': 'oops'}));
      expect(
        ExpensesRepository(api).get(1),
        throwsA(
          isA<ApiError>().having(
            (e) => e.message,
            'message',
            'Something went wrong. Try again.',
          ),
        ),
      );
    });

    test('a server error keeps the server message', () async {
      // ApiClient maps a 4xx only when Dio hands it the response, as in the app.
      final strict = Dio(
        BaseOptions(baseUrl: 'http://test', validateStatus: (s) => s! < 400),
      );
      DioAdapter(dio: strict).onPost(
        '/expenses',
        (s) => s.reply(422, {
          'errors': ['Amount must be equal to the sum of the distribution'],
        }),
        data: Matchers.any,
      );
      expect(
        ExpensesRepository(ApiClient(strict)).create(
          NewExpense(
            name: 'x',
            paise: 100,
            date: DateTime(2026, 10, 27),
            payerId: 2,
            categoryId: 1,
            splitType: SplitType.equal,
            distribution: const [MapEntry(2, 1)],
          ),
        ),
        throwsA(
          isA<ApiError>()
              .having((e) => e.status, 'status', 422)
              .having(
                (e) => e.message,
                'message',
                'Amount must be equal to the sum of the distribution',
              ),
        ),
      );
    });
  });

  group('GroupsRepository', () {
    test('list reads every page', () async {
      final page1 = Map<String, dynamic>.from(fixture('groups.json') as Map);
      page1['meta'] = {
        'total': 2,
        'current_page': 1,
        'prev_page': null,
        'next_page': 2,
        'total_pages': 2,
      };
      adapter
        ..onGet('/groups', (s) => s.reply(200, page1), queryParameters: {})
        ..onGet(
          '/groups',
          (s) => s.reply(200, fixture('groups.json')),
          queryParameters: {'page': 2},
        );
      final groups = await GroupsRepository(api).list();
      expect(groups, hasLength(4));
    });

    test('get, create, update, delete use the group paths', () async {
      adapter
        ..onGet('/groups/1', (s) => s.reply(200, fixture('group.json')))
        ..onPost(
          '/groups',
          (s) => s.reply(201, fixture('group.json')),
          data: {
            'group': {'name': 'Trip', 'description': 'd'},
          },
        )
        ..onPatch(
          '/groups/1',
          (s) => s.reply(200, fixture('group.json')),
          data: {
            'group': {'name': 'New'},
          },
        )
        ..onDelete(
          '/groups/1',
          (s) => s.reply(200, {'message': 'Group was successfully deleted'}),
        );
      final repo = GroupsRepository(api);
      expect((await repo.get(1)).name, 'Goa trip');
      await repo.create('Trip', 'd');
      await repo.update(1, name: 'New');
      await repo.delete(1);
      expect(sent.map((o) => o.method), ['GET', 'POST', 'PATCH', 'DELETE']);
    });

    test(
      'addMembers keeps current members, because the server replaces them',
      () async {
        adapter
          ..onGet('/groups/1', (s) => s.reply(200, fixture('group.json')))
          ..onPost(
            '/groups/1/add_members',
            (s) => s.reply(200, fixture('group.json')),
            data: Matchers.any,
          );
        await GroupsRepository(api).addMembers(1, [6, 3]);
        final body = sent.last.data as Map;
        expect((body['group'] as Map)['user_ids'], [2, 3, 4, 5, 6]);
      },
    );

    test('totals parses GroupTotals', () async {
      adapter.onGet(
        '/groups/1/totals',
        (s) => s.reply(200, fixture('group_totals.json')),
      );
      expect((await GroupsRepository(api).totals(1)).iPaidPaise, 900000);
    });

    test('memberships returns active memberships only', () async {
      adapter.onGet(
        '/groups/1/group_memberships',
        (s) => s.reply(200, fixture('group_memberships.json')),
      );
      final ms = await GroupsRepository(api).memberships(1);
      expect(ms.map((m) => (m.id, m.userId)), [(1, 2), (2, 3), (3, 4), (4, 5)]);
    });

    test('removeMember deletes the membership', () async {
      adapter.onDelete(
        '/groups/1/group_memberships/3',
        (s) => s.reply(200, {'status': 'success'}),
      );
      await GroupsRepository(api).removeMember(1, 3);
      expect(sent.single.path, '/groups/1/group_memberships/3');
    });
  });

  group('other repositories', () {
    test('balances', () async {
      adapter
        ..onGet(
          '/groups/1/balances',
          (s) => s.reply(200, fixture('group_balances.json')),
        )
        ..onGet('/balances', (s) => s.reply(200, fixture('balances.json')));
      final repo = BalancesRepository(api);
      expect((await repo.forGroup(1)).first.paise, 475000);
      expect((await repo.mine()).first.paise, 125000);
    });

    test('settlement create sends the spec payload', () async {
      adapter.onPost(
        '/settlements',
        (s) => s.reply(201, fixture('settlement_create.json')),
        data: {
          'settlement': {
            'payee_id': 3,
            'amount': '100.00',
            'currency': 'INR',
            'group_id': 1,
            'notes': null,
            'settled_on': '2026-10-27',
          },
        },
      );
      final s = await SettlementsRepository(api).create(
        payeeId: 3,
        paise: 10000,
        groupId: 1,
        settledOn: DateTime(2026, 10, 27),
      );
      expect(s.paise, 10000);
    });

    test('categories CRUD', () async {
      adapter
        ..onGet('/categories', (s) => s.reply(200, fixture('categories.json')))
        ..onPost(
          '/categories',
          (s) => s.reply(200, {
            'data': (fixture('categories.json') as Map)['data'][0],
          }),
          data: {
            'category': {
              'name': 'Food',
              'icon': 'restaurant',
              'color': '#FAC775',
            },
          },
        )
        ..onPatch(
          '/categories/1',
          (s) => s.reply(200, {
            'data': (fixture('categories.json') as Map)['data'][0],
          }),
          data: {
            'category': {'name': 'Eats'},
          },
        )
        ..onDelete('/categories/1', (s) => s.reply(200, {'message': 'ok'}));
      final repo = CategoriesRepository(api);
      expect(await repo.list(), hasLength(3));
      await repo.create(name: 'Food', icon: 'restaurant', color: '#FAC775');
      await repo.update(1, name: 'Eats');
      await repo.delete(1);
      expect(sent, hasLength(4));
    });

    test('users: friends, search, me, updateMe, invite', () async {
      adapter
        ..onGet('/users', (s) => s.reply(200, fixture('friends.json')))
        ..onGet(
          '/users/search',
          (s) => s.reply(200, fixture('users_search.json')),
          queryParameters: {'term': 'ri'},
        )
        ..onGet('/me', (s) => s.reply(200, fixture('me.json')))
        ..onPatch(
          '/me',
          (s) => s.reply(200, fixture('me_update.json')),
          data: {
            'user': {'phone': '9123456780'},
          },
        )
        ..onPost(
          '/invitations',
          (s) => s.reply(201, {'message': 'Invitation sent successfully.'}),
          data: {
            'invitation': {'email_address': 'a@b.com'},
          },
        );
      final repo = UsersRepository(api);
      expect(await repo.friends(), hasLength(3));
      expect((await repo.search('ri')).single.firstName, 'Riya');
      expect((await repo.me()).id, 2);
      expect((await repo.updateMe(phone: '9123456780')).phone, '9123456780');
      expect(await repo.invite('a@b.com'), 'Invitation sent successfully.');
    });

    test('summary sends month as YYYY-MM', () async {
      adapter.onGet(
        '/summary',
        (s) => s.reply(200, fixture('summary.json')),
        queryParameters: {'month': '2026-10'},
      );
      final s = await SummaryRepository(api).month(DateTime(2026, 10, 15));
      expect(s.owedToYouPaise, 450000);
    });
  });

  test('repositories are exposed as Providers', () {
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    expect(container.read(groupsRepositoryProvider), isA<GroupsRepository>());
    expect(
      container.read(expensesRepositoryProvider),
      isA<ExpensesRepository>(),
    );
    expect(
      container.read(balancesRepositoryProvider),
      isA<BalancesRepository>(),
    );
    expect(
      container.read(settlementsRepositoryProvider),
      isA<SettlementsRepository>(),
    );
    expect(
      container.read(categoriesRepositoryProvider),
      isA<CategoriesRepository>(),
    );
    expect(container.read(usersRepositoryProvider), isA<UsersRepository>());
    expect(container.read(summaryRepositoryProvider), isA<SummaryRepository>());
  });
}
