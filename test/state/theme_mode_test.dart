import 'package:ezsplit_mobile/state/theme_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads the saved mode', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(themeModeProvider), ThemeMode.system);
    await c.read(themeModeProvider.notifier).loaded;
    expect(c.read(themeModeProvider), ThemeMode.dark);
  });

  test('saves a new mode under theme_mode', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(themeModeProvider.notifier).set(ThemeMode.light);
    expect(c.read(themeModeProvider), ThemeMode.light);
    expect(
      (await SharedPreferences.getInstance()).getString('theme_mode'),
      'light',
    );
  });
}
