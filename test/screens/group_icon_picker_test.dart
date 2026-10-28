import 'package:ezsplit_mobile/screens/groups/group_widgets.dart';
import 'package:ezsplit_mobile/theme/app_theme.dart';
import 'package:ezsplit_mobile/widgets/brutal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('icon tiles are 52x52 and share rows on a phone', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: GroupIconPicker(selected: 'group', onChanged: (_) {}),
        ),
      ),
    );
    final tiles = find.byType(BrutalSurface);
    expect(t.getSize(tiles.first), const Size(52, 52));
    expect(t.getTopLeft(tiles.at(0)).dy, t.getTopLeft(tiles.at(1)).dy);
  });
}
