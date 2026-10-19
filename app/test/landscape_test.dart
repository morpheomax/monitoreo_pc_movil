import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_monitor/connection/monitor_controller.dart';
import 'package:pc_monitor/main.dart';

MonitorController liveMonitor() {
  final monitor = MonitorController();
  monitor.status = ConnectionStatus.connected;
  monitor.host = 'MacBook-Air-de-Maximiliano.local';
  monitor.sessionKnown = true;
  monitor.capabilities = {'metrics', 'processes', 'sessions', 'history'};
  monitor.metrics = {
    'cpu': {
      'total': 25,
      'per_core': [20, 30, 25, 35, 10, 15, 30, 35]
    },
    'mem': {'used': 4e9, 'total': 8e9, 'swap_used': 1e9},
    'disk': {'read_bps': 3e6, 'write_bps': 2e6},
    'net': {'down_bps': 1e6, 'up_bps': 2e5},
    'battery': {'percent': 50, 'charging': true},
    'temps': {'data': null},
  };
  final end = DateTime.now();
  for (var second = 30; second >= 0; second--) {
    monitor.history.add(end.subtract(Duration(seconds: second)), {
      'cpu': 25,
      'ram': 50,
      'disk_read': 3e6,
      'disk_write': 2e6,
      'net_down': 1e6,
      'net_up': 2e5,
    });
  }
  monitor.processes = [
    {'app': 'Browser', 'cpu': 20, 'mem': 200, 'count': 2},
    {'app': 'Editor', 'cpu': 10, 'mem': 100, 'count': 1},
  ];
  return monitor;
}

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(832, 384);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(left: 24, right: 48, top: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

void main() {
  testWidgets('panel Samsung muestra seis métricas y curva sin desplazamiento',
      (tester) async {
    phoneSize(tester);
    final monitor = liveMonitor();
    addTearDown(monitor.dispose);
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    for (final label in [
      'CPU',
      'RAM',
      'DISCO',
      'RED',
      'BATERÍA PC',
      'TEMPERATURA'
    ]) {
      expect(find.text(label), findsOneWidget);
      expect(tester.getRect(find.text(label)).bottom, lessThan(384));
    }
    expect(find.byKey(const ValueKey('chart-CPU y RAM')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tres gráficas completas caben lado a lado con márgenes del sistema',
      (tester) async {
    phoneSize(tester);
    final monitor = liveMonitor();
    addTearDown(monitor.dispose);
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    await tester.tap(find.text('Gráficas'));
    await tester.pumpAndSettle();
    final plots = [
      for (final title in ['CPU y RAM', 'Actividad de disco', 'Tráfico de red'])
        tester.getRect(find.byKey(ValueKey('chart-$title')))
    ];
    expect(plots[0].right, lessThan(plots[1].left));
    expect(plots[1].right, lessThan(plots[2].left));
    for (final plot in plots) {
      expect(plot.height, greaterThan(50));
      expect(plot.bottom, lessThan(384));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('teclado conserva acceso al formulario y navegación',
      (tester) async {
    phoneSize(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const PcMonitorApp());
    await tester.ensureVisible(find.byKey(const Key('token-field')));
    await tester.enterText(find.byKey(const Key('token-field')), 'token');
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('texto grande conserva lectura mediante vista desplazable',
      (tester) async {
    phoneSize(tester);
    final monitor = liveMonitor();
    addTearDown(monitor.dispose);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    await tester.tap(find.text('Gráficas'));
    await tester.pumpAndSettle();
    expect(find.text('CPU y RAM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
