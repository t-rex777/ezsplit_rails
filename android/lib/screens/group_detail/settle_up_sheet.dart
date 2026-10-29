import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/settlements_repository.dart';
import '../../domain/money.dart';
import '../../domain/settle_plan.dart';
import '../../state/activity.dart';
import '../../state/group_detail.dart';
import '../../state/groups.dart';
import '../../state/summary.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/brutal_button.dart';
import '../../widgets/brutal_input.dart';
import '../../widgets/brutal_pill.dart';
import '../../widgets/brutal_sheet.dart';
import '../groups/group_widgets.dart';

/// Opens the sheet for [transfer]. [names] maps user id to the name to show
/// ("You" for the signed-in user). Shows the "Payment recorded" toast once a
/// payment is saved.
Future<void> showSettleUpSheet(
  BuildContext context, {
  required int groupId,
  required Transfer transfer,
  required int meId,
  required Map<int, String> names,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final recorded = await showBrutalSheet<bool>(
    context,
    title: 'Settle up',
    // Dragging could close the sheet while a payment is posting.
    enableDrag: false,
    child: _SettleForm(
      groupId: groupId,
      transfer: transfer,
      meId: meId,
      names: names,
    ),
  );
  if (recorded == true) {
    messenger.showSnackBar(const SnackBar(content: Text('Payment recorded')));
  }
}

const _maxWholeDigits = 12;

/// Letters are dropped, and the part before the point stops at 12 digits so
/// the paise total can never overflow.
class _RupeesFormatter extends TextInputFormatter {
  static final _allowed = RegExp(r'^[0-9,]*\.?[0-9]*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    if (!_allowed.hasMatch(t)) return oldValue;
    final whole = t.split('.').first.replaceAll(',', '');
    return whole.length > _maxWholeDigits ? oldValue : newValue;
  }
}

class _SettleForm extends ConsumerStatefulWidget {
  const _SettleForm({
    required this.groupId,
    required this.transfer,
    required this.meId,
    required this.names,
  });

  final int groupId;
  final Transfer transfer;
  final int meId;
  final Map<int, String> names;

  @override
  ConsumerState<_SettleForm> createState() => _SettleFormState();
}

class _SettleFormState extends ConsumerState<_SettleForm> {
  late final TextEditingController _amount;
  bool _posting = false;
  String? _postError;

  Transfer get _t => widget.transfer;
  bool get _iPay => _t.fromUserId == widget.meId;
  String get _from => widget.names[_t.fromUserId] ?? 'Member';
  String get _to => widget.names[_t.toUserId] ?? 'Member';
  int get _full => _t.paise;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: _plain(_full));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// "1850" or "333.34": what the field shows for a full payment.
  String _plain(int paise) =>
      paiseToApi(paise).replaceFirst(RegExp(r'\.00$'), '');

  int? get _parsed => parseRupees(_amount.text);
  bool get _isFull => _parsed == _full;

  String? get _error {
    final p = _parsed;
    if (p == null) {
      final t = _amount.text.trim();
      if (t.isEmpty) return null;
      return RegExp(r'^[0.,\s]*$').hasMatch(t)
          ? 'Enter more than ₹0'
          : 'Use up to 2 decimals';
    }
    if (p <= _full) return null;
    return _iPay
        ? "That's more than you owe"
        : "That's more than ${_from.split(' ').first} owes";
  }

  bool get _canRecord =>
      _iPay && !_posting && _parsed != null && _parsed! <= _full;

  Future<void> _record() async {
    final paise = _parsed;
    if (paise == null || _posting) return;
    setState(() {
      _posting = true;
      _postError = null;
    });
    // The container outlives this sheet, so the reload happens even if the
    // sheet is gone by the time the post finishes.
    final container = ProviderScope.containerOf(context);
    final repo = ref.read(settlementsRepositoryProvider);
    final groupId = widget.groupId;
    try {
      await repo.create(
        payeeId: _t.toUserId,
        paise: paise,
        settledOn: DateTime.now(),
        groupId: groupId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _postError = errorMessage(e);
      });
      return;
    }
    container
      ..invalidate(groupBalancesProvider(groupId))
      ..invalidate(groupExpensesProvider)
      ..invalidate(groupProvider(groupId))
      ..invalidate(groupsProvider)
      ..invalidate(activityFeedProvider);
    invalidateMonthlySummaries(container.invalidate);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final headline = _iPay ? 'You pay $_to' : '$_from pays you';
    final error = _error ?? _postError;
    return PopScope(
      canPop: !_posting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(_initial(_from), tintFor(context, _t.fromUserId)),
              const SizedBox(width: 8),
              const Icon(Symbols.arrow_forward),
              const SizedBox(width: 8),
              Avatar(_initial(_to), tintFor(context, _t.toUserId)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BrutalInput(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Center(
                widthFactor: 1,
                child: Text(
                  '₹',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            errorText: error,
            inputFormatters: [_RupeesFormatter()],
            onChanged: (_) => setState(() => _postError = null),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BrutalPill(
                label: 'Full amount',
                selected: _isFull,
                onTap: () => setState(() {
                  _amount.text = _plain(_full);
                  _postError = null;
                }),
              ),
              BrutalPill(
                label: 'Part of it',
                selected: !_isFull,
                onTap: () {
                  if (!_isFull) return;
                  setState(() => _amount.clear());
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This records a payment. No money moves in the app.',
            style: text.bodyMedium?.copyWith(color: c.ink),
          ),
          const SizedBox(height: 16),
          if (_iPay)
            BrutalButton(
              label: 'Record payment',
              onPressed: _canRecord ? _record : null,
            )
          else
            Text(
              'Ask $_from to record it',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

String _initial(String name) => name.isEmpty ? '?' : name[0].toUpperCase();
