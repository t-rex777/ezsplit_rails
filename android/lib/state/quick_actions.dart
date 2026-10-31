import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import 'session.dart';

/// A saved expense the user adds often, like rent. It lives on this device
/// only; the server has no field for it.
class QuickAction {
  const QuickAction({
    required this.id,
    required this.name,
    required this.paise,
    required this.groupId,
    required this.groupName,
    required this.categoryId,
    required this.categoryIcon,
    required this.payerId,
    required this.splitType,
    required this.included,
    this.percents = const {},
    this.exact = const {},
  });

  final String id;
  final String name;
  final int paise;

  /// Null is a personal expense.
  final int? groupId;

  /// Copied when saved so the dashboard needs no network call to draw a tile.
  final String groupName;
  final int categoryId;
  final String categoryIcon;
  final int payerId;
  final SplitType splitType;

  /// Ids in the split, in member order.
  final List<int> included;

  /// Hundredths of a percent, for a percentage split.
  final Map<int, int> percents;

  /// Paise per person, for an exact split.
  final Map<int, int> exact;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'paise': paise,
    'group_id': groupId,
    'group_name': groupName,
    'category_id': categoryId,
    'category_icon': categoryIcon,
    'payer_id': payerId,
    'split_type': splitType.api,
    'included': included,
    'percents': {for (final e in percents.entries) '${e.key}': e.value},
    'exact': {for (final e in exact.entries) '${e.key}': e.value},
  };

  factory QuickAction.fromJson(Map<String, dynamic> j) {
    Map<int, int> ints(Object? m) => {
      for (final e in ((m as Map?) ?? const {}).entries)
        int.parse(e.key as String): (e.value as num).toInt(),
    };
    return QuickAction(
      id: j['id'] as String,
      name: j['name'] as String,
      paise: (j['paise'] as num).toInt(),
      groupId: (j['group_id'] as num?)?.toInt(),
      groupName: j['group_name'] as String? ?? '',
      categoryId: (j['category_id'] as num).toInt(),
      categoryIcon: j['category_icon'] as String? ?? '',
      payerId: (j['payer_id'] as num).toInt(),
      splitType: SplitType.fromApi(j['split_type'] as String),
      included: [for (final id in j['included'] as List) (id as num).toInt()],
      percents: ints(j['percents']),
      exact: ints(j['exact']),
    );
  }
}

/// Each signed-in user gets their own list on a shared phone.
String quickActionsKey(int userId) => 'quick_actions_$userId';

class QuickActionsNotifier extends AsyncNotifier<List<QuickAction>> {
  int? _userId;

  @override
  Future<List<QuickAction>> build() async {
    _userId = ref.watch(sessionProvider.select((s) => s.value?.id));
    final userId = _userId;
    if (userId == null) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(quickActionsKey(userId));
      if (raw == null) return const [];
      return [
        for (final j in jsonDecode(raw) as List)
          QuickAction.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      // A broken or unreadable list should not break the dashboard.
      return const [];
    }
  }

  /// Adds [action], or replaces the one with the same id in place.
  Future<void> save(QuickAction action) async {
    final current = await future;
    final i = current.indexWhere((a) => a.id == action.id);
    await _write(
      i < 0
          ? [...current, action]
          : [...current.take(i), action, ...current.skip(i + 1)],
    );
  }

  Future<void> remove(String id) async {
    final current = await future;
    await _write([
      for (final a in current)
        if (a.id != id) a,
    ]);
  }

  Future<void> _write(List<QuickAction> list) async {
    state = AsyncData(list);
    final userId = _userId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        quickActionsKey(userId),
        jsonEncode([for (final a in list) a.toJson()]),
      );
    } catch (_) {
      // The change still applies for this run.
    }
  }
}

final quickActionsProvider =
    AsyncNotifierProvider<QuickActionsNotifier, List<QuickAction>>(
      QuickActionsNotifier.new,
    );
