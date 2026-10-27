import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:ezsplit_mobile/data/api_error.dart';
import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/data/summary_repository.dart';
import 'package:ezsplit_mobile/screens/home/dashboard_screen.dart';
import 'package:ezsplit_mobile/state/summary.dart';
import 'package:ezsplit_mobile/theme/app_theme.dart';
import 'package:ezsplit_mobile/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

MonthlySummary october() => const MonthlySummary(
  month: '2026-10',
  mySharePaise: 1240000,
  youOwePaise: 80000,
  owedToYouPaise: 245000,
  categories: [
    CategorySpend(
      name: 'Food',
      icon: 'restaurant',
      color: '#EF9F27',
      paise: 496000,
    ),
    CategorySpend(
      name: 'Travel',
      icon: 'flight',
      color: '#AFA9EC',
      paise: 248000,
    ),
    CategorySpend(name: 'Rent', icon: 'home', color: '#5DCAA5', paise: 124000),
  ],
  otherCurrencies: [],
);

Future<void> pumpDashboard(
  WidgetTester tester,
  FakeSummaryRepository repo, {
  Brightness brightness = Brightness.light,
  DateTime? now,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overridesFor(FakeAuthRepository(current: testUser)),
        summaryRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(now ?? DateTime(2026, 10, 15)),
      ],
      child: MaterialApp(
        theme: buildTheme(brightness),
        home: const DashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double barFraction(WidgetTester tester, String name) => tester
    .widget<FractionallySizedBox>(find.byKey(ValueKey('bar-$name')))
    .widthFactor!;

Color barColor(WidgetTester tester, String name) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(ValueKey('bar-$name')),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  group('Dashboard', () {
    testWidgets('shows the month, share and a full-width Food bar', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        FakeSummaryRepository(byMonth: {'2026-10': october()}),
      );
      expect(find.text('Hey Neha'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('₹12,400'), findsOneWidget);
      expect(find.text('Your share this month'), findsOneWidget);
      expect(find.text('You owe'), findsOneWidget);
      expect(find.text('₹800'), findsOneWidget);
      expect(find.text('Owed to you'), findsOneWidget);
      expect(find.text('₹2,450'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('₹4,960'), findsOneWidget);
      expect(barFraction(tester, 'Food'), 1.0);
      expect(barFraction(tester, 'Travel'), closeTo(0.5, 0.001));
      expect(barFraction(tester, 'Rent'), closeTo(0.25, 0.001));
    });

    testWidgets('light bars use the category colour, bad hex falls back', (
      tester,
    ) async {
      final s = october();
      await pumpDashboard(
        tester,
        FakeSummaryRepository(
          byMonth: {
            '2026-10': MonthlySummary(
              month: s.month,
              mySharePaise: s.mySharePaise,
              youOwePaise: s.youOwePaise,
              owedToYouPaise: s.owedToYouPaise,
              categories: const [
                CategorySpend(
                  name: 'Food',
                  icon: 'restaurant',
                  color: '#AFA9EC',
                  paise: 1000,
                ),
                CategorySpend(
                  name: 'Odd',
                  icon: 'nope',
                  color: 'not-a-colour',
                  paise: 500,
                ),
              ],
              otherCurrencies: const [],
            ),
          },
        ),
      );
      expect(barColor(tester, 'Food'), const Color(0xFFAFA9EC));
      expect(barColor(tester, 'Odd'), EzColors.light.amber);
    });

    testWidgets('dark bars cycle through the dark accent fills', (
      tester,
    ) async {
      final s = october();
      final four = [
        for (var i = 0; i < 5; i++)
          CategorySpend(
            name: 'C$i',
            icon: 'home',
            color: '#FFFFFF',
            paise: 5000 - i * 100,
          ),
      ];
      await pumpDashboard(
        tester,
        FakeSummaryRepository(
          byMonth: {
            '2026-10': MonthlySummary(
              month: s.month,
              mySharePaise: 1,
              youOwePaise: 0,
              owedToYouPaise: 0,
              categories: four,
              otherCurrencies: const [],
            ),
          },
        ),
        brightness: Brightness.dark,
      );
      final d = EzColors.dark;
      final expected = [d.green, d.peach, d.mint, d.lilac, d.green];
      for (var i = 0; i < 5; i++) {
        expect(barColor(tester, 'C$i'), expected[i]);
      }
    });

    testWidgets('a tiny amount still gets a visible bar', (tester) async {
      final s = october();
      await pumpDashboard(
        tester,
        FakeSummaryRepository(
          byMonth: {
            '2026-10': MonthlySummary(
              month: s.month,
              mySharePaise: 1,
              youOwePaise: 0,
              owedToYouPaise: 0,
              categories: const [
                CategorySpend(
                  name: 'Big',
                  icon: 'home',
                  color: '#EF9F27',
                  paise: 10000000,
                ),
                CategorySpend(
                  name: 'Tiny',
                  icon: 'home',
                  color: '#EF9F27',
                  paise: 1,
                ),
              ],
              otherCurrencies: const [],
            ),
          },
        ),
      );
      expect(barFraction(tester, 'Tiny'), greaterThanOrEqualTo(0.03));
    });

    testWidgets('next arrow is disabled on the current month', (tester) async {
      final repo = FakeSummaryRepository();
      await pumpDashboard(tester, repo);
      final next = tester.getSemantics(find.bySemanticsLabel('Next month'));
      expect(next.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      final prev = tester.getSemantics(find.bySemanticsLabel('Previous month'));
      expect(prev.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(repo.requested, ['2026-10']);
    });

    testWidgets('arrows have 44 point tap targets', (tester) async {
      await pumpDashboard(tester, FakeSummaryRepository());
      for (final label in ['Previous month', 'Next month']) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('previous then next moves between months', (tester) async {
      final repo = FakeSummaryRepository(byMonth: {'2026-10': october()});
      await pumpDashboard(tester, repo);
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('No expenses in September'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('₹12,400'), findsOneWidget);
    });

    testWidgets('an empty month says so', (tester) async {
      await pumpDashboard(tester, FakeSummaryRepository());
      expect(find.text('No expenses in October'), findsOneWidget);
    });

    testWidgets('other currencies show with a code and symbol', (tester) async {
      final s = october();
      await pumpDashboard(
        tester,
        FakeSummaryRepository(
          byMonth: {
            '2026-10': MonthlySummary(
              month: s.month,
              mySharePaise: s.mySharePaise,
              youOwePaise: 0,
              owedToYouPaise: 0,
              categories: s.categories,
              otherCurrencies: const [
                OtherCurrencyTotals(
                  currency: 'USD',
                  youOwePaise: 1200,
                  owedToYouPaise: 0,
                ),
                OtherCurrencyTotals(
                  currency: 'CHF',
                  youOwePaise: 0,
                  owedToYouPaise: 123456,
                ),
              ],
            ),
          },
        ),
      );
      expect(find.text('Other currencies'), findsOneWidget);
      expect(find.text('USD: you owe \$12'), findsOneWidget);
      expect(find.text('CHF: owed to you CHF 1,234.56'), findsOneWidget);
    });

    testWidgets('no other currencies means no line', (tester) async {
      await pumpDashboard(
        tester,
        FakeSummaryRepository(byMonth: {'2026-10': october()}),
      );
      expect(find.text('Other currencies'), findsNothing);
    });

    testWidgets('previous data stays while the next month loads', (
      tester,
    ) async {
      final repo = FakeSummaryRepository(byMonth: {'2026-10': october()});
      await pumpDashboard(tester, repo);
      repo.gate = Completer<void>();
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pump();
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('₹12,400'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('₹12,400'), findsNothing);
      expect(find.text('No expenses in September'), findsOneWidget);
    });

    testWidgets('an error shows a retry that reloads', (tester) async {
      final repo = FakeSummaryRepository(byMonth: {'2026-10': october()})
        ..error = const ApiError(status: 500, message: 'Server is down.');
      await pumpDashboard(tester, repo);
      expect(find.text('Server is down.'), findsOneWidget);
      repo.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('₹12,400'), findsOneWidget);
    });

    testWidgets('pull to refresh loads again', (tester) async {
      final repo = FakeSummaryRepository(byMonth: {'2026-10': october()});
      await pumpDashboard(tester, repo);
      await tester.fling(find.text('Hey Neha'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(repo.requested.length, 2);
    });

    testWidgets('previous and next cross the year boundary', (tester) async {
      await pumpDashboard(
        tester,
        FakeSummaryRepository(),
        now: DateTime(2027, 1, 20),
      );
      expect(find.text('January 2027'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('December 2026'), findsOneWidget);
      expect(find.text('No expenses in December'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('January 2027'), findsOneWidget);
    });

    testWidgets('previous from January goes to December of last year', (
      tester,
    ) async {
      final repo = FakeSummaryRepository();
      await pumpDashboard(tester, repo, now: DateTime(2026, 1, 5));
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('December 2025'), findsOneWidget);
      expect(repo.requested, ['2026-01', '2025-12']);
    });

    testWidgets(
      'an older response arriving late does not replace a newer one',
      (tester) async {
        MonthlySummary share(String month, int paise) => MonthlySummary(
          month: month,
          mySharePaise: paise,
          youOwePaise: 0,
          owedToYouPaise: 0,
          categories: const [],
          otherCurrencies: const [],
        );
        final repo = FakeSummaryRepository(
          byMonth: {
            '2026-10': october(),
            '2026-09': share('2026-09', 222200),
            '2026-08': share('2026-08', 111100),
          },
        );
        await pumpDashboard(tester, repo);
        repo.gates['2026-09'] = Completer<void>();
        repo.gates['2026-08'] = Completer<void>();
        await tester.tap(find.bySemanticsLabel('Previous month'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Previous month'));
        await tester.pump();
        expect(find.text('August 2026'), findsOneWidget);

        repo.gates['2026-08']!.complete();
        await tester.pumpAndSettle();
        expect(find.text('₹1,111'), findsOneWidget);
        // September answers last, after the user already moved on.
        repo.gates['2026-09']!.complete();
        await tester.pumpAndSettle();
        expect(find.text('August 2026'), findsOneWidget);
        expect(find.text('₹1,111'), findsOneWidget);
        expect(find.text('₹2,222'), findsNothing);
      },
    );

    testWidgets('huge amounts and long names fit at 390 wide', (tester) async {
      final longName = List.filled(80, 'W').join();
      await pumpDashboard(
        tester,
        FakeSummaryRepository(
          byMonth: {
            '2026-10': MonthlySummary(
              month: '2026-10',
              mySharePaise: 9999999999999,
              youOwePaise: 9999999999999,
              owedToYouPaise: 9999999999999,
              categories: [
                CategorySpend(
                  name: longName,
                  icon: 'home',
                  color: '#EF9F27',
                  paise: 9999999999999,
                ),
                const CategorySpend(
                  name: 'Food',
                  icon: 'restaurant',
                  color: '#EF9F27',
                  paise: 5000,
                ),
              ],
              otherCurrencies: const [],
            ),
          },
        ),
      );
      expect(tester.takeException(), isNull);
      // The full amount is in the tree, scaled rather than cut.
      expect(find.text('₹99,99,99,99,999.99'), findsNWidgets(4));
      expect(find.text('₹50'), findsOneWidget);
    });

    testWidgets('dark mode keeps accent fills and readable text', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        FakeSummaryRepository(byMonth: {'2026-10': october()}),
        brightness: Brightness.dark,
      );
      final d = EzColors.dark;
      expect(barColor(tester, 'Food'), d.green);
      expect(barColor(tester, 'Travel'), d.peach);
      expect(barColor(tester, 'Rent'), d.mint);

      double contrast(Color a, Color b) {
        final l1 = a.computeLuminance(), l2 = b.computeLuminance();
        final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
        return (hi + 0.05) / (lo + 0.05);
      }

      Color colorOf(String t) =>
          tester.widget<Text>(find.text(t)).style!.color!;
      // Text on the dark card.
      expect(contrast(colorOf('Food'), d.card), greaterThanOrEqualTo(4.5));
      expect(contrast(colorOf('₹4,960'), d.card), greaterThanOrEqualTo(4.5));
      // Text on the coloured fills.
      expect(contrast(colorOf('₹12,400'), d.green), greaterThanOrEqualTo(4.5));
      expect(contrast(colorOf('₹800'), d.peach), greaterThanOrEqualTo(4.5));
      expect(contrast(colorOf('₹2,450'), d.mint), greaterThanOrEqualTo(4.5));
    });

    testWidgets('a failed refresh keeps the last data with an inline retry', (
      tester,
    ) async {
      final repo = FakeSummaryRepository(byMonth: {'2026-10': october()});
      await pumpDashboard(tester, repo);
      repo.error = const ApiError(status: 500, message: 'Server is down.');
      await tester.fling(find.text('Hey Neha'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Server is down.'), findsOneWidget);
      expect(find.text('₹12,400'), findsOneWidget);
      repo.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Server is down.'), findsNothing);
      expect(find.text('₹12,400'), findsOneWidget);
    });

    testWidgets('the first load shows a progress indicator', (tester) async {
      final repo = FakeSummaryRepository()..gate = Completer<void>();
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overridesFor(FakeAuthRepository(current: testUser)),
            summaryRepositoryProvider.overrideWithValue(repo),
            nowProvider.overrideWithValue(DateTime(2026, 10, 15)),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Previous month'), findsOneWidget);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the recorded summary parses and renders', (tester) async {
      final json = jsonDecode(
        File('test/fixtures/summary.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      await pumpDashboard(
        tester,
        FakeSummaryRepository(
          byMonth: {'2026-10': MonthlySummary.fromJson(json)},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('₹3,500'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      expect(barFraction(tester, 'Stay'), 1.0);
    });
  });
}
