class Transfer {
  const Transfer({
    required this.fromUserId,
    required this.toUserId,
    required this.paise,
  });

  final int fromUserId;
  final int toUserId;
  final int paise;

  @override
  bool operator ==(Object other) =>
      other is Transfer &&
      other.fromUserId == fromUserId &&
      other.toUserId == toUserId &&
      other.paise == paise;

  @override
  int get hashCode => Object.hash(fromUserId, toUserId, paise);

  @override
  String toString() => 'Transfer($fromUserId -> $toUserId, $paise)';
}

/// Plans who pays whom; a positive net means owed. Throws [ArgumentError] if the nets do not sum to 0.
List<Transfer> settlePlan(Map<int, int> netPaise) {
  if (netPaise.values.fold<int>(0, (a, b) => a + b) != 0) {
    throw ArgumentError('Nets must sum to 0');
  }
  final creditors = <int, int>{};
  final debtors = <int, int>{};
  netPaise.forEach((id, net) {
    if (net > 0) creditors[id] = net;
    if (net < 0) debtors[id] = -net;
  });

  // Largest amount first; lower user id wins ties.
  int? largest(Map<int, int> m) {
    int? best;
    for (final e in m.entries) {
      if (best == null ||
          e.value > m[best]! ||
          (e.value == m[best] && e.key < best)) {
        best = e.key;
      }
    }
    return best;
  }

  final plan = <Transfer>[];
  while (creditors.isNotEmpty && debtors.isNotEmpty) {
    final d = largest(debtors)!;
    final c = largest(creditors)!;
    final amount = debtors[d]! < creditors[c]! ? debtors[d]! : creditors[c]!;
    plan.add(Transfer(fromUserId: d, toUserId: c, paise: amount));
    if (debtors[d] == amount) {
      debtors.remove(d);
    } else {
      debtors[d] = debtors[d]! - amount;
    }
    if (creditors[c] == amount) {
      creditors.remove(c);
    } else {
      creditors[c] = creditors[c]! - amount;
    }
  }

  // Amount high to low; on equal amounts the higher payer id comes first.
  plan.sort((a, b) {
    final byAmount = b.paise.compareTo(a.paise);
    return byAmount != 0 ? byAmount : b.fromUserId.compareTo(a.fromUserId);
  });
  return plan;
}
