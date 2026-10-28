import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'domain/invite_link.dart';
import 'router.dart';
import 'state/theme_mode.dart';
import 'theme/app_theme.dart';

/// Opens the accept invite screen for an invite link; ignores anything else.
void openIncomingLink(GoRouter router, Uri uri) {
  final link = parseInviteLink(uri.toString());
  if (link == null) return;
  router.go(
    Uri(
      path: '/invite',
      queryParameters: {'token': link.token, 'email': link.email},
    ).toString(),
  );
}

class EzsplitApp extends ConsumerStatefulWidget {
  const EzsplitApp({super.key, this.listenForLinks = true, this.linkStream});

  /// Tests turn this off: app_links needs the platform plugin.
  final bool listenForLinks;

  /// Replaces the app_links stream, for tests.
  final Stream<Uri>? linkStream;

  @override
  ConsumerState<EzsplitApp> createState() => _EzsplitAppState();
}

class _EzsplitAppState extends ConsumerState<EzsplitApp> {
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    // The stream also delivers the link that launched the app.
    final stream =
        widget.linkStream ??
        (widget.listenForLinks ? AppLinks().uriLinkStream : null);
    _links = stream?.listen(_open);
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  void _open(Uri uri) => openIncomingLink(ref.read(routerProvider), uri);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ezsplit',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
