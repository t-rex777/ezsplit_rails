import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import 'api_client.dart';
import 'jsonapi.dart';
import 'models.dart';

class SummaryRepository {
  SummaryRepository(this._api);

  final ApiClient _api;

  Future<MonthlySummary> month(DateTime month) async {
    final m = month.month.toString().padLeft(2, '0');
    final json = await _api.get(
      '/summary',
      query: {'month': '${month.year.toString().padLeft(4, '0')}-$m'},
    );
    return parseOrThrow(() => MonthlySummary.fromJson(json));
  }
}

final summaryRepositoryProvider = Provider<SummaryRepository>(
  (ref) => SummaryRepository(ref.watch(apiClientProvider)),
);
