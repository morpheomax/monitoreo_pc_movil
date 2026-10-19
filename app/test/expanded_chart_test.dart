import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_monitor/connection/monitor_controller.dart';
import 'package:pc_monitor/main.dart';
import 'package:pc_monitor/widgets/metric_chart.dart';

import 'landscape_test.dart' show phoneSize;

class UpdatingMonitor extends MonitorController {
  UpdatingMonitor() {
    status = ConnectionStatus.connected;
    host = 'Test PC';
    metrics = {
      'cpu': {'total': 20},
      'mem': {'used': 50, 'total': 100}
    };
    final end = DateTime.now();
    history
        .add(end.subtract(const Duration(seconds: 30)), {'cpu': 80, 'ram': 50});
    history.add(end, {'cpu': 20, 'ram': 50});
  }

  void sample(double cpu) {
    history.add(DateTime.now(), {'cpu': cpu, 'ram': 50});
    notifyListeners();
  }
}

void main() {
  testWidgets(
      'tocar curva del Panel amplía, actualiza en vivo y X vuelve al Panel',
      (tester) async {
    phoneSize(tester);
    final monitor = UpdatingMonitor();
    addTearDown(monitor.dispose);
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    final plot = find.byKey(const ValueKey('chart-CPU y RAM'));
    final small = tester.getRect(plot);
    await tester.tap(plot);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expanded-chart-page')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getRect(plot).width, greaterThan(small.width * 1.7));
    expect(tester.getRect(plot).height, greaterThan(100));
    await tester.tap(plot);
    await tester.pump();
    expect(find.textContaining('CPU: 80.0 %'), findsOneWidget);
    expect(find.byKey(const Key('expanded-chart-page')), findsOneWidget);
    monitor.sample(99);
    await tester.pump();
    expect(find.text('CPU  99.0 %'), findsOneWidget);
    await tester.tap(find.byKey(const Key('close-expanded-chart')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        0);
    expect(monitor.connected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CPU, disco y red amplían; Atrás conserva destino y ventana seleccionada',
      (tester) async {
    phoneSize(tester);
    final monitor = UpdatingMonitor();
    // Proveer ambas series para disco/red, incluidas escalas automáticas.
    monitor.history.add(DateTime.now(), {
      'cpu': 20,
      'ram': 50,
      'disk_read': 1024,
      'disk_write': 512,
      'net_down': 2048,
      'net_up': 1024
    });
    addTearDown(monitor.dispose);
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    await tester.tap(find.text('Gráficas'));
    await tester.pumpAndSettle();
    for (final title in ['CPU y RAM', 'Actividad de disco', 'Tráfico de red']) {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expanded-chart-page')), findsOneWidget);
      await tester.tap(find.text('5 min'));
      await tester.pumpAndSettle();
      expect(tester.widget<MetricChart>(find.byType(MetricChart)).window,
          const Duration(minutes: 5));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<NavigationRail>(find.byType(NavigationRail))
              .selectedIndex,
          1);
    }
    expect(
        tester
            .widget<SegmentedButton<int>>(find.byKey(const Key('chart-window')))
            .selected,
        {5});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'sin datos y texto grande conserva X accesible y no inventa valores',
      (tester) async {
    phoneSize(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const PcMonitorApp());
    await tester.tap(find.text('Gráficas'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('CPU y RAM'), 180,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('CPU y RAM'));
    await tester.pumpAndSettle();
    expect(find.text('Esperando muestras…'), findsOneWidget);
    expect(find.text('CPU  —'), findsOneWidget);
    final close = find.byKey(const Key('close-expanded-chart'));
    expect(close.hitTestable(), findsOneWidget);
    await tester.drag(
        find.byType(SingleChildScrollView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(close.hitTestable(), findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expanded-chart-page')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
