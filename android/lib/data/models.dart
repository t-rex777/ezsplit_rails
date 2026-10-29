import '../domain/money.dart';
import '../domain/split.dart';
import 'jsonapi.dart';

class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.dob,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final DateTime? dob;

  String get initials {
    final f = firstName.isEmpty ? '' : firstName[0];
    final l = lastName.isEmpty ? '' : lastName[0];
    return (f + l).toUpperCase();
  }

  /// Reads a JSON:API user resource: {"id": "2", "type": "user", "attributes": {...}}.
  factory User.fromJson(Map<String, dynamic> resource) {
    final a = resource['attributes'] as Map<String, dynamic>;
    final dob = a['date_of_birth'] as String?;
    return User(
      id: (a['id'] as num?)?.toInt() ?? int.parse(resource['id'] as String),
      firstName: a['first_name'] as String? ?? '',
      lastName: a['last_name'] as String? ?? '',
      email: a['email_address'] as String? ?? '',
      phone: a['phone'] as String?,
      dob: dob == null ? null : DateTime.parse(dob),
    );
  }
}

/// A pending friend invite sent to the signed-in user.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;

  /// Reads `{"id": 1, "inviter": {"first_name": ..., "email_address": ...}}`.
  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final inviter = json['inviter'] as Map<String, dynamic>;
    return FriendRequest(
      id: (json['id'] as num).toInt(),
      firstName: inviter['first_name'] as String? ?? '',
      lastName: inviter['last_name'] as String? ?? '',
      email: inviter['email_address'] as String? ?? '',
    );
  }

  String get name {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? email : full;
  }
}

