import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_monitor/connection/monitor_controller.dart';
import 'package:pc_monitor/main.dart';

import 'landscape_test.dart' show phoneSize, liveMonitor;

class HistoryMonitor extends MonitorController {
  @override
  Future<void> loadHistory() async {}
}

void main() {
  const channel = MethodChannel('pcmonitor/panel');
  String savedTheme = 'system';
  setUp(() {
    savedTheme = 'system';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getThemeMode') return savedTheme;
      if (call.method == 'setThemeMode') savedTheme = call.arguments as String;
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('tema real cambia claro/oscuro y restaura la preferencia',
      (tester) async {
    phoneSize(tester);
    final monitor = liveMonitor();
    addTearDown(monitor.dispose);
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    await tester.pumpAndSettle();
    for (final (label, brightness) in [
      ('Tema oscuro', Brightness.dark),
      ('Tema claro', Brightness.light),
    ]) {
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.byType(NavigationRail))).brightness,
          brightness);
      await tester.tap(find.text('Gráficas'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(savedTheme, 'light');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light);
  });

  testWidgets('Atrás regresa al panel y permite cancelar salir sin desconectar',
      (tester) async {
    phoneSize(tester);
    final monitor = liveMonitor();
    monitor.activeSession = {'started_at': 1};
    addTearDown(monitor.dispose);
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    await tester.tap(find.text('Gráficas'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('seguirá grabándose'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(monitor.connected, isTrue);
    expect(find.text('Salir de PC Monitor'), findsNothing);
    var exited = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exited = true;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byTooltip('Opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir de la app'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(exited, isTrue);
    expect(monitor.connected, isFalse);
  });

  testWidgets(
      'informe largo conserva cierre visible y Atrás cierra solo informe',
      (tester) async {
    phoneSize(tester);
    final monitor = HistoryMonitor();
    monitor.reports = [
      {
        'host': 'Test PC',
        'started_at': 1,
        'duration_s': 60,
        'sample_count': 60,
        'top_apps': List.generate(30, (i) => {'app': 'App $i'}),
      }
    ];
    addTearDown(monitor.dispose);
    await tester.pumpWidget(PcMonitorApp(controller: monitor));
    await tester.tap(find.text('Sesiones'));
    await tester.pumpAndSettle();
    final report = find.byIcon(Icons.summarize_outlined);
    await tester.ensureVisible(report);
    await tester.tap(report);
    await tester.pumpAndSettle();
    final close = find.byKey(const Key('close-report-button'));
    expect(close.hitTestable(), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(close.hitTestable(), findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('Informe de sesión'), findsNothing);
    await tester.tap(report);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Informe de sesión'), findsNothing);
    expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        3);
    expect(tester.takeException(), isNull);
  });
}
