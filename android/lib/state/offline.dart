import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// True after a request got no response, until the next one does.
class OfflineNotifier extends Notifier<bool> {
  @override
  bool build() {
    final client = ref.read(apiClientProvider);
    client.onOffline = () => state = true;
    client.onOnline = () {
      if (state) state = false;
    };
    return false;
  }
}

final offlineProvider = NotifierProvider<OfflineNotifier, bool>(
  OfflineNotifier.new,
);
