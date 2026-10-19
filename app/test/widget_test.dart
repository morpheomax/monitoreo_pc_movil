import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_monitor/connection/monitor_controller.dart';
import 'package:pc_monitor/main.dart';

void main() {
  testWidgets('muestra panel desconectado y exige token del computador',
      (tester) async {
    await tester.pumpWidget(const PcMonitorApp());
    expect(find.textContaining('PC Monitor'), findsOneWidget);
    expect(find.text('Sin equipo conectado'), findsOneWidget);
    await tester.tap(find.byKey(const Key('connect-button')));
    await tester.pump();
    expect(find.text('Escribe el token que muestra el computador.'),
        findsOneWidget);
    expect(find.text('Conectado'), findsNothing);
  });

  testWidgets('procesos se pueden buscar sin confundir datos ausentes con cero',
      (tester) async {
    final controller = MonitorController();
    addTearDown(controller.dispose);
    controller.status = ConnectionStatus.connected;
    controller.metrics = {
      'cpu': {'total': 10},
      'mem': {'used': 50, 'total': 100}
    };
    controller.processes = [
      {'app': 'Browser', 'cpu': 20, 'mem': 200, 'count': 2},
      {'app': 'Editor', 'cpu': 10, 'mem': 100, 'count': 1},
    ];
    await tester.pumpWidget(PcMonitorApp(controller: controller));
    await tester.tap(find.text('Procesos'));
    await tester.pumpAndSettle();
    expect(find.text('Browser'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('process-search')), 'editor');
    await tester.pump();
    expect(find.text('Browser'), findsNothing);
    expect(find.text('Editor'), findsOneWidget);
  });

  testWidgets('gráficas ofrecen ventanas y escalas sin datos inventados',
      (tester) async {
    await tester.pumpWidget(const PcMonitorApp());
    await tester.tap(find.text('Gráficas'));
    await tester.pumpAndSettle();
    expect(find.text('Tendencias en vivo'), findsOneWidget);
    expect(find.text('CPU y RAM'), findsOneWidget);
    await tester.tap(find.text('5 min'));
    await tester.pumpAndSettle();
    expect(find.text('-5 min'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel funciona en horizontal sin desbordamiento',
      (tester) async {
    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PcMonitorApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Sesiones'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Todavía no hay informes.'));
    expect(find.text('Todavía no hay informes.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
