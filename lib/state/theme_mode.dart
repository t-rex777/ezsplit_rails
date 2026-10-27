import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  /// Completes once the saved mode has been read.
  late final Future<void> loaded;

  @override
  ThemeMode build() {
    loaded = _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      final mode = ThemeMode.values.where((m) => m.name == saved);
      if (mode.isNotEmpty) state = mode.first;
    } catch (_) {
      // Storage is unavailable: stay on the system mode.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, mode.name);
    } catch (_) {
      // The choice still applies for this run.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