/// A one-use invite with no email, shown as a QR code.
class QrInvite {
  const QrInvite({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;

  /// Reads `{"url": "https://<host>/register?token=...", "expires_at": "..."}`.
  factory QrInvite.fromJson(Map<String, dynamic> json) => QrInvite(
    url: json['url'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
    required this.myNetPaise,
    this.description,
    this.lastActivityAt,
  });

  final int id;
  final String name;
  final String? description;
  final int ownerId;
  final List<User> members;

  /// What the group owes me (positive) or I owe it (negative), from `my_net`.
  final int myNetPaise;
  final DateTime? lastActivityAt;

  factory Group.fromJson(Map<String, dynamic> resource, JsonApiIndex included) {
    final a = resource['attributes'] as Map<String, dynamic>;
    final last = a['last_activity_at'] as String?;
    return Group(
      id: int.parse(resource['id'] as String),
      name: a['name'] as String,
      description: a['description'] as String?,
      ownerId: (a['owner_id'] as num).toInt(),
      members: [
        for (final u in included.many(resource, 'users')) User.fromJson(u),
      ],
      myNetPaise: paiseOf(a['my_net']),
      lastActivityAt: last == null ? null : DateTime.parse(last),
    );
  }
}

/// A row of a group's membership list. Group payloads carry no membership ids.
class Membership {
  const Membership({
    required this.id,
    required this.userId,
    required this.active,
  });

  final int id;
  final int userId;
  final bool active;

  factory Membership.fromJson(Map<String, dynamic> resource) {
    final a = resource['attributes'] as Map<String, dynamic>;
    return Membership(
      id: int.parse(resource['id'] as String),
      userId: (a['user_id'] as num).toInt(),
      active: a['active'] as bool? ?? a['left_at'] == null,
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final int id;
  final String name;
  final String icon;
  final String color;

  factory Category.fromJson(Map<String, dynamic> resource) {
    final a = resource['attributes'] as Map<String, dynamic>;
    return Category(
      id: int.parse(resource['id'] as String),
      name: a['name'] as String,
      icon: a['icon'] as String,
      color: a['color'] as String,
    );
  }
}

class Share {
  const Share({required this.userId, required this.paise});

  final int userId;
  final int paise;

  factory Share.fromJson(Map<String, dynamic> resource) {
    final a = resource['attributes'] as Map<String, dynamic>;
    return Share(
      userId: (a['user_id'] as num).toInt(),
      paise: paiseOf(a['amount']),
    );
  }
}

enum SplitType {
  equal('equal'),
  percentage('percentage'),
  exact('exact');

  const SplitType(this.api);

  /// The string the server uses.
  final String api;

  static SplitType fromApi(String value) => SplitType.values.firstWhere(
    (t) => t.api == value,
    orElse: () => throw FormatException('Unknown split type: $value'),
  );
}

class Expense {
  const Expense({
    required this.id,
    required this.name,
    required this.paise,
    required this.currency,
    required this.splitType,
    required this.date,
    required this.payer,
    required this.category,
    required this.shares,
    required this.creatorId,
    required this.myAmountPaise,
    this.notes,
    this.groupId,
  });

  final int id;
  final String name;
  final int paise;
  final String currency;
  final SplitType splitType;
  final DateTime date;
  final String? notes;
  final User payer;
  final int? groupId;
  final Category category;
  final List<Share> shares;
  final int creatorId;

  /// From `current_user_amount`: positive when I am owed, negative when I owe.
  final int myAmountPaise;

  factory Expense.fromJson(
    Map<String, dynamic> resource,
    JsonApiIndex included,
  ) {
    final a = resource['attributes'] as Map<String, dynamic>;
    final payer = included.one(resource, 'payer');
    final category = included.one(resource, 'category');
    if (payer == null || category == null) {
      throw const FormatException('Expense needs its payer and category');
    }
    final groupRef = (resource['relationships'] as Map)['group'] as Map?;
    final group = groupRef?['data'] as Map?;
    return Expense(
      id: int.parse(resource['id'] as String),
      name: a['name'] as String,
      paise: paiseOf(a['amount']),
      currency: a['currency'] as String,
      splitType: SplitType.fromApi(a['split_type'] as String),
      date: DateTime.parse(a['expense_date'] as String),
      notes: a['notes'] as String?,
      payer: User.fromJson(payer),
      groupId: group == null ? null : int.parse(group['id'] as String),
      category: Category.fromJson(category),
      shares: [
        for (final s in included.many(resource, 'expenses_users'))
          Share.fromJson(s),
      ],
      creatorId: (a['creator_id'] as num).toInt(),
      myAmountPaise: paiseOf(a['current_user_amount']),
    );
  }
}

class BalanceRow {
  const BalanceRow({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.currency,
    required this.paise,
  });

  final int userId;
  final String firstName;
  final String lastName;
  final String currency;
  final int paise;

  factory BalanceRow.fromJson(Map<String, dynamic> row) => BalanceRow(
    userId: (row['user_id'] as num).toInt(),
    firstName: row['first_name'] as String? ?? '',
    lastName: row['last_name'] as String? ?? '',
    currency: row['currency'] as String,
    paise: paiseOf(row['amount']),
  );
}

class Settlement {
  const Settlement({
    required this.id,
    required this.payerId,
    required this.payeeId,
    required this.paise,
    required this.settledOn,
    this.groupId,
  });

  final int id;
  final int payerId;
  final int payeeId;
  final int paise;
  final int? groupId;
  final DateTime settledOn;

  factory Settlement.fromJson(Map<String, dynamic> resource) {
    final a = resource['attributes'] as Map<String, dynamic>;
    return Settlement(
      id: int.parse(resource['id'] as String),
      payerId: (a['payer_id'] as num).toInt(),
      payeeId: (a['payee_id'] as num).toInt(),
      paise: paiseOf(a['amount']),
      groupId: (a['group_id'] as num?)?.toInt(),
      settledOn: DateTime.parse(a['settled_on'] as String),
    );
  }
}

class CategorySpend {
  const CategorySpend({
    required this.name,
    required this.icon,
    required this.color,
    required this.paise,
  });

  final String name;
  final String icon;
  final String color;
  final int paise;

  factory CategorySpend.fromJson(Map<String, dynamic> row) => CategorySpend(
    name: row['name'] as String,
    icon: row['icon'] as String,
    color: row['color'] as String,
    paise: paiseOf(row['amount']),
  );
}

class OtherCurrencyTotals {
  const OtherCurrencyTotals({
    required this.currency,
    required this.youOwePaise,
    required this.owedToYouPaise,
  });

  final String currency;
  final int youOwePaise;
  final int owedToYouPaise;

  factory OtherCurrencyTotals.fromJson(Map<String, dynamic> row) =>
      OtherCurrencyTotals(
        currency: row['currency'] as String,
        youOwePaise: paiseOf(row['you_owe']),
        owedToYouPaise: paiseOf(row['owed_to_you']),
      );
}

class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.mySharePaise,
    required this.youOwePaise,
    required this.owedToYouPaise,
    required this.categories,
    required this.otherCurrencies,
  });

  /// "2026-10".
  final String month;
  final int mySharePaise;
  final int youOwePaise;
  final int owedToYouPaise;
  final List<CategorySpend> categories;
  final List<OtherCurrencyTotals> otherCurrencies;

  factory MonthlySummary.fromJson(Map<String, dynamic> json) => MonthlySummary(
    month: json['month'] as String,
    mySharePaise: paiseOf(json['my_share']),
    youOwePaise: paiseOf(json['you_owe']),
    owedToYouPaise: paiseOf(json['owed_to_you']),
    categories: [
      for (final c in json['categories'] as List<dynamic>)
        CategorySpend.fromJson(c as Map<String, dynamic>),
    ],
    otherCurrencies: [
      for (final c in json['other_currencies'] as List<dynamic>)
        OtherCurrencyTotals.fromJson(c as Map<String, dynamic>),
    ],
  );
}

class PayerTotal {
  const PayerTotal({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.paise,
  });

