import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'connection/monitor_controller.dart';
import 'screens/dashboard_page.dart';

void main() => runApp(const PcMonitorApp());

class PcMonitorApp extends StatefulWidget {
  const PcMonitorApp({super.key, this.controller});
  final MonitorController? controller;

  @override
  State<PcMonitorApp> createState() => _PcMonitorAppState();
}

class _PcMonitorAppState extends State<PcMonitorApp> {
  static const _preferences = MethodChannel('pcmonitor/panel');
  ThemeMode _mode = ThemeMode.system;
  bool _themeSelected = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final saved = await _preferences.invokeMethod<String>('getThemeMode');
      if (!mounted || _themeSelected) return;
      setState(() => _mode = ThemeMode.values.firstWhere(
          (mode) => mode.name == saved,
          orElse: () => ThemeMode.system));
    } on MissingPluginException {
      // Otras plataformas siguen el sistema hasta incorporar preferencias nativas.
    } on PlatformException {
      // Un fallo de preferencias no debe impedir abrir el panel.
    }
  }

  Future<void> _setTheme(ThemeMode mode) async {
    _themeSelected = true;
    setState(() => _mode = mode);
    try {
      await _preferences.invokeMethod<void>('setThemeMode', mode.name);
    } on MissingPluginException {
      // La selección sigue vigente durante esta ejecución.
    } on PlatformException {
      // Conservar el tema elegido aunque falle el almacenamiento.
    }
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
        useMaterial3: true,
        brightness: brightness,
        scaffoldBackgroundColor: brightness == Brightness.dark
            ? const Color(0xff090e17)
            : const Color(0xfff4f7fa),
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff16836c), brightness: brightness),
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PC Monitor',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: _mode,
        home: DashboardPage(
            controller: widget.controller,
            themeMode: _mode,
            onThemeChanged: _setTheme),
      );
}
