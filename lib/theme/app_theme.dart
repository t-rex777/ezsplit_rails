import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.light ? EzColors.light : EzColors.dark;
  final base = ThemeData(brightness: b);
  final textTheme = _spaceGrotesk(
    base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink),
  );
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: c.amber, brightness: b)
        .copyWith(
          surface: c.bg,
          onSurface: c.ink,
          primary: c.ink,
          onPrimary: c.bg,
          error: c.negative,
          outline: c.line,
        ),
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    extensions: [c],
  );
}

// google_fonts 9 returns a TextTheme from the material_ui package, which is a
// different type from the SDK's, so apply the font slot by slot instead.
TextTheme _spaceGrotesk(TextTheme t) {
  TextStyle? f(TextStyle? s) =>
      s == null ? null : GoogleFonts.spaceGrotesk(textStyle: s);
  return t.copyWith(
    displayLarge: f(t.displayLarge),
    displayMedium: f(t.displayMedium),
    displaySmall: f(t.displaySmall),
    headlineLarge: f(t.headlineLarge),
    headlineMedium: f(t.headlineMedium),
    headlineSmall: f(t.headlineSmall),
    titleLarge: f(t.titleLarge),
    titleMedium: f(t.titleMedium),
    titleSmall: f(t.titleSmall),
    bodyLarge: f(t.bodyLarge),
    bodyMedium: f(t.bodyMedium),
    bodySmall: f(t.bodySmall),
    labelLarge: f(t.labelLarge),
    labelMedium: f(t.labelMedium),
    labelSmall: f(t.labelSmall),
  );
}