  final int userId;
  final String firstName;
  final String lastName;
  final int paise;

  factory PayerTotal.fromJson(Map<String, dynamic> row) => PayerTotal(
    userId: (row['user_id'] as num).toInt(),
    firstName: row['first_name'] as String? ?? '',
    lastName: row['last_name'] as String? ?? '',
    paise: paiseOf(row['amount']),
  );
}

class GroupTotals {
  const GroupTotals({
    required this.totalSpentPaise,
    required this.mySharePaise,
    required this.iPaidPaise,
    required this.categories,
    required this.paidBy,
  });

  final int totalSpentPaise;
  final int mySharePaise;
  final int iPaidPaise;
  final List<CategorySpend> categories;
  final List<PayerTotal> paidBy;

  factory GroupTotals.fromJson(Map<String, dynamic> json) => GroupTotals(
    totalSpentPaise: paiseOf(json['total_spent']),
    mySharePaise: paiseOf(json['my_share']),
    iPaidPaise: paiseOf(json['i_paid']),
    categories: [
      for (final c in json['categories'] as List<dynamic>)
        CategorySpend.fromJson(c as Map<String, dynamic>),
    ],
    paidBy: [
      for (final p in json['paid_by'] as List<dynamic>)
        PayerTotal.fromJson(p as Map<String, dynamic>),
    ],
  );
}

enum ExpenseSort {
  newest('newest'),
  oldest('oldest'),
  amountDesc('amount_desc'),
  amountAsc('amount_asc');

  const ExpenseSort(this.api);
  final String api;
}

enum PaidBy {
  me('me'),
  others('others');

  const PaidBy(this.api);
  final String api;
}

class ExpenseQuery {
  const ExpenseQuery({
    this.groupId,
    this.q,
    this.categoryIds = const [],
    this.paidBy,
    this.from,
    this.to,
    this.sort,
    this.page,
  });

