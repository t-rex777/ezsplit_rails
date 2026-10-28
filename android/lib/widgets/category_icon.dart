import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Explicit map rather than the package's full name map, which would stop the
// icon font from being tree-shaken.
const _icons = <String, IconData>{
  'restaurant': Symbols.restaurant,
  'flight': Symbols.flight,
  'home': Symbols.home,
  'hotel': Symbols.hotel,
  'local_taxi': Symbols.local_taxi,
  'shopping_cart': Symbols.shopping_cart,
  'bolt': Symbols.bolt,
  'local_cafe': Symbols.local_cafe,
  'directions_car': Symbols.directions_car,
  'redeem': Symbols.redeem,
  'movie': Symbols.movie,
  'favorite': Symbols.favorite,
  'more_horiz': Symbols.more_horiz,
  'lunch_dining': Symbols.lunch_dining,
  'cookie': Symbols.cookie,
  'group': Symbols.group,
  'work': Symbols.work,
  'sports_soccer': Symbols.sports_soccer,
};

class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.iconName, this.color, {super.key, this.size = 24});

  final String iconName;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      _icons[iconName] ?? Symbols.more_horiz,
      color: color,
      size: size,
    );
  }
}
