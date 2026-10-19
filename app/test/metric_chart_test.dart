import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_monitor/models/metric_history.dart';
import 'package:pc_monitor/widgets/metric_chart.dart';

void main() {
  testWidgets('gráfica conserva escala 0–100 y consulta el valor tocado',
      (tester) async {
    final end = DateTime(2026, 10, 18, 12, 1);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MetricChart(
      title: 'CPU',
      points: [
        MetricPoint(end.subtract(const Duration(seconds: 30)), {'cpu': 80}),
        MetricPoint(end, {'cpu': 20})
      ],
      series: const [ChartSeries('cpu', 'CPU', Colors.green)],
      window: const Duration(minutes: 1),
      fixedMaximum: 100,
      formatValue: (value) =>
          value == null ? '—' : '${value.toStringAsFixed(0)} %',
    ))));
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('Media 50 % · Pico 80 %'), findsOneWidget);
    final rect = tester.getRect(find.byKey(const ValueKey('chart-CPU')));
    await tester.tapAt(Offset(rect.center.dx, rect.center.dy));
    await tester.pump();
    expect(find.text('12:00:30 · CPU: 80 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gráfica sin muestras muestra espera sin cero ficticio',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MetricChart(
      title: 'Disco',
      points: const [],
      series: const [ChartSeries('read', 'Lectura', Colors.blue)],
      window: const Duration(minutes: 5),
      formatValue: (value) => value?.toString() ?? '—',
    ))));
    expect(find.text('Esperando muestras…'), findsOneWidget);
    expect(find.text('Media — · Pico —'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
