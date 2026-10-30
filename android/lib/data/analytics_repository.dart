import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import 'api_client.dart';
import 'jsonapi.dart';
import 'models.dart';

/// Which expenses analytics counts.
enum AnalyticsScope {
  all('All'),
  groups('Groups'),
  personal('Personal');

  const AnalyticsScope(this.label);
  final String label;
}

class AnalyticsRepository {
  AnalyticsRepository(this._api);

  final ApiClient _api;

  /// Oldest month first.
  Future<List<AnalyticsMonth>> months(AnalyticsScope scope) async {
    final json = await _api.get('/analytics', query: {'scope': scope.name});
    return parseOrThrow(
      () => [
        for (final m in json['months'] as List<dynamic>)
          AnalyticsMonth.fromJson(m as Map<String, dynamic>),
      ],
    );
  }

  /// Newest first.
  Future<List<AnalyticsExpense>> expenses({
    required DateTime month,
    required String category,
    required AnalyticsScope scope,
  }) async {
    final m = month.month.toString().padLeft(2, '0');
    final json = await _api.get(
      '/analytics/expenses',
      query: {
        'month': '${month.year.toString().padLeft(4, '0')}-$m',
        'category': category,
        'scope': scope.name,
      },
    );
    return parseOrThrow(
      () => [
        for (final e in json['expenses'] as List<dynamic>)
          AnalyticsExpense.fromJson(e as Map<String, dynamic>),
      ],
    );
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(apiClientProvider)),
);
