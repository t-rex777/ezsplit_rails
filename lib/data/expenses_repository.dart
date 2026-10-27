import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import 'api_client.dart';
import 'jsonapi.dart';
import 'models.dart';

class ExpensesRepository {
  ExpensesRepository(this._api);

  final ApiClient _api;

  Future<Page<Expense>> list(ExpenseQuery query) async {
    final json = await _api.get('/expenses', query: query.toQuery());
    return parseOrThrow(() {
      final doc = JsonApiDoc(json);
      return doc.page((r) => Expense.fromJson(r, doc.index));
    });
  }

  Future<Expense> get(int id) async {
    final json = await _api.get('/expenses/$id');
    return parseOrThrow(() {
      final doc = JsonApiDoc(json);
      return Expense.fromJson(doc.data, doc.index);
    });
  }

  /// The create response has no `included`, so this re-reads the expense.
  Future<Expense> create(NewExpense expense) async {
    final json = await _api.post('/expenses', body: expense.toJson());
    return get(
      parseOrThrow(() => int.parse(JsonApiDoc(json).data['id'] as String)),
    );
  }

  Future<Expense> update(int id, NewExpense expense) async {
    await _api.patch('/expenses/$id', body: expense.toJson());
    return get(id);
  }

  Future<void> delete(int id) async {
    await _api.delete('/expenses/$id');
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(ref.watch(apiClientProvider)),
);
