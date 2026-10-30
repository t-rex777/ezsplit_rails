import 'dart:async';

import 'package:ezsplit_mobile/data/activities_repository.dart';
import 'package:ezsplit_mobile/data/analytics_repository.dart';
import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/balances_repository.dart';
import 'package:ezsplit_mobile/data/categories_repository.dart';
import 'package:ezsplit_mobile/data/expenses_repository.dart';
import 'package:ezsplit_mobile/data/groups_repository.dart';
import 'package:ezsplit_mobile/data/jsonapi.dart' show Page;
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/data/settlements_repository.dart';
import 'package:ezsplit_mobile/data/summary_repository.dart';
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
  Future<List<FriendRequest>> friendRequests() async => const [];

  Object? updateError;
  Completer<void>? updateGate;
  final List<Map<String, Object?>> updates = [];

  @override
  Future<User> updateMe({
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? dob,
  }) async {
    updates.add({
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'dob': dob,
    });
    await updateGate?.future;
    if (updateError != null) throw updateError!;
    return User(
      id: 1,
      firstName: firstName ?? '',
      lastName: lastName ?? '',
      email: 'neha@gmail.com',
      phone: phone,
      dob: dob,
    );
  }

  int qrInvites = 0;
  Object? qrInviteError;

  @override
  Future<QrInvite> qrInvite() async {
    qrInvites++;
    if (qrInviteError != null) throw qrInviteError!;
    return QrInvite(
      url: 'http://10.0.0.5:3100/register?token=qr$qrInvites',
      expiresAt: DateTime.utc(2026, 11, 5),
    );
  }

  @override
  Future<String> invite(String email) async {
    invited.add(email);
    if (inviteError != null) throw inviteError!;
    return inviteMessage;
  }
}

List<Override> repoOverrides(
  FakeGroupsRepository groups,
  FakeUsersRepository users, {
  FakeSummaryRepository? summary,
  FakeActivitiesRepository? activities,
  FakeAnalyticsRepository? analytics,
}) => [
  groupsRepositoryProvider.overrideWithValue(groups),
  usersRepositoryProvider.overrideWithValue(users),
  activitiesRepositoryProvider.overrideWithValue(
    activities ?? FakeActivitiesRepository(),
  ),
  summaryRepositoryProvider.overrideWithValue(
    summary ?? FakeSummaryRepository(),
  ),
  analyticsRepositoryProvider.overrideWithValue(
    analytics ?? FakeAnalyticsRepository(),
  ),
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
  int? groupId = 1,
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
  groupId: groupId,
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
  Object? listError;
  Object? writeError;
  Completer<void>? writeGate;
  final List<String> calls = [];
  final List<Map<String, Object?>> written = [];

  @override
  Future<List<Category>> list() async {
    calls.add('list');
    if (listError != null) throw listError!;
    return categories;
  }

  Future<void> _write(String call, Map<String, Object?> args) async {
    calls.add(call);
    written.add(args);
    await writeGate?.future;
    if (writeError != null) throw writeError!;
  }

  @override
  Future<Category> create({
    required String name,
    required String icon,
    required String color,
  }) async {
    await _write('create', {'name': name, 'icon': icon, 'color': color});
    final made = Category(id: 99, name: name, icon: icon, color: color);
    categories = [...categories, made];
    return made;
  }

  @override
  Future<Category> update(
    int id, {
    String? name,
    String? icon,
    String? color,
  }) async {
    await _write('update', {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    });
    final next = Category(id: id, name: name!, icon: icon!, color: color!);
    categories = [for (final c in categories) c.id == id ? next : c];
    return next;
  }

  @override
  Future<void> delete(int id) async {
    await _write('delete', {'id': id});
    categories = [
      for (final c in categories)
        if (c.id != id) c,
    ];
  }
}

List<Override> detailOverrides({
  required FakeGroupsRepository groups,
  required FakeExpensesRepository expenses,
  required FakeBalancesRepository balances,
  FakeSettlementsRepository? settlements,
  FakeCategoriesRepository? categories,
  FakeSummaryRepository? summary,
  FakeActivitiesRepository? activities,
}) => [
  ...repoOverrides(
    groups,
    FakeUsersRepository(),
    summary: summary,
    activities: activities,
  ),
  expensesRepositoryProvider.overrideWithValue(expenses),
  balancesRepositoryProvider.overrideWithValue(balances),
  settlementsRepositoryProvider.overrideWithValue(
    settlements ?? FakeSettlementsRepository(),
  ),
  categoriesRepositoryProvider.overrideWithValue(
    categories ?? FakeCategoriesRepository(),
  ),
];

MonthlySummary emptySummary(String month) => MonthlySummary(
  month: month,
  mySharePaise: 0,
  youOwePaise: 0,
  owedToYouPaise: 0,
  categories: const [],
  otherCurrencies: const [],
);

