import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shared press/focus behaviour for neo-brutalist surfaces. At rest it draws a
/// hard shadow; while pressed it moves by [pressOffset] and the shadow drops
/// to zero. Not exported for screens: use the Brutal* widgets.
class BrutalSurface extends StatefulWidget {
  const BrutalSurface({
    super.key,
    required this.color,
    required this.borderWidth,
    required this.radius,
    required this.child,
    this.onTap,
    this.shadowOffset = kShadowOffset,
    this.showShadow = true,
    this.isButton = false,
    this.padding = EdgeInsets.zero,
    this.constraints = const BoxConstraints(),
    this.semanticLabel,
  });

  final Color color;
  final double borderWidth;
  final double radius;
  final Widget child;
  final VoidCallback? onTap;
  final double shadowOffset;

  /// False draws no shadow at all (disabled state).
  final bool showShadow;
  final bool isButton;
  final EdgeInsets padding;
  final BoxConstraints constraints;
  final String? semanticLabel;

  @override
  State<BrutalSurface> createState() => _BrutalSurfaceState();
}

class _BrutalSurfaceState extends State<BrutalSurface> {
  bool _pressed = false;
  bool _focused = false;

  bool get _interactive => widget.onTap != null;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.ez.ink;
    final line = context.ez.line;
    final down = _pressed && _interactive;
    final shift = down ? widget.shadowOffset : 0.0;
    final shadows = (!widget.showShadow || down)
        ? <BoxShadow>[]
        : [
            BoxShadow(
              offset: Offset(widget.shadowOffset, widget.shadowOffset),
              blurRadius: 0,
              color: line,
            ),
          ];

    Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(shift, shift, 0),
      constraints: widget.constraints,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: line, width: widget.borderWidth),
        boxShadow: shadows,
      ),
      child: widget.child,
    );

    if (!_interactive) {
      if (!widget.isButton) return surface;
      return Semantics(
        button: true,
        enabled: false,
        excludeSemantics: widget.semanticLabel != null,
        label: widget.semanticLabel,
        child: surface,
      );
    }

    // 2px ink outline with a 2px gap, drawn outside the surface.
    surface = Stack(
      // Passthrough lets a tight parent (a full-width button) reach the surface.
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        surface,
        if (_focused)
          Positioned(
            left: -4,
            top: -4,
            right: -4,
            bottom: -4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.radius + 4),
                  border: Border.all(color: ink, width: 2),
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      button: widget.isButton,
      enabled: true,
      focusable: true,
      onTap: widget.onTap,
      excludeSemantics: widget.semanticLabel != null,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap!();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          child: surface,
        ),
      ),
    );
  }
}

class BrutalCard extends StatelessWidget {
  const BrutalCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final EdgeInsets padding;

  /// Makes the card tappable and gives it the pressed state.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BrutalSurface(
      color: color ?? context.ez.card,
      borderWidth: kCardBorder,
      radius: kCardRadius,
      padding: padding,
      onTap: onTap,
      child: child,
    );
  }
}
