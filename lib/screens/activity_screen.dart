import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/tokens.dart';
import '../widgets/coming_soon.dart';

/// A stub: no data and no network calls until the feed exists.
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ComingSoon(
          title: 'Activity',
          body: "You'll see every add, edit, and settle-up across your groups here.",
          icon: Symbols.history,
          tile: context.ez.lilac,
        ),
      ),
    );
  }
}
