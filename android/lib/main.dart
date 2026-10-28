import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/api_client.dart';
import 'state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  checkBaseUrl(apiBaseUrl, release: kReleaseMode, allowLanHttp: allowLanHttp);
  final client = await createApiClient(baseUrl: apiBaseUrl);
  runApp(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        cookieJarProvider.overrideWithValue(client.cookieJar!),
      ],
      child: const EzsplitApp(),
    ),
  );
}
