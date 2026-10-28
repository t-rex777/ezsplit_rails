import 'package:flutter/material.dart';

import '../data/api_error.dart';
import '../theme/tokens.dart';
import 'brutal_button.dart';
import 'brutal_sheet.dart';

/// Asks before a destructive action. Returns true when confirmed.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showBrutalSheet<bool>(
    context,
    title: title,
    child: Builder(
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(body, style: Theme.of(ctx).textTheme.bodyLarge),
          const SizedBox(height: 20),
          BrutalButton(
            label: confirmLabel,
            color: destructive ? ctx.ez.peach : ctx.ez.amber,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: 12),
          BrutalButton(
            label: 'Cancel',
            color: ctx.ez.card,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Asks first, then runs [action] inside the sheet. The buttons are disabled
/// and the sheet can't be dismissed while it runs. A failure stays in the sheet
/// as the server's message. Returns true once [action] has finished.
Future<bool> confirmAndRun(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required Future<void> Function() action,
  bool destructive = false,
}) async {
  final result = await showBrutalSheet<bool>(
    context,
    title: title,
    // Dragging could close the sheet while the action is running.
    enableDrag: false,
    child: _ConfirmRun(
      body: body,
      confirmLabel: confirmLabel,
      action: action,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class _ConfirmRun extends StatefulWidget {
  const _ConfirmRun({
    required this.body,
    required this.confirmLabel,
    required this.action,
    required this.destructive,
  });

  final String body;
  final String confirmLabel;
  final Future<void> Function() action;
  final bool destructive;

  @override
  State<_ConfirmRun> createState() => _ConfirmRunState();
}

class _ConfirmRunState extends State<_ConfirmRun> {
  bool _running = false;
  String? _error;

  Future<void> _run() async {
    // The action may end the screen behind this sheet, so keep what we need.
    final navigator = Navigator.of(context);
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await widget.action();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = e is ApiError ? e.message : 'Something went wrong. Try again.';
      });
      return;
    }
    if (mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_running,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.body, style: text.bodyLarge),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: c.negative,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 20),
          BrutalButton(
            label: widget.confirmLabel,
            color: widget.destructive ? c.peach : c.amber,
            onPressed: _running ? null : _run,
          ),
          const SizedBox(height: 12),
          BrutalButton(
            label: 'Cancel',
            color: c.card,
            onPressed: _running ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