  final int? groupId;
  final String? q;
  final List<int> categoryIds;
  final PaidBy? paidBy;
  final DateTime? from;
  final DateTime? to;
  final ExpenseSort? sort;
  final int? page;

  /// Only the filters that are set; the server defaults the rest.
  Map<String, dynamic> toQuery() => {
    if (groupId != null) 'group_id': groupId,
    if (q != null && q!.isNotEmpty) 'q': q,
    if (categoryIds.isNotEmpty) 'category_ids[]': categoryIds,
    if (paidBy != null) 'paid_by': paidBy!.api,
    if (from != null) 'from': isoDate(from!),
    if (to != null) 'to': isoDate(to!),
    if (sort != null) 'sort': sort!.api,
    if (page != null) 'page': page,
  };
}

class NewExpense {
  const NewExpense({
    required this.name,
    required this.paise,
    required this.date,
    required this.payerId,
    required this.categoryId,
    required this.splitType,
    required this.distribution,
    this.groupId,
    this.notes,
  });

  final String name;
  final int paise;
  final DateTime date;
  final int payerId;
  final int? groupId;
  final int categoryId;
  final SplitType splitType;
  final String? notes;

  /// Per person, in the order they appear on the split. The value means:
  /// equal: ignored (only the user ids matter); percentage: hundredths of a
  /// percent (33.33% is 3333); exact: the person's whole amount in paise.
  final List<MapEntry<int, int>> distribution;

  Map<String, dynamic> toJson() => {
    'expense': {
      'name': name,
      'amount': paiseToApi(paise),
      'currency': 'INR',
      'expense_date': isoDate(date),
      'payer_id': payerId,
      'group_id': groupId,
      'category_id': categoryId,
      'split_type': splitType.api,
      'notes': notes,
      'distribution': [
        for (final e in _entries()) {'user_id': e.key, 'amount': e.value},
      ],
    },
  };

  List<MapEntry<int, String>> _entries() {
    switch (splitType) {
      case SplitType.equal:
        final shares = splitEqual(paise, [for (final e in distribution) e.key]);
        return [
          for (final e in distribution)
            MapEntry(e.key, paiseToApi(shares[e.key]!)),
        ];
      case SplitType.percentage:
        return [
          // Hundredths of a percent format the same way as paise.
          for (final e in distribution) MapEntry(e.key, paiseToApi(e.value)),
        ];
      case SplitType.exact:
        return [
          for (final e in distribution) MapEntry(e.key, paiseToApi(e.value)),
        ];
    }
  }
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum ActivityAction { created, updated, deleted, settled }

/// A settle-up as the activity log copied it.
class PaymentSnapshot {
  const PaymentSnapshot({
    required this.paise,
    required this.settledOn,
    required this.payerId,
    required this.payerName,
    required this.payeeId,
    required this.payeeName,
    this.notes,
  });

  final int paise;
  final DateTime settledOn;
  final int payerId;
  final String payerName;
  final int payeeId;
  final String payeeName;
  final String? notes;

  factory PaymentSnapshot.fromJson(Map<String, dynamic> s) {
    final payer = s['payer'] as Map<String, dynamic>;
    final payee = s['payee'] as Map<String, dynamic>;
    return PaymentSnapshot(
      paise: paiseOf(s['amount']),
      settledOn: DateTime.parse(s['settled_on'] as String),
      payerId: (payer['id'] as num).toInt(),
      payerName: payer['name'] as String,
      payeeId: (payee['id'] as num).toInt(),
      payeeName: payee['name'] as String,
      notes: s['notes'] as String?,
    );
  }
}

class SnapshotShare {
  const SnapshotShare({
    required this.userId,
    required this.name,
    required this.paise,
  });

  final int userId;
  final String name;
  final int paise;
}

/// The expense as the activity log copied it. Names are copied too, so a
/// deleted expense still reads.
class ExpenseSnapshot {
  const ExpenseSnapshot({
    required this.name,
    required this.paise,
    required this.date,
    required this.splitType,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.payerId,
    required this.payerName,
    required this.shares,
    this.notes,
    this.groupName,
  });

