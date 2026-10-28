const String connectionErrorMessage =
    "Couldn't reach ezsplit. Check your connection.";

class ApiError implements Exception {
  const ApiError({this.status, required this.message});

  final int? status;
  final String message;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiError($status, $message)';
}
