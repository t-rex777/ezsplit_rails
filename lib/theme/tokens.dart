import 'package:flutter/material.dart';

const double kCardBorder = 2.5;
const double kCardRadius = 12;
const double kPillBorder = 2;
const double kSheetBorder = 3;
const double kSheetRadius = 22;
const double kShadowOffset = 4;
const double kMinTap = 44;

/// Text and icons on coloured fills (accents and disabled grey), both modes.
const Color onAccent = Color(0xFF111111);

class EzColors extends ThemeExtension<EzColors> {
  const EzColors({
    required this.bg,
    required this.ink,
    required this.card,
    required this.amber,
    required this.green,
    required this.peach,
    required this.mint,
    required this.lilac,
    required this.positive,
    required this.negative,
  });

  final Color bg;
  final Color ink;
  final Color card;
  final Color amber;
  final Color green;
  final Color peach;
  final Color mint;
  final Color lilac;
  final Color positive;
  final Color negative;

  static const light = EzColors(
    bg: Color(0xFFFFF6DC),
    ink: Color(0xFF111111),
    card: Color(0xFFFFFFFF),
    amber: Color(0xFFEF9F27),
    green: Color(0xFF97C459),
    peach: Color(0xFFF5C4B3),
    mint: Color(0xFF9FE1CB),
    lilac: Color(0xFFCECBF6),
    positive: Color(0xFF27500A),
    negative: Color(0xFFA32D2D),
  );

  // Dark mode: ink is the cream outline/shadow colour. The brief gives four
  // accent fills; amber keeps its light value.
  static const dark = EzColors(
    bg: Color(0xFF141414),
    ink: Color(0xFFFFF6DC),
    card: Color(0xFF222222),
    amber: Color(0xFFEF9F27),
    green: Color(0xFF639922),
    peach: Color(0xFFD85A30),
    mint: Color(0xFF1D9E75),
    lilac: Color(0xFF7F77DD),
    positive: Color(0xFF97C459),
    negative: Color(0xFFF09595),
  );

  /// Disabled button fill, same in both modes.
  static const disabled = Color(0xFFD3D1C7);

  @override
  EzColors copyWith({
    Color? bg,
    Color? ink,
    Color? card,
    Color? amber,
    Color? green,
    Color? peach,
    Color? mint,
    Color? lilac,
    Color? positive,
    Color? negative,
  }) => EzColors(
    bg: bg ?? this.bg,
    ink: ink ?? this.ink,
    card: card ?? this.card,
    amber: amber ?? this.amber,
    green: green ?? this.green,
    peach: peach ?? this.peach,
    mint: mint ?? this.mint,
    lilac: lilac ?? this.lilac,
    positive: positive ?? this.positive,
    negative: negative ?? this.negative,
  );

  @override
  EzColors lerp(ThemeExtension<EzColors>? other, double t) {
    if (other is! EzColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return EzColors(
      bg: l(bg, other.bg),
      ink: l(ink, other.ink),
      card: l(card, other.card),
      amber: l(amber, other.amber),
      green: l(green, other.green),
      peach: l(peach, other.peach),
      mint: l(mint, other.mint),
      lilac: l(lilac, other.lilac),
      positive: l(positive, other.positive),
      negative: l(negative, other.negative),
    );
  }
}

extension EzContext on BuildContext {
  EzColors get ez => Theme.of(this).extension<EzColors>()!;
}
