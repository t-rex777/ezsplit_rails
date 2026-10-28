import 'dart:ui' as ui;

import 'package:ezsplit_mobile/theme/app_theme.dart';
import 'package:ezsplit_mobile/theme/tokens.dart';
import 'package:ezsplit_mobile/widgets/avatar.dart';
import 'package:ezsplit_mobile/widgets/brutal_button.dart';
import 'package:ezsplit_mobile/widgets/brutal_card.dart';
import 'package:ezsplit_mobile/widgets/brutal_input.dart';
import 'package:ezsplit_mobile/widgets/brutal_pill.dart';
import 'package:ezsplit_mobile/widgets/brutal_sheet.dart';
import 'package:ezsplit_mobile/widgets/category_icon.dart';
import 'package:ezsplit_mobile/widgets/coming_soon.dart';
import 'package:ezsplit_mobile/widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

Widget host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
  theme: buildTheme(b),
  home: Scaffold(body: Center(child: child)),
);

List<BoxShadow> shadowsOf(WidgetTester t, Finder inside) {
  final box = t.widget<AnimatedContainer>(
    find.descendant(of: inside, matching: find.byType(AnimatedContainer)),
  );
  return (box.decoration! as BoxDecoration).boxShadow ?? const [];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('BrutalButton', () {
    testWidgets('card-coloured button uses ink text in dark mode', (t) async {
      await t.pumpWidget(
        host(
          BrutalButton(
            label: 'Cancel',
            color: EzColors.dark.card,
            onPressed: () {},
          ),
          b: Brightness.dark,
        ),
      );
      expect(
        t.widget<Text>(find.text('Cancel')).style?.color,
        EzColors.dark.ink,
      );
    });

    testWidgets('disabled has no shadow and a grey fill', (t) async {
      await t.pumpWidget(host(const BrutalButton(label: 'Save')));
      final f = find.byType(BrutalButton);
      expect(shadowsOf(t, f), isEmpty);
      final deco =
          t
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: f,
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(deco.color, EzColors.disabled);
    });

    testWidgets('enabled has a (4,4) hard shadow, which collapses on press', (
      t,
    ) async {
      var taps = 0;
      await t.pumpWidget(
        host(BrutalButton(label: 'Save', onPressed: () => taps++)),
      );
      final f = find.byType(BrutalButton);
      final s = shadowsOf(t, f).single;
      expect(s.offset, const Offset(4, 4));
      expect(s.blurRadius, 0);

      final g = await t.startGesture(t.getCenter(f));
      await t.pump(const Duration(milliseconds: 200));
      expect(shadowsOf(t, f), isEmpty);
      final box = t.widget<AnimatedContainer>(
        find.descendant(of: f, matching: find.byType(AnimatedContainer)),
      );
      expect(box.transform!.getTranslation().x, 4);
      await g.up();
      await t.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
      expect(shadowsOf(t, f), hasLength(1));
    });

    testWidgets('is at least 44x44', (t) async {
      await t.pumpWidget(host(BrutalButton(label: 'Go', onPressed: () {})));
      final size = t.getSize(find.byType(BrutalButton));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
    });
  });

  testWidgets('BrutalPill is at least 44px tall, selected or not', (t) async {
    await t.pumpWidget(
      host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrutalPill(label: 'A', onTap: () {}),
            BrutalPill(label: 'Food', selected: true, onTap: () {}),
          ],
        ),
      ),
    );
    for (final e in t.widgetList(find.byType(BrutalPill)).indexed) {
      final size = t.getSize(find.byType(BrutalPill).at(e.$1));
      expect(size.height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('BrutalCard only moves when tappable', (t) async {
    await t.pumpWidget(host(const BrutalCard(child: Text('x'))));
    final s = shadowsOf(t, find.byType(BrutalCard)).single;
    expect(s.offset, const Offset(4, 4));
    var taps = 0;
    await t.pumpWidget(
      host(BrutalCard(onTap: () => taps++, child: const Text('x'))),
    );
    await t.tap(find.byType(BrutalCard));
    expect(taps, 1);
  });

  group('CategoryIcon', () {
    testWidgets('unknown names fall back to more_horiz', (t) async {
      await t.pumpWidget(host(const CategoryIcon('not_a_symbol', Colors.red)));
      expect(t.widget<Icon>(find.byType(Icon)).icon, Symbols.more_horiz);
    });

    testWidgets('known names map to their symbol', (t) async {
      await t.pumpWidget(
        host(const CategoryIcon('restaurant', Colors.red, size: 30)),
      );
      final icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Symbols.restaurant);
      expect(icon.size, 30);
    });
  });

  group('MoneyText', () {
    Future<void> show(
      WidgetTester t,
      int paise,
      MoneyStyle s, {
      Brightness b = Brightness.light,
    }) => t.pumpWidget(host(MoneyText(paise, style: s), b: b));

    testWidgets('plain', (t) async {
      await show(t, 10000000, MoneyStyle.plain);
      expect(find.text('₹1,00,000'), findsOneWidget);
    });

    testWidgets('signed uses + and a true minus, with colours', (t) async {
      await show(t, 60000, MoneyStyle.signed);
      expect(find.text('+₹600'), findsOneWidget);
      expect(
        t.widget<Text>(find.text('+₹600')).style!.color,
        EzColors.light.positive,
      );
      await show(t, -18000, MoneyStyle.signed);
      expect(find.text('−₹180'), findsOneWidget);
      expect(
        t.widget<Text>(find.text('−₹180')).style!.color,
        EzColors.light.negative,
      );
    });

    testWidgets('owesGets uses words', (t) async {
      await show(t, 90000, MoneyStyle.owesGets);
      expect(find.text('gets ₹900'), findsOneWidget);
      await show(t, -45000, MoneyStyle.owesGets);
      expect(find.text('owes ₹450'), findsOneWidget);
    });

    testWidgets('uses dark colours in dark mode', (t) async {
      await show(t, 60000, MoneyStyle.signed, b: Brightness.dark);
      expect(
        t.widget<Text>(find.text('+₹600')).style!.color,
        EzColors.dark.positive,
      );
    });
  });

  testWidgets('BrutalInput shows label and error text', (t) async {
    await t.pumpWidget(
      host(const BrutalInput(label: 'Amount', errorText: 'Enter an amount')),
    );
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Enter an amount'), findsOneWidget);
  });

  testWidgets('showBrutalSheet shows title and uses a 60% ink scrim', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showBrutalSheet<void>(
              ctx,
              title: 'Add expense',
              child: const Text('body'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    final barrier = t.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, EzColors.light.ink.withValues(alpha: 0.6));
  });

  testWidgets('Avatar and ComingSoon render', (t) async {
    await t.pumpWidget(
      host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar('MS', Colors.orange),
            ComingSoon(
              title: 'Activity',
              body: 'Your feed will live here.',
              icon: Icons.bolt,
              tile: Colors.amber,
            ),
          ],
        ),
      ),
    );
    expect(find.text('MS'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('selected pill defaults to ink fill and bg text ($b)', (
      t,
    ) async {
      await t.pumpWidget(
        host(const BrutalPill(label: 'Food', selected: true), b: b),
      );
      final c = b == Brightness.light ? EzColors.light : EzColors.dark;
      final deco =
          t
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;
      expect(deco.color, c.ink);
      expect(t.widget<Text>(find.text('Food')).style!.color, c.bg);
    });
  }

  testWidgets('disabled BrutalButton keeps button role, not enabled', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(host(const BrutalButton(label: 'Save')));
    final node = t.getSemantics(find.byType(BrutalButton));
    final data = node.getSemanticsData();
    expect(data.label, 'Save');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('enabled labelled BrutalButton is tappable via semantics', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    var taps = 0;
    await t.pumpWidget(
      host(BrutalButton(label: 'Save', onPressed: () => taps++)),
    );
    final data = t.getSemantics(find.byType(BrutalButton)).getSemanticsData();
    expect(data.label, 'Save');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    t.semantics.tap(find.semantics.byLabel('Save'));
    await t.pump();
    expect(taps, 1);
    handle.dispose();
  });
}
