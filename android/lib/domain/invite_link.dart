import 'dart:convert';

class InviteLink {
  const InviteLink({required this.token, required this.email});

  final String token;
  final String email;
}

/// Reads `ezsplit://register?...` and `https://<host>/register?...`.
///
/// The server emails the email unencoded, so the query is split by hand:
/// `Uri.queryParameters` would turn a `+` in the address into a space.
InviteLink? parseInviteLink(String text) {
  final raw = text.trim();
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  final isApp = uri.scheme == 'ezsplit' && uri.host == 'register';
  final isWeb =
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.path == '/register';
  if (!isApp && !isWeb) return null;

  String? token;
  String? email;
  // Dart's Uri rewrites a bad '%' as '%25', so read the query from the raw text.
  final q = raw.indexOf('?');
  if (q < 0) return null;
  final hash = raw.indexOf('#', q);
  final query = raw.substring(q + 1, hash < 0 ? raw.length : hash);
  for (final pair in query.split('&')) {
    final i = pair.indexOf('=');
    if (i < 0) continue;
    final String value;
    try {
      value = _decode(pair.substring(i + 1));
    } on FormatException {
      continue;
    }
    switch (pair.substring(0, i)) {
      case 'token':
        token = value;
      case 'email_address':
        email = value;
    }
  }
  if (token == null || token.isEmpty || email == null || email.isEmpty) {
    return null;
  }
  return InviteLink(token: token, email: email);
}

/// Percent-decodes strictly (a `+` stays a `+`). Bad escapes or invalid UTF-8
/// throw FormatException, so a crafted link can't slip through as U+FFFD text.
String _decode(String s) {
  final bytes = <int>[];
  final hexPair = RegExp(r'^[0-9a-fA-F]{2}$');
  for (var i = 0; i < s.length;) {
    if (s[i] == '%') {
      final hex = i + 3 <= s.length ? s.substring(i + 1, i + 3) : '';
      if (!hexPair.hasMatch(hex)) throw const FormatException('Bad escape');
      bytes.add(int.parse(hex, radix: 16));
      i += 3;
    } else {
      final next = s.indexOf('%', i);
      final end = next < 0 ? s.length : next;
      bytes.addAll(utf8.encode(s.substring(i, end)));
      i = end;
    }
  }
  return utf8.decode(bytes);
}
