import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_monitor/connection/monitor_controller.dart';
import 'package:pc_monitor/connection/usb_pairing.dart';
import 'package:pc_monitor/screens/dashboard_page.dart';

import 'landscape_test.dart' show phoneSize;

class PairingMonitor extends MonitorController {
  final connections = <String>[];
  @override
  void connect(String url, String token) => connections.add('$url|$token');
}

void main() {
  const channel = MethodChannel('pcmonitor/pairing');
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final accept in [false, true]) {
    testWidgets('conexión USB exige confirmación: aceptar=$accept',
        (tester) async {
      phoneSize(tester);
      final monitor = PairingMonitor();
      addTearDown(monitor.dispose);
      var pending = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (!pending) return null;
        pending = false;
        return 'usb-link';
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(MaterialApp(
          home: DashboardPage(
        controller: monitor,
        pairingLoader: (_) async => const UsbCredentials('ws://127.0.0.1:8766',
            'test-memory-only', 'Windows de prueba', 'Windows'),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Conectar por USB'), findsOneWidget);
      expect(find.textContaining('Windows de prueba'), findsOneWidget);
      expect(find.textContaining('test-memory-only'), findsNothing);
      expect(monitor.connections, isEmpty);
      await tester.tap(find
          .widgetWithText(accept ? FilledButton : TextButton,
              accept ? 'Conectar' : 'Cancelar')
          .last);
      await tester.pumpAndSettle();
      expect(monitor.connections,
          accept ? ['ws://127.0.0.1:8766|test-memory-only'] : isEmpty);
      expect(find.text('Conectar por USB'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
