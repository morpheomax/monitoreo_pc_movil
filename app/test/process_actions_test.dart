import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_monitor/connection/monitor_controller.dart';
import 'package:pc_monitor/main.dart';

import 'landscape_test.dart' show phoneSize;

class ActionMonitor extends MonitorController {
  int preparations = 0;
  final List<bool> signals = [];
  bool failAction = false;

  ActionMonitor() {
    status = ConnectionStatus.connected;
    capabilities = {'metrics', 'processes', 'process_actions'};
    metrics = {
      'cpu': {'total': 5},
      'mem': {'used': 1, 'total': 10}
    };
    processes = [
      {
        'app': 'Worker',
        'cpu': 5,
        'mem': 100,
        'count': 2,
        'members': [
          {
            'pid': 123,
            'name': 'worker',
            'exe': '/Applications/Worker.app/worker',
            'create_time': 10,
            'can_terminate': true
          },
          {
            'pid': 1,
            'name': 'launchd',
            'exe': '/sbin/launchd',
            'create_time': 1,
            'can_terminate': false,
            'blocked_reason': 'Proceso protegido.'
          },
        ],
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> prepareProcess(
      Map<String, dynamic> member) async {
    preparations++;
    return {'ticket': 'ticket', 'process': member};
  }

  @override
  Future<Map<String, dynamic>> terminateProcess(String ticket,
      {required bool force}) async {
    signals.add(force);
    if (failAction) throw StateError('El proceso cambió.');
    return {'status': 'terminated', 'message': 'Proceso finalizado.'};
  }
}

void main() {
  testWidgets('Procesos exige elegir PID y confirmar; cancelar no envía cierre',
      (tester) async {
    phoneSize(tester);
    final monitor = ActionMonitor();
    addTearDown(monitor.dispose);
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    await tester.tap(find.text('Procesos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gestionar procesos de Worker'));
    await tester.pumpAndSettle();
    expect(find.text('Proceso protegido.'), findsOneWidget);
    expect(find.byKey(const ValueKey('terminate-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('terminate-123')));
    await tester.pumpAndSettle();
    expect(find.text('PID 123'), findsOneWidget);
    expect(monitor.signals, isEmpty);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(monitor.signals, isEmpty);
    await tester.tap(find.byKey(const ValueKey('terminate-123')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(monitor.signals, [false]);
    expect(find.text('Finalizado'), findsOneWidget);
    expect(find.byKey(const ValueKey('terminate-123')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forzar es explícito y un rechazo no se reintenta',
      (tester) async {
    phoneSize(tester);
    final monitor = ActionMonitor()..failAction = true;
    addTearDown(monitor.dispose);
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    await tester.tap(find.text('Procesos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gestionar procesos de Worker'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('terminate-123')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forzar cierre'));
    await tester.pumpAndSettle();
    expect(monitor.signals, [true]);
    expect(find.text('El proceso cambió.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(monitor.signals, [true]);
    expect(tester.takeException(), isNull);
  });
}
