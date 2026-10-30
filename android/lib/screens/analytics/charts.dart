import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../data/models.dart';
import '../../domain/analytics.dart';
import '../../domain/money.dart';
import '../../theme/tokens.dart';

const double _step = 50;
const double _barWidth = 26;
const double _barInset = (_step - _barWidth) / 2;
const double _plotTop = 30;
const double _plotHeight = 170;
const double _axisHeight = 44;
const double barChartHeight = _plotTop + _plotHeight + _axisHeight;

/// A round chart top in paise, split into three equal gridline steps.
int niceTopPaise(int maxPaise) {
  if (maxPaise <= 0) return 300000;
  final raw = maxPaise / 100 / 3;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final step = [
    1,
    2,
    5,
    10,
  ].map((m) => m * magnitude).firstWhere((s) => s >= raw);
  // Whole rupees per step, so axis labels never show paise.
  return (math.max(step, 1) * 3 * 100).round();
}

/// "5k", "1.5L" (lakh), "800".
String compactRupees(int paise) {
  final rupees = paise / 100;
  String trim(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  if (rupees >= 100000) return '${trim(rupees / 100000)}L';
  if (rupees >= 1000) return '${trim(rupees / 1000)}k';
  return rupees.round().toString();
}

/// One stacked bar per month, oldest on the left, with a trend line over the
/// tops. Scrolls sideways and opens on the newest month.
class MonthlyBarChart extends StatefulWidget {
  const MonthlyBarChart({
    super.key,
    required this.months,
    required this.order,
    required this.colors,
    required this.other,
    required this.selected,
    required this.onSelect,
  });

  final List<AnalyticsMonth> months;

  /// Category keys with their own colour, bottom of the bar first. The rest of
  /// each month stacks on top as [other].
  final List<String> order;
  final Map<String, Color> colors;
  final Color other;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  State<MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<MonthlyBarChart> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(MonthlyBarChart old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected ||
        old.months.length != widget.months.length) {
      _revealSelected();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the picked bar into view when it is off screen, for example after
  /// a filter change rebuilds the chart at the newest month.
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final i = widget.selected;
      if (i == null || !_scroll.hasClients) return;
      final position = _scroll.position;
      final width = widget.months.length * _step;
      // The list is reversed, so offset 0 shows the right end.
      final left = width - position.pixels - position.viewportDimension;
      final barLeft = i * _step;
      if (barLeft >= left &&
          barLeft + _step <= left + position.viewportDimension) {
        return;
      }
      final target =
          width - barLeft - _step / 2 - position.viewportDimension / 2;
      _scroll.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    final order = widget.order;
    final colors = widget.colors;
    final other = widget.other;
    final selected = widget.selected;
    final onSelect = widget.onSelect;
    final c = context.ez;
    final text = Theme.of(context).textTheme;
    final top = niceTopPaise(
      months.fold(0, (m, e) => math.max(m, e.totalPaise)),
    );
    final labelStyle = text.labelSmall?.copyWith(color: c.ink, fontSize: 11);
    double yOf(int paise) => _plotTop + _plotHeight - paise * _plotHeight / top;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 34,
            height: barChartHeight,
            child: Stack(
              children: [
                for (var i = 0; i <= 3; i++)
                  Positioned(
                    right: 4,
                    top: yOf(top * i ~/ 3) - 8,
                    child: Text(compactRupees(top * i ~/ 3), style: labelStyle),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: SizedBox(
              width: months.length * _step,
              height: barChartHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BarsPainter(
                        months: months,
                        order: order,
                        colors: colors,
                        selected: selected,
                        top: top,
                        ink: c.ink,
                        line: c.line,
                        dot: c.card,
                        pillText: c.bg,
                        labelStyle: labelStyle ?? const TextStyle(),
                        other: other,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < months.length; i++)
                        Semantics(
                          button: true,
                          selected: i == selected,
                          label:
                              '${DateFormat('MMMM y').format(months[i].month)}, '
                              '${formatRupees(months[i].totalPaise)}',
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: ValueKey(
                              'bar-${DateFormat('y-MM').format(months[i].month)}',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelect(i),
                            child: const SizedBox(
                              width: _step,
                              height: barChartHeight,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.months,
    required this.order,
    required this.colors,
    required this.selected,
    required this.top,
    required this.ink,
    required this.line,
    required this.dot,
    required this.pillText,
    required this.labelStyle,
    required this.other,
  });

  final List<AnalyticsMonth> months;
  final List<String> order;
  final Map<String, Color> colors;
  final int? selected;
  final int top;
  final Color ink;
  final Color line;
  final Color dot;
  final Color pillText;
  final TextStyle labelStyle;
  final Color other;

  double _y(int paise) => _plotTop + _plotHeight - paise * _plotHeight / top;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = ink.withValues(alpha: 0.15)
      ..strokeWidth = 1.5;
    for (var i = 1; i <= 3; i++) {
      final y = _y(top * i ~/ 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..color = line
      ..strokeWidth = 1.5;
    final points = <Offset>[];
    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final x = i * _step + _barInset;
      final faded = selected != null && i != selected;
      final byKey = {for (final c in m.categories) categoryKey(c.name): c};
      var acc = 0;
      for (final key in order) {
        final c = byKey[key];
        if (c == null || c.paise <= 0) continue;
        final rect = Rect.fromLTRB(
          x,
          _y(acc + c.paise),
          x + _barWidth,
          _y(acc),
        );
        final color = colors[key] ?? other;
        canvas.drawRect(
          rect,
          Paint()..color = faded ? color.withValues(alpha: 0.35) : color,
        );
        canvas.drawRect(rect, outline);
        acc += c.paise;
      }
      final rest = m.totalPaise - acc;
      if (rest > 0) {
        final rect = Rect.fromLTRB(x, _y(acc + rest), x + _barWidth, _y(acc));
        canvas.drawRect(
          rect,
          Paint()..color = faded ? other.withValues(alpha: 0.35) : other,
        );
        canvas.drawRect(rect, outline);
        acc += rest;
      }
      if (i == selected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(x - 3, _y(acc) - 3, x + _barWidth + 3, _y(0)),
            const Radius.circular(3),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..color = line
            ..strokeWidth = 3,
        );
      }
      points.add(Offset(x + _barWidth / 2, _y(acc) - 14));
      _monthLabel(canvas, i, x);
    }

    canvas.drawLine(
      Offset(0, _y(0)),
      Offset(size.width, _y(0)),
      Paint()
        ..color = line
        ..strokeWidth = 2.5,
    );

    if (points.length > 1) {
      canvas.drawPath(
        Path()..addPolygon(points, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = ink
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = dot);
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = ink
          ..strokeWidth = 2,
      );
    }
  }

  void _monthLabel(Canvas canvas, int i, double x) {
    final month = months[i].month;
    final picked = i == selected;
    final label = TextPainter(
      text: TextSpan(
        text: DateFormat('MMM').format(month),
        style: labelStyle.copyWith(
          color: picked ? pillText : ink,
          fontWeight: picked ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final cx = x + _barWidth / 2;
    final baseline = _plotTop + _plotHeight;
    if (picked) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 8, baseline + 8, _barWidth + 16, 20),
          const Radius.circular(10),
        ),
        Paint()..color = ink,
      );
    }
    label.paint(
      canvas,
      Offset(cx - label.width / 2, baseline + 18 - label.height / 2),
    );
    if (i == 0 || month.month == 1) {
      final year = TextPainter(
        text: TextSpan(
          text: '${month.year}',
          style: labelStyle.copyWith(
            fontSize: 10,
            color: ink.withValues(alpha: 0.75),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      year.paint(canvas, Offset(cx - year.width / 2, baseline + 30));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.months != months ||
      old.selected != selected ||
      old.colors != colors ||
      old.ink != ink;
}

/// A ring split into [slices], drawn clockwise from the top.
class Donut extends StatelessWidget {
  const Donut({super.key, required this.slices, required this.child});

  final List<({int paise, Color color})> slices;

  /// Shown in the hole.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DonutPainter(slices: slices, line: context.ez.line),
            ),
          ),
          SizedBox(width: 100, child: child),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.line});

  final List<({int paise, Color color})> slices;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const ring = 34.0;
    const radius = 70.0;
    final total = slices.fold<int>(0, (sum, s) => sum + s.paise);
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -math.pi / 2;
    final edges = <double>[];
    if (total > 0) {
      for (final s in slices) {
        final sweep = 2 * math.pi * s.paise / total;
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ring
            ..color = s.color,
        );
        edges.add(start);
        start += sweep;
      }
    }
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = line
      ..strokeWidth = 2.5;
    if (edges.length > 1) {
      for (final a in edges) {
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          center + dir * (radius - ring / 2),
          center + dir * (radius + ring / 2),
          border..strokeWidth = 2,
        );
      }
    }
    canvas.drawCircle(center, radius + ring / 2, border..strokeWidth = 2.5);
    canvas.drawCircle(center, radius - ring / 2, border);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.line != line;
}
