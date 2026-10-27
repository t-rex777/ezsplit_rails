import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import 'api_client.dart';
import 'jsonapi.dart';
import 'models.dart';

class GroupsRepository {
  GroupsRepository(this._api);

  final ApiClient _api;

  Future<List<Group>> list() => allPages((page) async {
    final json = await _api.get('/groups', query: {if (page > 1) 'page': page});
    return parseOrThrow(() {
      final doc = JsonApiDoc(json);
      return doc.page((r) => Group.fromJson(r, doc.index));
    });
  });

  Future<Group> get(int id) async => _group(await _api.get('/groups/$id'));

  Future<Group> create(String name, String? description) async => _group(
    await _api.post(
      '/groups',
      body: {
        'group': {'name': name, 'description': description},
      },
    ),
  );

  Future<Group> update(int id, {String? name, String? description}) async =>
      _group(
        await _api.patch(
          '/groups/$id',
          body: {
            'group': {'name': ?name, 'description': ?description},
          },
        ),
      );

  Future<void> delete(int id) async {
    await _api.delete('/groups/$id');
  }

  /// Adds [userIds] to the group. The server replaces the whole member list
  /// with what it is sent, so this sends the current members plus the new ones.
  Future<Group> addMembers(int id, List<int> userIds) async {
    final current = await get(id);
    final ids = <int>[
      for (final m in current.members) m.id,
      for (final u in userIds)
        if (!current.members.any((m) => m.id == u)) u,
    ];
    return _group(
      await _api.post(
        '/groups/$id/add_members',
        body: {
          'group': {'user_ids': ids},
        },
      ),
    );
  }

  /// [membershipId] comes from [memberships]; group payloads do not carry it.
  Future<void> removeMember(int groupId, int membershipId) async {
    await _api.delete('/groups/$groupId/group_memberships/$membershipId');
  }

  /// Active memberships only (the server also lists people who left).
  Future<List<Membership>> memberships(int groupId) async {
    final all = await allPages((page) async {
      final json = await _api.get(
        '/groups/$groupId/group_memberships',
        query: {if (page > 1) 'page': page},
      );
      return parseOrThrow(() => JsonApiDoc(json).page(Membership.fromJson));
    });
    return [
      for (final m in all)
        if (m.active) m,
    ];
  }

  Future<GroupTotals> totals(int id) async {
    final json = await _api.get('/groups/$id/totals');
    return parseOrThrow(() => GroupTotals.fromJson(json));
  }

  Group _group(Map<String, dynamic> json) => parseOrThrow(() {
    final doc = JsonApiDoc(json);
    return Group.fromJson(doc.data, doc.index);
  });
}

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => GroupsRepository(ref.watch(apiClientProvider)),
);
