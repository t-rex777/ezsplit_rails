final _amountPattern = RegExp(r'^\d+(\.\d{1,2})?$');

/// Parses typed rupees into paise. Null for empty, zero, negative, non-numeric
/// or more than 2 decimals.
int? parseRupees(String input) {
  final cleaned = input.replaceAll(RegExp(r'[,₹\s]'), '');
  if (!_amountPattern.hasMatch(cleaned)) return null;
  final paise = _decimalToPaise(cleaned);
  return paise > 0 ? paise : null;
}

/// Converts a server decimal string such as "600.0" to paise.
int paiseFromApi(String decimal) => _decimalToPaise(decimal.trim());

String paiseToApi(int paise) {
  final sign = paise < 0 ? '-' : '';
  final abs = paise.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

String formatRupees(int paise) {
  final sign = paise < 0 ? '-' : '';
  final abs = paise.abs();
  final whole = _groupIndian((abs ~/ 100).toString());
  final cents = abs % 100;
  final decimals = cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}';
  return '$sign₹$whole$decimals';
}

// String maths avoids double rounding; extra decimals are truncated.
int _decimalToPaise(String s) {
  final negative = s.startsWith('-');
  final body = negative ? s.substring(1) : s;
  final parts = body.split('.');
  final whole = int.parse(parts[0].isEmpty ? '0' : parts[0]);
  final frac = parts.length > 1
      ? parts[1].padRight(2, '0').substring(0, 2)
      : '00';
  final paise = whole * 100 + int.parse(frac);
  return negative ? -paise : paise;
}

String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${groups.join(',')},$last3';
}
