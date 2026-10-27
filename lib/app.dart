import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/invite_link.dart';
import 'router.dart';
import 'state/theme_mode.dart';
import 'theme/app_theme.dart';

class EzsplitApp extends ConsumerStatefulWidget {
  const EzsplitApp({super.key, this.listenForLinks = true});

  /// Tests turn this off: app_links needs the platform plugin.
  final bool listenForLinks;

  @override
  ConsumerState<EzsplitApp> createState() => _EzsplitAppState();
}

class _EzsplitAppState extends ConsumerState<EzsplitApp> {
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    // The stream also delivers the link that launched the app.
    if (widget.listenForLinks) {
      _links = AppLinks().uriLinkStream.listen(_open);
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  void _open(Uri uri) {
    final link = parseInviteLink(uri.toString());
    if (link == null) return;
    ref
        .read(routerProvider)
        .go(
          Uri(
            path: '/invite',
            queryParameters: {'token': link.token, 'email': link.email},
          ).toString(),
        );
  }

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
