import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import 'api_client.dart';
import 'jsonapi.dart';
import 'models.dart';

class CategoriesRepository {
  CategoriesRepository(this._api);

  final ApiClient _api;

  Future<List<Category>> list() => allPages((page) async {
    final json = await _api.get(
      '/categories',
      query: {if (page > 1) 'page': page},
    );
    return parseOrThrow(() => JsonApiDoc(json).page(Category.fromJson));
  });

  Future<Category> create({
    required String name,
    required String icon,
    required String color,
  }) async => _category(
    await _api.post(
      '/categories',
      body: {
        'category': {'name': name, 'icon': icon, 'color': color},
      },
    ),
  );

  Future<Category> update(
    int id, {
    String? name,
    String? icon,
    String? color,
  }) async => _category(
    await _api.patch(
      '/categories/$id',
      body: {
        'category': {'name': ?name, 'icon': ?icon, 'color': ?color},
      },
    ),
  );

  Future<void> delete(int id) async {
    await _api.delete('/categories/$id');
  }

  Category _category(Map<String, dynamic> json) =>
      parseOrThrow(() => Category.fromJson(JsonApiDoc(json).data));
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.watch(apiClientProvider)),
);
