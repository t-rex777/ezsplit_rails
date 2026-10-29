import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import 'api_client.dart';
import 'jsonapi.dart';
import 'models.dart';

/// Which entries the Activity tab shows.
sealed class ActivityFilter {
  const ActivityFilter();

  Object? get groupParam;
}

class AllActivity extends ActivityFilter {
  const AllActivity();

  @override
  Object? get groupParam => null;

  @override
  bool operator ==(Object other) => other is AllActivity;

  @override
  int get hashCode => 0;
}

class GroupActivity extends ActivityFilter {
  const GroupActivity(this.groupId);

  final int groupId;

  @override
  Object? get groupParam => groupId;

  @override
  bool operator ==(Object other) =>
      other is GroupActivity && other.groupId == groupId;

  @override
  int get hashCode => groupId.hashCode;
}

/// Expenses outside any group.
class FriendActivity extends ActivityFilter {
  const FriendActivity();

  @override
  Object? get groupParam => 'none';

  @override
  bool operator ==(Object other) => other is FriendActivity;

  @override
  int get hashCode => 1;
}

class ActivitiesRepository {
  ActivitiesRepository(this._api);

  final ApiClient _api;

  Future<Page<ActivityEntry>> list(
    ActivityFilter filter, {
    int page = 1,
  }) async {
    final json = await _api.get(
      '/activities',
      query: {
        'page': page,
        if (filter.groupParam != null) 'group_id': filter.groupParam,
      },
    );
    return parseOrThrow(() => JsonApiDoc(json).page(ActivityEntry.fromJson));
  }
}

final activitiesRepositoryProvider = Provider<ActivitiesRepository>(
  (ref) => ActivitiesRepository(ref.watch(apiClientProvider)),
);
