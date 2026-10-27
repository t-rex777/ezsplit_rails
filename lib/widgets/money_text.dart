import 'package:flutter/material.dart';

import '../domain/money.dart';
import '../theme/tokens.dart';

/// plain: "₹600". signed: "+₹600" / "−₹180". owesGets: "gets ₹900" / "owes ₹450".
enum MoneyStyle { plain, signed, owesGets }

/// Shows [paise] as rupees. For signed and owesGets, positive means the user
/// is owed money; the sign or word always accompanies the colour.
class MoneyText extends StatelessWidget {
  const MoneyText(this.paise, {super.key, this.style = MoneyStyle.plain});

  final int paise;
  final MoneyStyle style;

  @override
  Widget build(BuildContext context) {
    final c = context.ez;
    final abs = formatRupees(paise.abs());
    final (String text, Color color) = switch (style) {
      MoneyStyle.plain => (formatRupees(paise), c.ink),
      MoneyStyle.signed when paise > 0 => ('+$abs', c.positive),
      MoneyStyle.signed when paise < 0 => ('−$abs', c.negative),
      MoneyStyle.signed => (abs, c.ink),
      MoneyStyle.owesGets when paise > 0 => ('gets $abs', c.positive),
      MoneyStyle.owesGets when paise < 0 => ('owes $abs', c.negative),
      MoneyStyle.owesGets => ('settled up', c.ink),
    };
    return Text(
      text,
      softWrap: false,
      overflow: TextOverflow.visible,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: color, fontWeight: FontWeight.w700),
    );
  }
}