  final String name;
  final int paise;
  final DateTime date;
  final SplitType splitType;
  final String? notes;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final int payerId;
  final String payerName;
  final String? groupName;
  final List<SnapshotShare> shares;

  factory ExpenseSnapshot.fromJson(Map<String, dynamic> s) {
    final category = s['category'] as Map<String, dynamic>;
    final payer = s['payer'] as Map<String, dynamic>;
    final group = s['group'] as Map<String, dynamic>?;
    return ExpenseSnapshot(
      name: s['name'] as String,
      paise: paiseOf(s['amount']),
      date: DateTime.parse(s['expense_date'] as String),
      splitType: SplitType.fromApi(s['split_type'] as String),
      notes: s['notes'] as String?,
      categoryName: category['name'] as String,
      categoryIcon: category['icon'] as String,
      categoryColor: category['color'] as String,
      payerId: (payer['id'] as num).toInt(),
      payerName: payer['name'] as String,
      groupName: group?['name'] as String?,
      shares: [
        for (final share in s['shares'] as List<dynamic>)
          SnapshotShare(
            userId: ((share as Map)['user_id'] as num).toInt(),
            name: share['name'] as String,
            paise: paiseOf(share['amount']),
          ),
      ],
    );
  }
}

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.action,
    required this.at,
    required this.actorId,
    required this.actorName,
    required this.changedFields,
    this.groupId,
    this.groupName,
    this.expenseId,
    this.settlementId,
    this.before,
    this.after,
    this.payment,
  });

  final int id;
  final ActivityAction action;
  final DateTime at;
  final int actorId;
  final String actorName;
  final int? groupId;
  final String? groupName;
  final int? expenseId;
  final int? settlementId;
  final ExpenseSnapshot? before;
  final ExpenseSnapshot? after;

  /// Set only when [action] is settled; the expense copies are then null.
  final PaymentSnapshot? payment;

  /// Top-level snapshot keys that differ; empty unless [action] is updated.
  final List<String> changedFields;

  /// The latest expense copy: after an add or edit, before a delete.
  /// Only for expense entries.
  ExpenseSnapshot get current => after ?? before!;

  /// The amount the row shows, for expenses and payments alike.
  int get subjectPaise => payment?.paise ?? current.paise;

  factory ActivityEntry.fromJson(Map<String, dynamic> resource) {
    final a = resource['attributes'] as Map<String, dynamic>;
    final actor = a['actor'] as Map<String, dynamic>;
    final group = a['group'] as Map<String, dynamic>?;
    final before = a['before'] as Map<String, dynamic>?;
    final after = a['after'] as Map<String, dynamic>?;
    if (before == null && after == null) {
      throw const FormatException('Activity needs a before or after copy');
    }
    final action = ActivityAction.values.byName(a['action'] as String);
    final settled = action == ActivityAction.settled;
    return ActivityEntry(
      id: int.parse(resource['id'] as String),
      action: action,
      at: DateTime.parse(a['created_at'] as String).toLocal(),
      actorId: (actor['id'] as num).toInt(),
      actorName: actor['name'] as String,
      groupId: (group?['id'] as num?)?.toInt(),
      groupName: group?['name'] as String?,
      expenseId: (a['expense_id'] as num?)?.toInt(),
      settlementId: (a['settlement_id'] as num?)?.toInt(),
      before: before == null || settled
          ? null
          : ExpenseSnapshot.fromJson(before),
      after: after == null || settled ? null : ExpenseSnapshot.fromJson(after),
      payment: settled ? PaymentSnapshot.fromJson(after!) : null,
      changedFields: [
        for (final f in a['changed_fields'] as List<dynamic>) f as String,
      ],
    );
  }
}
