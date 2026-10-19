import 'package:flutter_test/flutter_test.dart';
import 'package:pc_monitor/models/metric_history.dart';

void main() {
  test('retención por tiempo y huecos explícitos sin muestras inventadas', () {
    final history = MetricHistory();
    final start = DateTime(2026, 10, 18, 12);
    history.add(start, {'cpu': 10});
    history.gap(start.add(const Duration(seconds: 2)));
    history.add(start.add(const Duration(seconds: 5)), {'cpu': 30});
    expect(history.points[1].values['cpu'], isNull);
    expect(validValues(history.points, 'cpu'), [10, 30]);
    history.add(start.add(const Duration(minutes: 6)), {'cpu': 50});
    expect(history.points.length, 1);
  });

  test('escala de tráfico compartida no recorta los picos ni usa porcentajes',
      () {
    final points = [
      MetricPoint(DateTime(2026), {'read': 4096, 'write': 900000})
    ];
    final maximum = rateCeiling(points, ['read', 'write']);
    expect(maximum, greaterThanOrEqualTo(900000));
    expect(maximum, 1024000);
    expect(rateCeiling([], ['read', 'write']), greaterThan(0));
  });
}
