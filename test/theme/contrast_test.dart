import 'dart:math';

import 'package:ezsplit_mobile/theme/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _channel(double v) =>
    v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  test('light card is white', () {
    expect(EzColors.light.card, const Color(0xFFFFFFFF));
  });

  for (final entry in {
    'light': EzColors.light,
    'dark': EzColors.dark,
  }.entries) {
    final c = entry.value;
    test('${entry.key} positive money has 4.5:1 on card', () {
      expect(contrast(c.positive, c.card), greaterThanOrEqualTo(4.5));
    });
    test('${entry.key} negative money has 4.5:1 on card', () {
      expect(contrast(c.negative, c.card), greaterThanOrEqualTo(4.5));
    });
  }

  test('light ink has 4.5:1 on every accent fill', () {
    final c = EzColors.light;
    for (final fill in [c.amber, c.green, c.peach, c.mint, c.lilac]) {
      expect(contrast(c.ink, fill), greaterThanOrEqualTo(4.5), reason: '$fill');
    }
  });

  test('ink text on the disabled grey has 4.5:1', () {
    expect(
      contrast(EzColors.light.ink, EzColors.disabled),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('onAccent has 4.5:1 on every accent fill and the disabled grey', () {
    final fills = [
      for (final c in [EzColors.light, EzColors.dark]) ...[
        c.amber,
        c.green,
        c.peach,
        c.mint,
        c.lilac,
      ],
      EzColors.disabled,
    ];
    for (final fill in fills) {
      expect(
        contrast(onAccent, fill),
        greaterThanOrEqualTo(4.5),
        reason: '$fill',
      );
    }
  });
}
