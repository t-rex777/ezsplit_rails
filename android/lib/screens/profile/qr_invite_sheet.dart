import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/models.dart';
import '../../data/users_repository.dart';
import '../../theme/tokens.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_card.dart';
import '../../widgets/brutal_sheet.dart';
import '../groups/group_widgets.dart';

/// Shows a new one-use invite as a QR code. A phone camera opens the same
/// web page an invite email links to.
Future<void> showQrInviteSheet(BuildContext context) => showBrutalSheet<void>(
  context,
  title: 'Scan to join',
  child: const _QrInvite(),
);

class _QrInvite extends ConsumerStatefulWidget {
  const _QrInvite();

  @override
  ConsumerState<_QrInvite> createState() => _QrInviteState();
}

class _QrInviteState extends ConsumerState<_QrInvite> {
  late Future<QrInvite> _invite = _make();

  Future<QrInvite> _make() => ref.read(usersRepositoryProvider).qrInvite();

  void _refresh() {
    setState(() {
      _invite = _make();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    return FutureBuilder<QrInvite>(
      future: _invite,
      builder: (context, snap) {
        if (snap.hasError && snap.connectionState == ConnectionState.done) {
          return RetryMessage(
            message: errorMessage(snap.error!),
            onRetry: _refresh,
          );
        }
        final invite = snap.data;
        if (invite == null) {
          return SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator(color: c.ink)),
          );
        }
        final loading = snap.connectionState == ConnectionState.waiting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              // White in both themes: cameras read dark-on-light codes best.
              child: BrutalCard(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  key: ValueKey(invite.url),
                  data: invite.url,
                  size: 240,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: onAccent,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: onAccent,
                  ),
                  semanticsLabel: 'Invite QR code',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Works once, for one person. Expires in 7 days.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            BrutalButton(
              label: 'New code',
              icon: Symbols.refresh,
              color: c.card,
              onPressed: loading ? null : _refresh,
            ),
          ],
        );
      },
    );
  }
}
