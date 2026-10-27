import 'api_error.dart';
import '../domain/money.dart';

const String unexpectedResponseMessage = 'Something went wrong. Try again.';

/// Runs [parse] on a 2xx body. A body with the wrong shape surfaces as an
/// [ApiError] instead of a raw TypeError.
T parseOrThrow<T>(T Function() parse) {
  try {
    return parse();
  } on ApiError {
    rethrow;
  } catch (_) {
    throw const ApiError(message: unexpectedResponseMessage);
  }
}

/// Server decimal (string or number) to paise.
int paiseOf(Object? value) {
  if (value is String) return paiseFromApi(value);
  if (value is num) return paiseFromApi(value.toString());
  throw FormatException('Not an amount: $value');
}

/// Resolves resource relationships against `included` by (type, id).
class JsonApiIndex {
  JsonApiIndex(List<dynamic>? included) {
    for (final r in included ?? const []) {
      final m = r as Map<String, dynamic>;
      _byKey['${m['type']}:${m['id']}'] = m;
    }
  }

  final Map<String, Map<String, dynamic>> _byKey = {};

  Map<String, dynamic>? find(String type, Object id) => _byKey['$type:$id'];

  /// The resource behind a to-one relationship, or null when it is empty.
  /// Throws when the relationship points at something not in `included`.
  Map<String, dynamic>? one(Map<String, dynamic> resource, String name) {
    final ref = _ref(resource, name);
    if (ref == null) return null;
    return _resolve(ref);
  }

  /// The resources behind a to-many relationship, in server order.
  List<Map<String, dynamic>> many(Map<String, dynamic> resource, String name) {
    final data = _data(resource, name);
    if (data == null) return const [];
    return [
      for (final ref in data as List<dynamic>)
        _resolve(ref as Map<String, dynamic>),
    ];
  }

  Object? _data(Map<String, dynamic> resource, String name) {
    final rels = resource['relationships'] as Map<String, dynamic>;
    final rel = rels[name] as Map<String, dynamic>?;
    return rel?['data'];
  }

  Map<String, dynamic>? _ref(Map<String, dynamic> resource, String name) =>
      _data(resource, name) as Map<String, dynamic>?;

  Map<String, dynamic> _resolve(Map<String, dynamic> ref) {
    final found = find(ref['type'] as String, ref['id'] as Object);
    if (found == null) {
      throw FormatException('Missing included ${ref['type']} ${ref['id']}');
    }
    return found;
  }
}

class Page<T> {
  const Page({
    required this.items,
    required this.page,
    required this.total,
    this.nextPage,
  });

  final List<T> items;
  final int page;
  final int total;
  final int? nextPage;
}

/// A JSON:API response body with its included index and paging meta.
class JsonApiDoc {
  JsonApiDoc(this.json) : index = JsonApiIndex(json['included'] as List?);

  final Map<String, dynamic> json;
  final JsonApiIndex index;

  Map<String, dynamic> get data => json['data'] as Map<String, dynamic>;

  List<Map<String, dynamic>> get list => rawList;

  /// `data` as a list of plain maps (also used by the non-JSON:API balance rows).
  List<Map<String, dynamic>> get rawList => [
    for (final r in json['data'] as List<dynamic>) r as Map<String, dynamic>,
  ];

  Page<T> page<T>(T Function(Map<String, dynamic> resource) parse) {
    final meta = json['meta'] as Map<String, dynamic>?;
    final items = [for (final r in list) parse(r)];
    return Page(
      items: items,
      page: (meta?['current_page'] as num?)?.toInt() ?? 1,
      total: (meta?['total'] as num?)?.toInt() ?? items.length,
      nextPage: (meta?['next_page'] as num?)?.toInt(),
    );
  }
}

/// Follows `next_page` until the last page.
Future<List<T>> allPages<T>(Future<Page<T>> Function(int page) fetch) async {
  final items = <T>[];
  int? next = 1;
  while (next != null) {
    final page = await fetch(next);
    items.addAll(page.items);
    next = page.nextPage;
  }
  return items;
}
