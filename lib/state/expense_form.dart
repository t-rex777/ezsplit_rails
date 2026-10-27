import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/expenses_repository.dart';
import '../data/models.dart';
import '../domain/money.dart';
import '../domain/split.dart';
import '../screens/groups/group_widgets.dart' show errorMessage;
import 'group_detail.dart';
import 'groups.dart';
import 'session.dart';

const lastCategoryKey = 'last_category_id';

enum SplitMode {
  equal('Equally', SplitType.equal),
  percent('By %', SplitType.percentage),
  exact('Exact', SplitType.exact);

  const SplitMode(this.label, this.type);
  final String label;
  final SplitType type;

  static SplitMode of(SplitType t) =>
      SplitMode.values.firstWhere((m) => m.type == t);
}

/// An open expense, for the detail and edit screens.
final expenseProvider = FutureProvider.autoDispose.family<Expense, int>(
  (ref, id) => ref.watch(expensesRepositoryProvider).get(id),
  retry: (_, _) => null,
);

/// The category used for the last saved expense, kept on this device.
final lastCategoryIdProvider = FutureProvider.autoDispose<int?>((ref) async {
  try {
    return (await SharedPreferences.getInstance()).getInt(lastCategoryKey);
  } catch (_) {
    return null;
  }
});

/// Reloads everything an expense change can alter in a group.
void invalidateAfterExpenseChange(
  void Function(ProviderOrFamily) invalidate,
  int groupId, {
  int? expenseId,
}) {
  invalidate(groupExpensesProvider);
  invalidate(groupBalancesProvider(groupId));
  invalidate(groupTotalsProvider(groupId));
  invalidate(groupProvider(groupId));
  invalidate(groupsProvider);
  if (expenseId != null) invalidate(expenseProvider(expenseId));
}

/// [expenseId] is null when adding.
typedef ExpenseFormKey = ({int groupId, int? expenseId});

class ExpenseFormState {
  const ExpenseFormState({
    required this.groupId,
    required this.meId,
    required this.members,
    required this.name,
    required this.amountText,
    required this.categoryId,
    required this.payerId,
    required this.date,
    required this.notes,
    required this.mode,
    required this.included,
    required this.percents,
    required this.exact,
    this.expenseId,
    this.posting = false,
    this.error,
  });

  final int groupId;
  final int? expenseId;
  final int meId;

  /// Everyone who can be in the split, in the order the split uses.
  final List<User> members;
  final String name;
  final String amountText;
  final int? categoryId;
  final int payerId;
  final DateTime date;
  final String notes;
  final SplitMode mode;

  /// Ids in the split, in member order.
  final List<int> included;

  /// Hundredths of a percent (33.33% is 3333). Valid when they sum to 10000.
  final Map<int, int> percents;

  /// Paise per person.
  final Map<int, int> exact;
  final bool posting;
  final String? error;

  bool get isEdit => expenseId != null;

  int? get paise => parseRupees(amountText);

  String? get amountError {
    final t = amountText.trim();
    if (t.isEmpty || paise != null) return null;
    final noAmount = RegExp(r'^[-0.,₹\s]*$').hasMatch(t);
    return noAmount ? 'Enter an amount above ₹0' : 'Use up to 2 decimals';
  }

  int get percentSum => included.fold(0, (a, id) => a + (percents[id] ?? 0));

  /// Positive is left to assign, negative is over.
  int get percentRemaining => 10000 - percentSum;

  int get exactSum => included.fold(0, (a, id) => a + (exact[id] ?? 0));

  int get exactRemaining => (paise ?? 0) - exactSum;

  /// The split adds up for the current mode.
  bool get splitValid {
    if (included.isEmpty) return false;
    return switch (mode) {
      SplitMode.equal => true,
      SplitMode.percent => percentRemaining == 0,
      SplitMode.exact => paise != null && exactRemaining == 0,
    };
  }

