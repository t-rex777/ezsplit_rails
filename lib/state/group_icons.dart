import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultGroupIcon = 'group';

/// Material Symbols names a group can use (all known to CategoryIcon).
const groupIconChoices = [
  'group',
  'flight',
  'home',
  'favorite',
  'work',
  'sports_soccer',
];

String _key(int groupId) => 'group_icon_$groupId';

/// The icon for a group, kept on this device only; the server has no field for it.
class GroupIconNotifier extends AsyncNotifier<String> {
  GroupIconNotifier(this.groupId);

  final int groupId;

  @override
  Future<String> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key(groupId)) ?? defaultGroupIcon;
    } catch (_) {
      return defaultGroupIcon;
    }
  }

  Future<void> set(String icon) async {
    // Let the first load finish so it cannot overwrite this choice.
    await future;
    state = AsyncData(icon);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(groupId), icon);
    } catch (_) {
      // The choice still applies for this run.
    }
  }
}

final groupIconProvider =
    AsyncNotifierProvider.family<GroupIconNotifier, String, int>(
      GroupIconNotifier.new,
    );
