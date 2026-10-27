import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class BrutalInput extends StatefulWidget {
  const BrutalInput({
    super.key,
    this.label,
    this.controller,
    this.errorText,
    this.readOnly = false,
    this.keyboardType,
  });

  final String? label;
  final TextEditingController? controller;
  final String? errorText;
  final bool readOnly;
  final TextInputType? keyboardType;

  @override
  State<BrutalInput> createState() => _BrutalInputState();
}

class _BrutalInputState extends State<BrutalInput> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final hasError = widget.errorText != null;
    final borderColor = hasError ? c.negative : c.ink;
    final lit = _focused && !widget.readOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: widget.readOnly ? c.bg : c.card,
            borderRadius: BorderRadius.circular(kCardRadius),
            border: Border.all(color: borderColor, width: kCardBorder),
            boxShadow: lit
                ? [
                    BoxShadow(
                      offset: const Offset(kShadowOffset, kShadowOffset),
                      blurRadius: 0,
                      color: c.ink,
                    ),
                  ]
                : null,
          ),
          child: TextField(
            focusNode: _focus,
            controller: widget.controller,
            readOnly: widget.readOnly,
            keyboardType: widget.keyboardType,
            style: text.bodyLarge?.copyWith(color: c.ink),
            cursorColor: c.ink,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: text.bodySmall?.copyWith(
              color: c.negative,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
