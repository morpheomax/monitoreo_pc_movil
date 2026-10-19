import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/metric_history.dart';

class ChartSeries {
  const ChartSeries(this.key, this.label, this.color);
  final String key;
  final String label;
  final Color color;
}

class MetricChart extends StatefulWidget {
  const MetricChart(
      {super.key,
      required this.title,
      required this.points,
      required this.series,
      required this.window,
      required this.formatValue,
      this.fixedMaximum,
      this.caption,
      this.compact = false,
      this.expanded = false,
      this.onExpand})
      : assert(!compact || !expanded);
  final String title;
  final List<MetricPoint> points;
  final List<ChartSeries> series;
  final Duration window;
  final String Function(double?) formatValue;
  final double? fixedMaximum;
  final String? caption;
  final bool compact;
  final bool expanded;
  final VoidCallback? onExpand;

  @override
  State<MetricChart> createState() => _MetricChartState();
}

class _MetricChartState extends State<MetricChart> {
  DateTime? _selectedTime;

  @override
  void didUpdateWidget(MetricChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.window != widget.window) _selectedTime = null;
  }

  @override
  Widget build(BuildContext context) {
    final end =
        widget.points.isEmpty ? DateTime.now() : widget.points.last.time;
    final start = end.subtract(widget.window);
    final points =
        widget.points.where((point) => !point.time.isBefore(start)).toList();
    final maximum = widget.fixedMaximum ??
        rateCeiling(points, widget.series.map((series) => series.key).toList());
    MetricPoint? selected;
    if (_selectedTime != null && !_selectedTime!.isBefore(start)) {
      var closest = const Duration(days: 1);
      for (final point in points) {
        final distance = point.time.difference(_selectedTime!).abs();
        if (distance < closest) {
          selected = point;
          closest = distance;
        }
      }
      if (closest > const Duration(seconds: 2)) selected = null;
    }
    final hasValues = widget.series
        .any((series) => validValues(points, series.key).isNotEmpty);
    final compact = widget.compact;
    final axisWidth = compact ? 48.0 : 65.0;
    final axisStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(fontSize: compact ? 9 : null);
    Widget plot() => Row(children: [
          SizedBox(
              width: axisWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final fraction in [1.0, .5, 0.0])
                    Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(widget.formatValue(maximum * fraction),
                              maxLines: 1, style: axisStyle),
                        )),
                ],
              )),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            void select(Offset position) {
              final fraction =
                  (position.dx / constraints.maxWidth).clamp(0.0, 1.0);
              setState(() => _selectedTime = start.add(Duration(
                  milliseconds:
                      (widget.window.inMilliseconds * fraction).round())));
            }

            return Semantics(
              label:
                  '${widget.title}. Escala de cero a ${widget.formatValue(maximum)}. ${widget.onExpand != null ? 'Toca para ampliar.' : 'Toca para consultar una muestra.'}',
              child: GestureDetector(
                key: ValueKey('chart-${widget.title}'),
                onTapDown: widget.onExpand == null
                    ? (details) => select(details.localPosition)
                    : null,
                onHorizontalDragUpdate: widget.onExpand == null
                    ? (details) => select(details.localPosition)
                    : null,
                onLongPress: widget.onExpand == null
                    ? () => setState(() => _selectedTime = null)
                    : null,
                child: SizedBox.expand(
                    child: CustomPaint(
                        painter: _ChartPainter(
                  points: points,
                  series: widget.series,
                  start: start,
                  end: end,
                  maximum: maximum,
                  selectedTime: _selectedTime,
                  foreground: Theme.of(context).colorScheme.onSurface,
                ))),
              ),
            );
          })),
        ]);
    final legend = widget.series.map((series) {
      final values = validValues(points, series.key);
      final latest = points.isEmpty ? null : points.last.values[series.key];
      final average = values.isEmpty
          ? null
          : values.reduce((a, b) => a + b) / values.length;
      final peak = values.isEmpty ? null : values.reduce(math.max);
      final label = '${series.label}  ${widget.formatValue(latest)}';
      final stats =
          'Media ${widget.formatValue(average)} · Pico ${widget.formatValue(peak)}';
      return Padding(
          padding: EdgeInsets.only(bottom: compact ? 4 : 0),
          child: Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
            children: [
              Row(
                  mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Icon(Icons.show_chart,
                        size: compact ? 12 : 16, color: series.color),
                    const SizedBox(width: 5),
                    if (compact)
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(label,
                                  maxLines: 1,
                                  style: TextStyle(
                                      color: series.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))))
                    else
                      Text(label,
                          style: TextStyle(
                              color: series.color,
                              fontWeight: FontWeight.bold)),
                  ]),
              if (compact)
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(stats,
                        maxLines: 1, style: const TextStyle(fontSize: 10)))
              else
                Text(stats, style: Theme.of(context).textTheme.bodySmall),
            ],
          ));
    }).toList();
    final selection = _selectedTime != null && !_selectedTime!.isBefore(start)
        ? selected == null || selected.values.isEmpty
            ? 'Sin muestra en ese instante'
            : '${_clock(selected.time)} · ${widget.series.map((series) => '${series.label}: ${widget.formatValue(selected!.values[series.key])}').join(' · ')}'
        : widget.onExpand != null
            ? 'Toca para ampliar'
            : compact
                ? 'Toca para consultar'
                : 'Toca o desliza sobre la curva para ver un valor.';
    return Card(
        child: InkWell(
            onTap: widget.onExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: EdgeInsets.all(compact ? 10 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.expanded) ...[
                      Row(children: [
                        Expanded(
                            child: Text(widget.title,
                                maxLines: compact ? 1 : null,
                                overflow:
                                    compact ? TextOverflow.ellipsis : null,
                                style: compact
                                    ? const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)
                                    : Theme.of(context).textTheme.titleMedium)),
                        if (widget.onExpand != null)
                          const Icon(Icons.fullscreen, size: 18),
                      ]),
                      SizedBox(height: compact ? 6 : 12),
                    ],
                    if (compact)
                      ...legend
                    else
                      Wrap(spacing: 20, runSpacing: 10, children: legend),
                    SizedBox(height: compact ? 6 : 18),
                    if (compact || widget.expanded)
                      Expanded(
                          child: hasValues
                              ? plot()
                              : const Center(
                                  child: Text('Esperando muestras…',
                                      style: TextStyle(fontSize: 11))))
                    else
                      SizedBox(
                          height: 150,
                          child: hasValues
                              ? plot()
                              : const Center(
                                  child: Text('Esperando muestras…'))),
                    Padding(
                        padding: EdgeInsets.only(left: axisWidth, top: 5),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final (label, alignment) in [
                                (
                                  '-${widget.window.inMinutes} min',
                                  Alignment.centerLeft
                                ),
                                (
                                  '-${widget.window.inSeconds ~/ 2} s',
                                  Alignment.center
                                ),
                                ('Ahora', Alignment.centerRight),
                              ])
                                Expanded(
                                    child: Align(
                                        alignment: alignment,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(label,
                                              maxLines: 1, style: axisStyle),
                                        ))),
                            ])),
                    SizedBox(height: compact ? 4 : 12),
                    if (compact)
                      SizedBox(
                          height: 26,
                          child: Text(selection,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10)))
                    else
                      Text(selection,
                          style: Theme.of(context).textTheme.bodySmall),
                    if (!compact && !widget.expanded && widget.caption != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(widget.caption!,
                              style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ))));
  }
}