class FakeSummaryRepository extends SummaryRepository {
  FakeSummaryRepository({Map<String, MonthlySummary>? byMonth})
    : byMonth = byMonth ?? {},
      super(dummyClient());

  /// Keyed "2026-10". Months not listed come back empty.
  final Map<String, MonthlySummary> byMonth;
  final List<String> requested = [];

  /// When set, month() waits on it, so tests can hold a load open.
  Completer<void>? gate;

  /// Per-month holds, keyed "2026-09", for out-of-order response tests.
  final Map<String, Completer<void>> gates = {};
  Object? error;

  @override
  Future<MonthlySummary> month(DateTime month) async {
    final key =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    requested.add(key);
    await gate?.future;
    await gates[key]?.future;
    if (error != null) throw error!;
    return byMonth[key] ?? emptySummary(key);
  }
}

class FakeActivitiesRepository extends ActivitiesRepository {
  FakeActivitiesRepository({this.entries = const []}) : super(dummyClient());

  List<ActivityEntry> entries;
  Object? error;
  final List<ActivityFilter> calls = [];

  @override
  Future<Page<ActivityEntry>> list(
    ActivityFilter filter, {
    int page = 1,
  }) async {
    calls.add(filter);
    if (error != null) throw error!;
    final items = switch (filter) {
      AllActivity() => entries,
      GroupActivity(:final groupId) =>
        entries.where((e) => e.groupId == groupId).toList(),
      FriendActivity() => entries.where((e) => e.groupId == null).toList(),
    };
    return Page(items: items, page: 1, total: items.length);
  }
}

ExpenseSnapshot makeSnapshot(
  String name, {
  required int paise,
  User payer = riya,
  List<SnapshotShare> shares = const [],
  String? groupName = 'Goa trip',
  String category = 'Food',
}) => ExpenseSnapshot(
  name: name,
  paise: paise,
  date: DateTime(2026, 10, 26),
  splitType: SplitType.equal,
  categoryName: category,
  categoryIcon: 'restaurant',
  categoryColor: '#F5C4B3',
  payerId: payer.id,
  payerName: '${payer.firstName} ${payer.lastName}',
  groupName: groupName,
  shares: shares,
);

ActivityEntry makeActivity(
  int id,
  ActivityAction action, {
  required User actor,
  ExpenseSnapshot? before,
  ExpenseSnapshot? after,
  int? groupId = 1,
  int expenseId = 1,
  DateTime? at,
  List<String> changedFields = const [],
}) => ActivityEntry(
  id: id,
  action: action,
  at: at ?? DateTime.now(),
  actorId: actor.id,
  actorName: '${actor.firstName} ${actor.lastName}',
  groupId: groupId,
  groupName: groupId == null ? null : (after ?? before)!.groupName,
  expenseId: expenseId,
  before: before,
  after: after,
  changedFields: changedFields,
);

ActivityEntry makePayment(
  int id, {
  required User payer,
  required User payee,
  required int paise,
  int? groupId = 1,
  String? groupName = 'Goa trip',
  String? notes,
}) => ActivityEntry(
  id: id,
  action: ActivityAction.settled,
  at: DateTime.now(),
  actorId: payer.id,
  actorName: '${payer.firstName} ${payer.lastName}',
  groupId: groupId,
  groupName: groupId == null ? null : groupName,
  settlementId: id,
  payment: PaymentSnapshot(
    paise: paise,
    settledOn: DateTime(2026, 10, 29),
    payerId: payer.id,
    payerName: '${payer.firstName} ${payer.lastName}',
    payeeId: payee.id,
    payeeName: '${payee.firstName} ${payee.lastName}',
    notes: notes,
  ),
  changedFields: const [],
);

class FakeAnalyticsRepository extends AnalyticsRepository {
  FakeAnalyticsRepository({Map<AnalyticsScope, List<AnalyticsMonth>>? byScope})
    : byScope = byScope ?? {},
      super(dummyClient());

  /// Scopes not listed come back with no months.
  final Map<AnalyticsScope, List<AnalyticsMonth>> byScope;
  final List<AnalyticsScope> requested = [];
  final List<({DateTime month, String category, AnalyticsScope scope})>
  expenseRequests = [];
  List<AnalyticsExpense> expenseRows = const [];
  Object? error;

  @override
  Future<List<AnalyticsMonth>> months(AnalyticsScope scope) async {
    requested.add(scope);
    if (error != null) throw error!;
    return byScope[scope] ?? const [];
  }

  @override
  Future<List<AnalyticsExpense>> expenses({
    required DateTime month,
    required String category,
    required AnalyticsScope scope,
  }) async {
    expenseRequests.add((month: month, category: category, scope: scope));
    return expenseRows;
  }
}
