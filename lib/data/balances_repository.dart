import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import 'api_client.dart';
import 'jsonapi.dart';
import 'models.dart';

class BalancesRepository {
  BalancesRepository(this._api);

  final ApiClient _api;

  /// Positive: the group owes that member. Negative: they owe the group.
  Future<List<BalanceRow>> forGroup(int groupId) =>
      _rows('/groups/$groupId/balances');

  /// Per person: positive means they owe me, negative means I owe them.
  Future<List<BalanceRow>> mine() => _rows('/balances');

  Future<List<BalanceRow>> _rows(String path) async {
    final json = await _api.get(path);
    return parseOrThrow(
      () => [for (final r in JsonApiDoc(json).rawList) BalanceRow.fromJson(r)],
    );
  }
}

final balancesRepositoryProvider = Provider<BalancesRepository>(
  (ref) => BalancesRepository(ref.watch(apiClientProvider)),
);