String _clock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

class _ChartPainter extends CustomPainter {
  _ChartPainter(
      {required this.points,
      required this.series,
      required this.start,
      required this.end,
      required this.maximum,
      required this.foreground,
      this.selectedTime});
  final List<MetricPoint> points;
  final List<ChartSeries> series;
  final DateTime start;
  final DateTime end;
  final double maximum;
  final Color foreground;
  final DateTime? selectedTime;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final grid = Paint()
      ..color = foreground.withValues(alpha: .13)
      ..strokeWidth = 1;
    for (final fraction in [0.0, .25, .5, .75, 1.0]) {
      canvas.drawLine(Offset(0, size.height * fraction),
          Offset(size.width, size.height * fraction), grid);
      canvas.drawLine(Offset(size.width * fraction, 0),
          Offset(size.width * fraction, size.height), grid);
    }
    double x(DateTime time) =>
        time.difference(start).inMilliseconds /
        end.difference(start).inMilliseconds *
        size.width;
    for (final entry in series) {
      final path = Path();
      DateTime? previous;
      for (final point in points) {
        final value = point.values[entry.key];
        if (value == null || !value.isFinite || value < 0) {
          previous = null;
          continue;
        }
        final position = Offset(x(point.time),
            size.height * (1 - (value / maximum).clamp(0.0, 1.0)));
        // No unir tramos separados por suspensión o pérdida de conexión.
        if (previous == null ||
            point.time.difference(previous) > const Duration(seconds: 3)) {
          path.moveTo(position.dx, position.dy);
        } else {
          path.lineTo(position.dx, position.dy);
        }
        canvas.drawCircle(position, 1.8, Paint()..color = entry.color);
        previous = point.time;
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = entry.color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }
    if (selectedTime != null && !selectedTime!.isBefore(start)) {
      final markerX = x(selectedTime!);
      canvas.drawLine(
          Offset(markerX, 0),
          Offset(markerX, size.height),
          Paint()
            ..color = foreground.withValues(alpha: .7)
            ..strokeWidth = 1);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) => true;
}
