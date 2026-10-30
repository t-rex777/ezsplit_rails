import 'package:ezsplit_mobile/data/models.dart';
import 'package:ezsplit_mobile/domain/analytics.dart';
import 'package:ezsplit_mobile/screens/analytics/charts.dart';
import 'package:flutter_test/flutter_test.dart';

CategorySpend cat(String name, int paise) => CategorySpend(
  name: name,
  icon: 'restaurant',
  color: '#EF9F27',
  paise: paise,
);

AnalyticsMonth month(int m, List<CategorySpend> cats) => AnalyticsMonth(
  month: DateTime(2026, m),
  totalPaise: cats.fold(0, (s, c) => s + c.paise),
  categories: cats,
);

void main() {
  test('rankedCategories sums across months, merges case, biggest first', () {
    final ranked = rankedCategories([
      month(9, [cat('Food', 100), cat('Travel', 500)]),
      month(10, [cat('food', 700), cat('Rent', 200)]),
    ]);
    expect(
      [for (final c in ranked) (c.name, c.paise)],
      [('Food', 800), ('Travel', 500), ('Rent', 200)],
    );
  });

  test('withoutCategories drops hidden ones and recounts totals', () {
    final out = withoutCategories(
      [
        month(10, [cat('Food', 700), cat('Rent', 200)]),
      ],
      {'food'},
    );
    expect(out.single.totalPaise, 200);
    expect(out.single.categories.map((c) => c.name), ['Rent']);
  });

  test('foldSmall folds categories under 5% into Other', () {
    final split = foldSmall(
      [cat('Food', 9000), cat('A', 300), cat('B', 200), cat('Rent', 500)],
      keep: {'food', 'a', 'b', 'rent'},
    );
    expect(split.big.map((c) => c.name), ['Food', 'Rent']);
    expect(split.otherPaise, 500);
    expect(split.otherCount, 2);
  });

  test(
    'foldSmall puts categories without a colour into Other, however big',
    () {
      final split = foldSmall(
        [cat('Food', 5000), cat('Rent', 4000), cat('Tea', 1000)],
        keep: {'food'},
      );
      expect(split.big.map((c) => c.name), ['Food']);
      expect(split.otherPaise, 5000);
      expect(split.otherCount, 2);
    },
  );

  test('foldSmall keeps a lone small category under its own name', () {
    final split = foldSmall(
      [cat('Food', 9700), cat('Tea', 300)],
      keep: {'food', 'tea'},
    );
    expect(split.big.map((c) => c.name), ['Food', 'Tea']);
    expect(split.otherCount, 0);
  });

  test('changePercent compares with the month before', () {
    final months = [
      month(8, [cat('Food', 0)]),
      month(9, [cat('Food', 1000)]),
      month(10, [cat('Food', 1250)]),
    ];
    expect(changePercent(months, 2), 25);
    expect(changePercent(months, 1), isNull);
    expect(changePercent(months, 0), isNull);
  });

  test('averagePaise uses at most the last 12 months', () {
    final months = [
      for (var i = 1; i <= 13; i++)
        month(i, [cat('Food', i == 1 ? 99900 : 1200)]),
    ];
    expect(averagePaise(months), 1200);
    expect(averagePaise(const []), 0);
  });

  test('highestMonth picks the biggest, latest on a tie', () {
    final months = [
      month(8, [cat('Food', 500)]),
      month(9, [cat('Food', 900)]),
      month(10, [cat('Food', 900)]),
    ];
    expect(highestMonth(months)!.month, DateTime(2026, 10));
  });

  test('niceTopPaise rounds up to three even steps', () {
    expect(niceTopPaise(1420000), 1500000);
    expect(niceTopPaise(100), 300);
    expect(niceTopPaise(0), 300000);
  });

  test('compactRupees', () {
    expect(compactRupees(500000), '5k');
    expect(compactRupees(150000), '1.5k');
    expect(compactRupees(15000000), '1.5L');
    expect(compactRupees(80000), '800');
  });

  test('AnalyticsMonth and AnalyticsExpense parse server JSON', () {
    final m = AnalyticsMonth.fromJson({
      'month': '2026-10',
      'total': '3500.0',
      'other_currency_count': 2,
      'categories': [
        {
          'name': 'Food',
          'icon': 'restaurant',
          'color': '#EF9F27',
          'amount': '500.0',
        },
      ],
    });
    expect(m.month, DateTime(2026, 10));
    expect(m.totalPaise, 350000);
    expect(m.otherCurrencyCount, 2);
    expect(m.categories.single.paise, 50000);

    final e = AnalyticsExpense.fromJson({
      'id': 4,
      'name': 'Dinner',
      'expense_date': '2026-10-03',
      'group_name': null,
      'my_share': '1000.5',
    });
    expect(e.date, DateTime(2026, 10, 3));
    expect(e.mySharePaise, 100050);
    expect(e.groupName, isNull);
  });
}
