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
  final uri = Uri.tryParse(text.trim());
  if (uri == null) return null;
  final isApp = uri.scheme == 'ezsplit' && uri.host == 'register';
  final isWeb =
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.path == '/register';
  if (!isApp && !isWeb) return null;

  String? token;
  String? email;
  for (final pair in uri.query.split('&')) {
    final i = pair.indexOf('=');
    if (i < 0) continue;
    final String value;
    try {
      value = Uri.decodeComponent(pair.substring(i + 1));
    } on ArgumentError {
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
