import 'package:ezsplit_mobile/data/groups_repository.dart';
import 'package:ezsplit_mobile/data/models.dart';
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
  final List<String> calls = [];
  final List<List<int>> added = [];

  @override
  Future<List<Group>> list() async => groups;

  @override
  Future<Group> get(int id) async => groups.firstWhere((g) => g.id == id);

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
