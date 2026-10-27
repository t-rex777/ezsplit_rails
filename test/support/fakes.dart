import 'dart:async';

import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/balances_repository.dart';
import 'package:ezsplit_mobile/data/categories_repository.dart';
import 'package:ezsplit_mobile/data/expenses_repository.dart';
import 'package:ezsplit_mobile/data/groups_repository.dart';
import 'package:ezsplit_mobile/data/jsonapi.dart' show Page;
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/data/settlements_repository.dart';
import 'package:ezsplit_mobile/data/users_repository.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'harness.dart';

const riya = User(
  id: 3,
  firstName: 'Riya',
  lastName: 'Kapoor',
  email: 'riya@example.com',
);
const arjun = User(
  id: 4,
  firstName: 'Arjun',
  lastName: 'Mehta',
  email: 'arjun@example.com',
);
const sam = User(
  id: 5,
  firstName: 'Sam',
  lastName: 'Rao',
  email: 'sam@example.com',
);

Group makeGroup(
  int id,
  String name, {
  int net = 0,
  List<User> members = const [testUser, riya, arjun],
  int ownerId = 1,
  String? description,
  DateTime? lastActivityAt,
}) => Group(
  id: id,
  name: name,
  ownerId: ownerId,
  members: members,
  myNetPaise: net,
  description: description,
  lastActivityAt: lastActivityAt,
);

class FakeGroupsRepository extends GroupsRepository {
  FakeGroupsRepository({this.groups = const []}) : super(dummyClient());

  List<Group> groups;
  Object? removeError;
  Object? deleteError;
  GroupTotals? totalsResult;
  final List<String> calls = [];
  final List<List<int>> added = [];

  @override
  Future<List<Group>> list() async => groups;

  int gets = 0;

  @override
  Future<Group> get(int id) async {
    gets++;
    return groups.firstWhere((g) => g.id == id);
  }

  @override
  Future<Group> create(String name, String? description) async {
    calls.add('create $name');
    return makeGroup(99, name, description: description);
  }

  @override
  Future<Group> update(int id, {String? name, String? description}) async {
    calls.add('update $id');
    return groups.firstWhere((g) => g.id == id);
  }

  @override
  Future<void> delete(int id) async {
    calls.add('delete $id');
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<Group> addMembers(int id, List<int> userIds) async {
    calls.add('addMembers $id');
    added.add(userIds);
    return groups.firstWhere(
      (g) => g.id == id,
      orElse: () => makeGroup(id, 'x'),
    );
  }

  @override
  Future<void> removeMember(int groupId, int membershipId) async {
    calls.add('removeMember $groupId $membershipId');
    if (removeError != null) throw removeError!;
  }

  @override
  Future<GroupTotals> totals(int id) async =>
      totalsResult ??
      const GroupTotals(
        totalSpentPaise: 0,
        mySharePaise: 0,
        iPaidPaise: 0,
        categories: [],
        paidBy: [],
      );

  @override
  Future<List<Membership>> memberships(int groupId) async => [
    for (final m in groups.firstWhere((g) => g.id == groupId).members)
      Membership(id: 100 + m.id, userId: m.id, active: true),
  ];
}

class FakeUsersRepository extends UsersRepository {
  FakeUsersRepository({this.friendList = const []}) : super(dummyClient());

  List<User> friendList;
  String inviteMessage = 'Invitation sent successfully.';
  Object? inviteError;
  final List<String> invited = [];

  @override
  Future<List<User>> friends() async => friendList;

  @override
  Future<String> invite(String email) async {
    invited.add(email);
    if (inviteError != null) throw inviteError!;
    return inviteMessage;
  }
}

List<Override> repoOverrides(
  FakeGroupsRepository groups,
  FakeUsersRepository users,
) => [
  groupsRepositoryProvider.overrideWithValue(groups),
  usersRepositoryProvider.overrideWithValue(users),
];

const milisha = User(
  id: 2,
  firstName: 'Milisha',
  lastName: 'Saran',
  email: 'milisha@example.com',
);
const neha = User(
  id: 5,
  firstName: 'Neha',
  lastName: 'Rao',
  email: 'neharao@example.com',
);

const foodCategory = Category(
  id: 1,
  name: 'Food',
  icon: 'restaurant',
  color: '#FAC775',
);
const stayCategory = Category(
  id: 2,
  name: 'Stay',
  icon: 'hotel',
  color: '#5DCAA5',
);

Expense makeExpense(
  int id,
  String name, {
  int paise = 100000,
  User payer = riya,
  int mine = -20000,
  DateTime? date,
  Category category = foodCategory,
  SplitType splitType = SplitType.equal,
  List<Share> shares = const [],
  int? creatorId,
  String? notes,
}) => Expense(
  id: id,
  name: name,
  paise: paise,
  currency: 'INR',
  splitType: splitType,
  date: date ?? DateTime(2026, 10, 24),
  payer: payer,
  category: category,
  shares: shares,
  creatorId: creatorId ?? payer.id,
  myAmountPaise: mine,
  notes: notes,
  groupId: 1,
);

BalanceRow balanceRow(User u, int paise) => BalanceRow(
  userId: u.id,
  firstName: u.firstName,
  lastName: u.lastName,
  currency: 'INR',
  paise: paise,
);

/// The Goa numbers from the design canvas: I am owed, I owe nothing.
List<BalanceRow> goaBalances() => [
  balanceRow(milisha, 185000),
  balanceRow(riya, 90000),
  balanceRow(arjun, -45000),
  balanceRow(neha, -230000),
];

class FakeExpensesRepository extends ExpensesRepository {
  FakeExpensesRepository({this.expenses = const [], this.pageSize})
    : super(dummyClient());