  /// What each included person owes, in paise. Empty without a valid amount.
  Map<int, int> get shares {
    final total = paise;
    if (total == null || included.isEmpty) return const {};
    return switch (mode) {
      SplitMode.equal => splitEqual(total, included),
      SplitMode.percent => splitPercent(total, [
        for (final id in included) MapEntry(id, percents[id] ?? 0),
      ]),
      SplitMode.exact => {for (final id in included) id: exact[id] ?? 0},
    };
  }

  bool get canSave =>
      !posting &&
      name.trim().isNotEmpty &&
      paise != null &&
      categoryId != null &&
      members.any((u) => u.id == payerId) &&
      splitValid;

  User? member(int id) => members.where((u) => u.id == id).firstOrNull;

  NewExpense toNewExpense() {
    final notes = this.notes.trim();
    return NewExpense(
      name: name.trim(),
      paise: paise!,
      date: date,
      payerId: payerId,
      groupId: groupId,
      categoryId: categoryId!,
      splitType: mode.type,
      notes: notes.isEmpty ? null : notes,
      distribution: [
        for (final id in included)
          MapEntry<int, num>(id, switch (mode) {
            SplitMode.equal => 1,
            SplitMode.percent => (percents[id] ?? 0) / 100,
            SplitMode.exact => exact[id] ?? 0,
          }),
      ],
    );
  }

  ExpenseFormState copyWith({
    String? name,
    String? amountText,
    int? categoryId,
    int? payerId,
    DateTime? date,
    String? notes,
    SplitMode? mode,
    List<int>? included,
    Map<int, int>? percents,
    Map<int, int>? exact,
    bool? posting,
    String? Function()? error,
  }) => ExpenseFormState(
    groupId: groupId,
    expenseId: expenseId,
    meId: meId,
    members: members,
    name: name ?? this.name,
    amountText: amountText ?? this.amountText,
    categoryId: categoryId ?? this.categoryId,
    payerId: payerId ?? this.payerId,
    date: date ?? this.date,
    notes: notes ?? this.notes,
    mode: mode ?? this.mode,
    included: included ?? this.included,
    percents: percents ?? this.percents,
    exact: exact ?? this.exact,
    posting: posting ?? this.posting,
    error: error != null ? error() : this.error,
  );
}

/// Percents as whole hundredths that always add to 10000, first people taking
/// the leftover, like the money split.
Map<int, int> equalPercents(List<int> ids) {
  final shares = splitEqual(10000, ids);
  return {for (final id in ids) id: shares[id]!};
}

class ExpenseFormNotifier extends Notifier<ExpenseFormState> {
  ExpenseFormNotifier(this.key);

  final ExpenseFormKey key;

  // The screen waits for these to load before it builds the form, so reading
  // them here does not need to watch them (a reload must not reset the form).
  @override
  ExpenseFormState build() {
    final me = ref.read(sessionProvider).requireValue!;
    final group = ref.read(groupProvider(key.groupId)).requireValue;
    final categories = ref.read(categoriesProvider).requireValue;
    final expenseId = key.expenseId;
    if (expenseId != null) {
      return _fromExpense(
        ref.read(expenseProvider(expenseId)).requireValue,
        me.id,
        group,
      );
    }
    final last = ref.read(lastCategoryIdProvider).value;
    final category = categories.any((c) => c.id == last)
        ? last
        : categories.firstOrNull?.id;
    final today = DateTime.now();
    return ExpenseFormState(
      groupId: key.groupId,
      meId: me.id,
      members: group.members,
      name: '',
      amountText: '',
      categoryId: category,
      payerId: me.id,
      date: DateTime(today.year, today.month, today.day),
      notes: '',
      mode: SplitMode.equal,
      included: [for (final u in group.members) u.id],
      percents: const {},
      exact: const {},
    );
  }

