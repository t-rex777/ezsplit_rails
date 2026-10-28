import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/money.dart';
import '../state/session.dart';
import 'api_client.dart';
import 'jsonapi.dart';
import 'models.dart';

class SettlementsRepository {
  SettlementsRepository(this._api);

  final ApiClient _api;

  /// The signed-in user records that they paid [payeeId].
  Future<Settlement> create({
    required int payeeId,
    required int paise,
    required DateTime settledOn,
    int? groupId,
    String? notes,
  }) async {
    final json = await _api.post(
      '/settlements',
      body: {
        'settlement': {
          'payee_id': payeeId,
          'amount': paiseToApi(paise),
          'currency': 'INR',
          'group_id': groupId,
          'notes': notes,
          'settled_on': isoDate(settledOn),
        },
      },
    );
    return parseOrThrow(() => Settlement.fromJson(JsonApiDoc(json).data));
  }
}

final settlementsRepositoryProvider = Provider<SettlementsRepository>(
  (ref) => SettlementsRepository(ref.watch(apiClientProvider)),
);
