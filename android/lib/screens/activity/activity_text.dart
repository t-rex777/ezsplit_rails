import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../domain/money.dart';

/// "You" for the signed-in user, otherwise the first name.
String personName(String fullName, int userId, int? meId) =>
    userId == meId ? 'You' : fullName.split(' ').first;

String initialsOf(String fullName) => fullName
    .split(' ')
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w[0].toUpperCase())
    .join();

String verbFor(ActivityAction action) => switch (action) {
  ActivityAction.created => 'added',
  ActivityAction.updated => 'edited',
  ActivityAction.deleted => 'deleted',
  ActivityAction.settled => 'paid',
};

/// What the verb acts on: the expense name, or the person paid back.
String objectOf(ActivityEntry entry, int? meId) {
  final p = entry.payment;
  return p == null
      ? entry.current.name
      : personName(p.payeeName, p.payeeId, meId);
}

String dayLabel(DateTime at, DateTime now) {
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat(at.year == now.year ? 'MMM d' : 'MMM d, y').format(at);
}

String timeLabel(DateTime at) => DateFormat('h:mm a').format(at).toLowerCase();

/// Snapshot keys the "What changed" table shows, in display order.
const fieldLabels = {
  'name': 'Name',
  'amount': 'Amount',
  'payer': 'Paid by',
  'shares': 'Split',
  'split_type': 'Split type',
  'expense_date': 'Date',
  'category': 'Category',
  'group': 'Group',
  'notes': 'Notes',
};

/// Fields named in the "Unchanged: …" line when they did not change.
const _basicFields = {
  'name': 'name',
  'expense_date': 'date',
  'category': 'category',
  'notes': 'notes',
};

String? unchangedLine(List<String> changed) {
  final same = [
    for (final e in _basicFields.entries)
      if (!changed.contains(e.key)) e.value,
  ];
  return same.isEmpty ? null : 'Unchanged: ${same.join(', ')}.';
}

String splitTypeLabel(SplitType t) => switch (t) {
  SplitType.equal => 'Equally',
  SplitType.percentage => 'By percent',
  SplitType.exact => 'Exact amounts',
};

String shareLine(SnapshotShare s, int? meId) =>
    '${personName(s.name, s.userId, meId)} ${formatRupees(s.paise)}';

String fieldValue(String field, ExpenseSnapshot s, int? meId) =>
    switch (field) {
      'name' => s.name,
      'amount' => formatRupees(s.paise),
      'payer' => personName(s.payerName, s.payerId, meId),
      'shares' => s.shares.map((x) => shareLine(x, meId)).join('\n'),
      'split_type' => splitTypeLabel(s.splitType),
      'expense_date' => DateFormat('d MMM y').format(s.date),
      'category' => s.categoryName,
      'group' => s.groupName ?? 'No group',
      'notes' => (s.notes == null || s.notes!.isEmpty) ? '—' : s.notes!,
      _ => '',
    };