  ExpenseFormState _fromExpense(Expense e, int meId, Group group) {
    // A payer who has left the group still has to be choosable and visible.
    final members = [
      ...group.members,
      if (!group.members.any((u) => u.id == e.payer.id)) e.payer,
    ];
    final shareIds = {for (final s in e.shares) s.userId};
    final included = [
      for (final u in members)
        if (shareIds.contains(u.id)) u.id,
    ];
    final paiseById = {for (final s in e.shares) s.userId: s.paise};
    final mode = SplitMode.of(e.splitType);
    return ExpenseFormState(
      groupId: key.groupId,
      expenseId: e.id,
      meId: meId,
      members: members,
      name: e.name,
      amountText: paiseToApi(e.paise).replaceFirst(RegExp(r'\.00$'), ''),
      categoryId: e.category.id,
      payerId: e.payer.id,
      date: DateTime(e.date.year, e.date.month, e.date.day),
      notes: e.notes ?? '',
      mode: mode,
      included: included,
      percents: mode == SplitMode.percent
          ? _percentsFromShares(e.paise, included, paiseById)
          : const {},
      exact: mode == SplitMode.exact
          ? {for (final id in included) id: paiseById[id] ?? 0}
          : const {},
    );
  }

  /// The server keeps shares, not percents, so the percents are rebuilt by
  /// rounding each share to the nearest hundredth of a percent. Any rounding
  /// difference goes to the first person so the total is exactly 100.
  Map<int, int> _percentsFromShares(
    int total,
    List<int> ids,
    Map<int, int> paiseById,
  ) {
    if (total <= 0 || ids.isEmpty) return equalPercents(ids);
    final out = {
      for (final id in ids)
        id: ((paiseById[id] ?? 0) * 10000 + total ~/ 2) ~/ total,
    };
    final diff = 10000 - out.values.fold<int>(0, (a, b) => a + b);
    out[ids.first] = out[ids.first]! + diff;
    return out;
  }

  void setName(String v) => state = state.copyWith(name: v);

  void setAmount(String v) => state = state.copyWith(amountText: v);

  void setNotes(String v) => state = state.copyWith(notes: v);

  void setCategory(int id) => state = state.copyWith(categoryId: id);

  void setPayer(int id) => state = state.copyWith(payerId: id);

  void setDate(DateTime d) =>
      state = state.copyWith(date: DateTime(d.year, d.month, d.day));

  void setMode(SplitMode mode) {
    var s = state.copyWith(mode: mode);
    // Start By % from an even split so the first view is already valid.
    if (mode == SplitMode.percent && s.percentSum == 0) {
      s = s.copyWith(percents: equalPercents(s.included));
    }
    state = s;
  }

  /// Adds or removes a person. A person who is out has no percent or amount.
  void toggleIncluded(int id) {
    final isIn = state.included.contains(id);
    final ids = {...state.included};
    isIn ? ids.remove(id) : ids.add(id);
    state = state.copyWith(
      included: [
        for (final u in state.members)
          if (ids.contains(u.id)) u.id,
      ],
      percents: {...state.percents}..remove(id),
      exact: {...state.exact}..remove(id),
    );
  }

  void setPercent(int id, int hundredths) =>
      state = state.copyWith(percents: {...state.percents, id: hundredths});

  void setExact(int id, int paise) =>
      state = state.copyWith(exact: {...state.exact, id: paise});

  /// Saves the expense. Returns it on success; on failure the message is in
  /// `state.error` and the form stays as it was.
  Future<Expense?> save() async {
    if (!state.canSave) return null;
    final repo = ref.read(expensesRepositoryProvider);
    final body = state.toNewExpense();
    final id = state.expenseId;
    state = state.copyWith(posting: true, error: () => null);
    final Expense saved;
    try {
      saved = id == null
          ? await repo.create(body)
          : await repo.update(id, body);
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(posting: false, error: () => errorMessage(e));
      }
      return null;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(lastCategoryKey, body.categoryId);
    } catch (_) {
      // The category is only a convenience for the next expense.
    }
    if (ref.mounted) state = state.copyWith(posting: false);
    return saved;
  }
}

final expenseFormProvider = NotifierProvider.autoDispose
    .family<ExpenseFormNotifier, ExpenseFormState, ExpenseFormKey>(
      ExpenseFormNotifier.new,
    );
