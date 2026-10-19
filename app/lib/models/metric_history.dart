/// Muestras recibidas por el teléfono; los huecos de conexión no son ceros.
class MetricPoint {
  const MetricPoint(this.time, this.values);
  final DateTime time;
  final Map<String, double?> values;
}

class MetricHistory {
  static const retention = Duration(minutes: 5);
  final List<MetricPoint> _points = [];
  List<MetricPoint> get points => List.unmodifiable(_points);

  void add(DateTime time, Map<String, double?> values) {
    _points.add(MetricPoint(time, Map.unmodifiable(values)));
    _points
        .removeWhere((point) => point.time.isBefore(time.subtract(retention)));
    // El agente admite 0.5 s; dejar margen sin permitir crecimiento ilimitado.
    if (_points.length > 650) _points.removeRange(0, _points.length - 650);
  }

  void gap(DateTime time) {
    if (_points.isNotEmpty) add(time, const {});
  }

  void clear() => _points.clear();
}

List<double> validValues(List<MetricPoint> points, String key) => points
    .map((point) => point.values[key])
    .whereType<double>()
    .where((value) => value.isFinite && value >= 0)
    .toList();

/// Escala única para ambas curvas, estable y legible en unidades binarias.
double rateCeiling(List<MetricPoint> points, List<String> keys) {
  var peak = 0.0;
  for (final key in keys) {
    for (final value in validValues(points, key)) {
      if (value > peak) peak = value;
    }
  }
  var unit = 1024.0;
  while (peak > unit * 1000) {
    unit *= 1024;
  }
  for (final step in [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000]) {
    if (peak <= unit * step) return unit * step;
  }
  return unit * 1000;
}
