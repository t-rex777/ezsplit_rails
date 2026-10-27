import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/groups_repository.dart';
import '../data/models.dart';
import '../data/users_repository.dart';

final groupsProvider = FutureProvider.autoDispose<List<Group>>(
  (ref) => ref.watch(groupsRepositoryProvider).list(),
);

final groupProvider = FutureProvider.autoDispose.family<Group, int>(
  (ref, id) => ref.watch(groupsRepositoryProvider).get(id),
);

final friendsProvider = FutureProvider.autoDispose<List<User>>(
  (ref) => ref.watch(usersRepositoryProvider).friends(),
);
