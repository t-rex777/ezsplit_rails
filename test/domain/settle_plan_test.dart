import 'dart:math';

import 'package:ezsplit_mobile/domain/settle_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Goa example settles in three transfers', () {
    const me = 1, riya = 2, arjun = 3, neha = 4;
    final plan = settlePlan({
      me: 185000,
      riya: 90000,
      arjun: -45000,
      neha: -230000,
    });
    expect(plan, [
      const Transfer(fromUserId: neha, toUserId: me, paise: 185000),
      const Transfer(fromUserId: neha, toUserId: riya, paise: 45000),
      const Transfer(fromUserId: arjun, toUserId: riya, paise: 45000),
    ]);
  });

  test('all zeros gives no transfers', () {
    expect(settlePlan({1: 0, 2: 0, 3: 0}), isEmpty);
    expect(settlePlan({}), isEmpty);
  });

  test('nets that do not sum to zero throw', () {
    expect(() => settlePlan({1: 100, 2: -50}), throwsArgumentError);
  });

  test('random inputs end at zero with at most n-1 transfers', () {
    final rng = Random(42);
    for (var c = 0; c < 200; c++) {
      final n = 2 + rng.nextInt(7);
      final nets = <int, int>{};
      var sum = 0;
      for (var i = 1; i < n; i++) {
        final v = rng.nextInt(200001) - 100000;
        nets[i] = v;
        sum += v;
      }
      nets[n] = -sum;

      final plan = settlePlan(nets);
      final after = Map<int, int>.of(nets);
      for (final t in plan) {
        expect(t.paise, greaterThan(0));
        after[t.fromUserId] = after[t.fromUserId]! + t.paise;
        after[t.toUserId] = after[t.toUserId]! - t.paise;
      }
      expect(after.values.every((v) => v == 0), isTrue, reason: 'case $c');
      expect(plan.length, lessThanOrEqualTo(n - 1), reason: 'case $c');
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i - 1].paise, greaterThanOrEqualTo(plan[i].paise));
      }
    }
  });
}
