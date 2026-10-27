import 'package:ezsplit_mobile/domain/split.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splitEqual gives leftover paise to the first people', () {
    expect(splitEqual(10000, [1, 2, 3]), {1: 3334, 2: 3333, 3: 3333});
  });

  test('splitEqual divides evenly', () {
    final r = splitEqual(300000, [1, 2, 3, 4, 5]);
    expect(r.values, everyElement(60000));
    expect(r.length, 5);
  });

  test('splitByWeights floors then distributes leftover in list order', () {
    final r = splitByWeights(100, [
      const MapEntry(1, 1),
      const MapEntry(2, 1),
      const MapEntry(3, 1),
    ]);
    expect(r, {1: 34, 2: 33, 3: 33});
  });

  test('splitPercent handles uneven percents and sums to total', () {
    final r = splitPercent(10000, [
      const MapEntry(1, 33.33),
      const MapEntry(2, 33.33),
      const MapEntry(3, 33.34),
    ]);
    expect(r, {1: 3333, 2: 3333, 3: 3334});
    expect(r.values.reduce((a, b) => a + b), 10000);
  });

  test('splitPercent with whole percents', () {
    final r = splitPercent(300000, [
      const MapEntry(10, 40),
      const MapEntry(11, 30),
      const MapEntry(12, 20),
      const MapEntry(13, 10),
    ]);
    expect(r, {10: 120000, 11: 90000, 12: 60000, 13: 30000});
  });

  test('empty or zero-weight input returns zeros without throwing', () {
    expect(splitEqual(100, []), isEmpty);
    expect(splitByWeights(100, [const MapEntry(1, 0)]), {1: 0});
  });

  test('checkExact reports remaining and over', () {
    final c = checkExact(300000, {1: 100000, 2: 120000, 3: 50000});
    expect(c.ok, isFalse);
    expect(c.remaining, 30000);
    final over = checkExact(100, {1: 150});
    expect(over.ok, isFalse);
    expect(over.remaining, -50);
    expect(checkExact(100, {1: 40, 2: 60}).ok, isTrue);
  });

  test('checkPercent works in hundredths of a percent', () {
    expect(checkPercent([40, 30, 20, 10]).ok, isTrue);
    expect(checkPercent([33.33, 33.33, 33.34]).ok, isTrue);
    final c = checkPercent([50, 40]);
    expect(c.ok, isFalse);
    expect(c.remaining, 1000);
    expect(checkPercent([60, 50]).remaining, -1000);
  });

  test('a 12-digit total split by percent does not overflow', () {
    const total = 99999999999999; // ₹999,999,999,999.99
    final shares = splitPercent(total, [
      const MapEntry(1, 33.33),
      const MapEntry(2, 33.33),
      const MapEntry(3, 33.34),
    ]);
    expect(shares.values.fold<int>(0, (a, b) => a + b), total);
    expect(shares[1], 33330000000000);
    expect(shares[3], 33339999999999);
    // Whole hundredths as weights (what the form passes) give the same shares.
    final hundredths = splitPercent(total, [
      const MapEntry(1, 3333),
      const MapEntry(2, 3333),
      const MapEntry(3, 3334),
    ]);
    expect(hundredths, shares);
  });
}