  List<Expense> expenses;
  int? pageSize;

  /// Overrides the meta total when set (the dry-run count).
  int? totalOverride;
  Object? error;
  Completer<void>? gate;
  final List<ExpenseQuery> queries = [];

  /// Expenses `get` can return, by id. Falls back to [expenses].
  final Map<int, Expense> details = {};
  Object? saveError;
  Object? deleteError;
  Completer<void>? saveGate;
  final List<NewExpense> created = [];
  final List<({int id, NewExpense expense})> updated = [];
  final List<int> deleted = [];

  @override
  Future<Expense> get(int id) async {
    final e = details[id] ?? expenses.where((x) => x.id == id).firstOrNull;
    if (e == null) {
      throw const ApiError(status: 404, message: 'Expense not found');
    }
    return e;
  }

  @override
  Future<Expense> create(NewExpense expense) async {
    created.add(expense);
    await saveGate?.future;
    if (saveError != null) throw saveError!;
    return makeExpense(900, expense.name, paise: expense.paise);
  }

  @override
  Future<Expense> update(int id, NewExpense expense) async {
    updated.add((id: id, expense: expense));
    await saveGate?.future;
    if (saveError != null) throw saveError!;
    return makeExpense(id, expense.name, paise: expense.paise);
  }

  @override
  Future<void> delete(int id) async {
    deleted.add(id);
    await saveGate?.future;
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<Page<Expense>> list(ExpenseQuery query) async {
    queries.add(query);
    await gate?.future;
    if (error != null) throw error!;
    final page = query.page ?? 1;
    final size = pageSize ?? (expenses.isEmpty ? 1 : expenses.length);
    final start = (page - 1) * size;
    final items = expenses.skip(start).take(size).toList();
    final more = start + size < expenses.length;
    return Page(
      items: items,
      page: page,
      total: totalOverride ?? expenses.length,
      nextPage: more ? page + 1 : null,
    );
  }
}

class FakeBalancesRepository extends BalancesRepository {
  FakeBalancesRepository(this.rows) : super(dummyClient());

  List<BalanceRow> rows;
  int calls = 0;

  @override
  Future<List<BalanceRow>> forGroup(int groupId) async {
    calls++;
    return rows;
  }
}

class FakeSettlementsRepository extends SettlementsRepository {
  FakeSettlementsRepository() : super(dummyClient());

  Object? error;
  Completer<void>? gate;
  final List<({int payeeId, int paise, int? groupId})> created = [];

  @override
  Future<Settlement> create({
    required int payeeId,
    required int paise,
    required DateTime settledOn,
    int? groupId,
    String? notes,
  }) async {
    created.add((payeeId: payeeId, paise: paise, groupId: groupId));
    await gate?.future;
    if (error != null) throw error!;
    return Settlement(
      id: 1,
      payerId: 2,
      payeeId: payeeId,
      paise: paise,
      groupId: groupId,
      settledOn: settledOn,
    );
  }
}

class FakeCategoriesRepository extends CategoriesRepository {
  FakeCategoriesRepository([
    this.categories = const [foodCategory, stayCategory],
  ]) : super(dummyClient());

  List<Category> categories;

  @override
  Future<List<Category>> list() async => categories;
}

List<Override> detailOverrides({
  required FakeGroupsRepository groups,
  required FakeExpensesRepository expenses,
  required FakeBalancesRepository balances,
  FakeSettlementsRepository? settlements,
  FakeCategoriesRepository? categories,
}) => [
  ...repoOverrides(groups, FakeUsersRepository()),
  expensesRepositoryProvider.overrideWithValue(expenses),
  balancesRepositoryProvider.overrideWithValue(balances),
  settlementsRepositoryProvider.overrideWithValue(
    settlements ?? FakeSettlementsRepository(),
  ),
  categoriesRepositoryProvider.overrideWithValue(
    categories ?? FakeCategoriesRepository(),
  ),
];
