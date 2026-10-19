import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../connection/monitor_controller.dart';
import '../connection/usb_pairing.dart';
import 'process_details_sheet.dart';
import 'expanded_chart_page.dart';
import '../widgets/metric_chart.dart';
import '../widgets/landscape_shell.dart';
import '../models/metric_history.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage(
      {super.key,
      this.controller,
      this.pairingLoader = fetchUsbCredentials,
      this.themeMode = ThemeMode.system,
      this.onThemeChanged});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final MonitorController? controller;
  final Future<UsbCredentials> Function(String) pairingLoader;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  late final MonitorController monitor;
  final _token = TextEditingController();
  final _url = TextEditingController(text: 'ws://127.0.0.1:8765');
  static const _panelChannel = MethodChannel('pcmonitor/panel');
  static const _pairingChannel = MethodChannel('pcmonitor/pairing');
  bool _pairingBusy = false;
  bool _pairingAgain = false;
  int _tab = 0;
  Duration _chartWindow = const Duration(minutes: 1);
  bool _busy = false;
  bool _showToken = false;
  bool _keepAwake = true;
  bool _awake = false;
  bool _exitDialogOpen = false;
  String _query = '';
  String _sort = 'mem';

  @override
  void initState() {
    super.initState();
    monitor = widget.controller ?? MonitorController();
    monitor.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _pairingChannel.setMethodCallHandler((call) async {
      if (call.method == 'available') await _receiveUsbPairing();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _receiveUsbPairing());
  }

  Future<void> _receiveUsbPairing() async {
    if (!mounted) return;
    if (_pairingBusy) {
      _pairingAgain = true;
      return;
    }
    _pairingBusy = true;
    try {
      final link = await _pairingChannel.invokeMethod<String>('consume');
      if (link == null || !mounted) return;
      final credentials = await widget.pairingLoader(link);
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Conectar por USB'),
          content: Text('${credentials.host}\n${credentials.os}\n\n'
              'Comprueba que es el computador conectado. Podrás ver sus métricas '
              'y cerrar procesos permitidos, con confirmación. '
              'El token se recibió por USB y no se guardará.'
              '${monitor.running ? '\n\nSe reemplazará la conexión actual; una grabación seguirá en su computador.' : ''}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Conectar')),
          ],
        ),
      );
      if (!mounted || accepted != true) return;
      _url.text = credentials.url;
      _token.clear();
      monitor.connect(credentials.url, credentials.token);
    } on MissingPluginException {
      // Tests y otras plataformas mantienen conexión manual.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo recibir la conexión USB. Reinicia el '
                'lanzador o usa el token manual.')));
      }
    } finally {
      _pairingBusy = false;
      if (_pairingAgain && mounted) {
        _pairingAgain = false;
        unawaited(_receiveUsbPairing());
      }
    }
  }

  void _changed() {
    if (!mounted) return;
    _updateAwake();
    setState(() {});
  }

  void _updateAwake() {
    final desired = _keepAwake && monitor.connected;
    if (_awake == desired) return;
    _awake = desired;
    _panelChannel
        .invokeMethod<void>('keepScreenOn', desired)
        .catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) monitor.checkFreshness();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    monitor.removeListener(_changed);
    _pairingChannel.setMethodCallHandler(null);
    if (widget.controller == null) monitor.dispose();
    _panelChannel
        .invokeMethod<void>('keepScreenOn', false)
        .catchError((Object _) {});
    _token.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sessionAction() => _run(() async {
        if (monitor.activeSession == null) {
          await monitor.request('session_start');
        } else {
          final response = await monitor.request('session_stop');
          await monitor.loadHistory();
          if (mounted && response['report'] is Map<String, dynamic>) {
            await _showReport(response['report'] as Map<String, dynamic>);
          }
        }
      });

  bool get _wide {
    final size = MediaQuery.sizeOf(context);
    return size.width >= 640 && size.width > size.height;
  }

  void _selectTab(int index) {
    setState(() => _tab = index);
    if (index == 3 &&
        monitor.connected &&
        monitor.capabilities.contains('history')) {
      _run(monitor.loadHistory);
    }
  }

  Widget _themeIcons() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (mode, icon, label) in [
            (ThemeMode.light, Icons.light_mode_outlined, 'Tema claro'),
            (ThemeMode.dark, Icons.dark_mode_outlined, 'Tema oscuro'),
            (
              ThemeMode.system,
              Icons.brightness_auto_outlined,
              'Tema del sistema'
            ),
          ])
            IconButton(
              tooltip: label,
              isSelected: widget.themeMode == mode,
              onPressed: () => widget.onThemeChanged?.call(mode),
              icon: Icon(icon, size: 18),
              selectedIcon: Icon(icon, size: 18),
              style: IconButton.styleFrom(
                minimumSize: const Size(36, 40),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: widget.themeMode == mode
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : null,
                foregroundColor: widget.themeMode == mode
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : null,
              ),
            ),
        ],
      );

  Widget _settingsMenu() => PopupMenuButton<String>(
        tooltip: 'Opciones',
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (_) => _closeApp(),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'exit', child: Text('Salir de la app')),
        ],
      );

  Future<void> _closeApp() async {
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    final exit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Salir de PC Monitor'),
              content: Text(monitor.activeSession != null
                  ? 'La sesión seguirá grabándose en el computador mientras el agente permanezca abierto. Para terminarla y generar el informe, pulsa Finalizar antes de salir.'
                  : 'Se desconectará el teléfono. El agente del computador seguirá abierto; puedes detenerlo allí con Ctrl+C.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Salir')),
              ],
            ));
    _exitDialogOpen = false;
    if (!mounted || exit != true) return;
    monitor.disconnect();
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_tab != 0) {
            _selectTab(0);
          } else {
            _closeApp();
          }
        },
        child: _buildShell(context),
      );

  Widget _buildShell(BuildContext context) {
    if (_wide) {
      return LandscapeShell(
        selectedIndex: _tab,
        onSelected: _selectTab,
        status: monitor.label,
        connected: monitor.connected,
        host: monitor.host,
        detail: monitor.detail,
        actions: [
          if (monitor.connected)
            FilledButton.tonalIcon(
              key: const Key('toolbar-session-button'),
              onPressed: monitor.sessionKnown &&
                      monitor.capabilities.contains('sessions') &&
                      !_busy
                  ? _sessionAction
                  : null,
              icon: Icon(
                  monitor.activeSession == null ? Icons.play_arrow : Icons.stop,
                  size: 16),
              label: Text(
                  _busy
                      ? 'Procesando…'
                      : monitor.activeSession == null
                          ? 'Grabar sesión'
                          : 'Finalizar',
                  style: const TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 34)),
            ),
          _themeIcons(),
          IconButton(
              tooltip:
                  _keepAwake ? 'Pantalla activa: sí' : 'Pantalla activa: no',
              onPressed: () {
                setState(() => _keepAwake = !_keepAwake);
                _updateAwake();
              },
              icon: Icon(
                  _keepAwake
                      ? Icons.screen_lock_portrait
                      : Icons.screen_lock_rotation,
                  size: 18)),
          if (monitor.running)
            IconButton(
                tooltip: 'Desconectar',
                icon: const Icon(Icons.link_off, size: 18),
                onPressed: () {
                  monitor.disconnect();
                  setState(() => _tab = 0);
                }),
          _settingsMenu(),
        ],
        body: switch (_tab) {
          1 => _chartsPage(),
          2 => _processPage(),
          3 => _wideSessions(),
          _ => _widePanel()
        },
      );
    }
    return _portraitShell(context);
  }

  Widget _portraitShell(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('PC Monitor'),
          actions: [
            _themeIcons(),
            _settingsMenu(),
            Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                    child: Chip(
                  avatar: Icon(Icons.circle,
                      size: 10,
                      color: monitor.connected
                          ? Colors.greenAccent
                          : Colors.amber),
                  label: Text(monitor.label),
                ))),
          ],
        ),
        body: SafeArea(
            child: Column(children: [
          if (monitor.detail != null)
            Container(
              width: double.infinity,
              color: Colors.amber.withValues(alpha: .10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(monitor.detail!,
                  style: TextStyle(
                      color: panelColor(
                          context, Colors.amberAccent, Colors.brown.shade700))),
            ),
          Expanded(
              child: switch (_tab) {
            1 => _chartsPage(),
            2 => _processPage(),
            3 => _sessionsPage(),
            _ => _dashboard(),
          }),
        ])),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Panel'),
            NavigationDestination(
                icon: Icon(Icons.show_chart), label: 'Gráficas'),
            NavigationDestination(icon: Icon(Icons.apps), label: 'Procesos'),
            NavigationDestination(icon: Icon(Icons.history), label: 'Sesiones'),
          ],
        ),
      );

  Widget _dashboard({bool compact = false}) {
    final cpu = number(monitor.metrics?['cpu']?['total']);
    final mem = monitor.metrics?['mem'];
    final used = number(mem?['used']);
    final total = number(mem?['total']);
    final memoryPercent =
        used != null && total != null && total > 0 ? used / total * 100 : null;
    final disk = monitor.metrics?['disk'];
    final net = monitor.metrics?['net'];
    final battery = number(monitor.metrics?['battery']?['percent']);
    final cores =
        (monitor.metrics?['cpu']?['per_core'] as List?)?.map(number).toList() ??
            <double?>[];
    final temperature = _temperature();
    final cards = [
      _MetricCard(
          compact: compact,
          label: 'CPU',
          value: percent(cpu),
          subtitle: cpu == null ? 'Esperando muestra' : 'Uso total del equipo',
          color: metricColor(cpu, context)),
      _MetricCard(
          compact: compact,
          label: 'RAM',
          value: percent(memoryPercent),
          subtitle:
              '${bytes(used)} / ${bytes(total)} · swap ${bytes(number(mem?['swap_used']))}',
          color: metricColor(memoryPercent, context)),
      _MetricCard(
          compact: compact,
          label: 'DISCO',
          value: '${rate(disk?['read_bps'])} ↓',
          subtitle: compact
              ? 'Escr. ${rate(disk?['write_bps'])}'
              : 'Escritura ${rate(disk?['write_bps'])} ↑',
          color: panelColor(
              context, Colors.lightBlueAccent, Colors.blue.shade800)),
      _MetricCard(
          compact: compact,
          label: 'RED',
          value: '${rate(net?['down_bps'])} ↓',
          subtitle: compact
              ? 'Subida ${rate(net?['up_bps'])}'
              : 'Subida ${rate(net?['up_bps'])} ↑',
          color:
              panelColor(context, Colors.purpleAccent, Colors.purple.shade700)),
      _MetricCard(
          compact: compact,
          label: compact ? 'BATERÍA PC' : 'BATERÍA DEL EQUIPO',
          value: percent(battery),
          subtitle: battery == null
              ? 'Sin sensor disponible'
              : monitor.metrics?['battery']?['charging'] == true
                  ? 'Conectado a corriente'
                  : 'Usando batería',
          color:
              panelColor(context, Colors.amberAccent, Colors.brown.shade700)),
      _MetricCard(
          compact: compact,
          label: 'TEMPERATURA',
          value: temperature == null
              ? '—'
              : '${temperature.$1.toStringAsFixed(1)} °C',
          subtitle: temperature?.$2 ?? 'Sensor no disponible',
          color: temperature == null ? Colors.grey : Colors.deepOrangeAccent),
    ];
    if (compact) {
      return LayoutBuilder(
          builder: (context, constraints) => GridView.count(
                key: const PageStorageKey('wide-metrics'),
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: ((constraints.maxWidth - 16) / 3) /
                    ((constraints.maxHeight - 8) / 2),
                physics: const NeverScrollableScrollPhysics(),
                children: cards,
              ));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      _connectionCard(),
      if (monitor.live)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _tab = 1),
              icon: const Icon(Icons.show_chart),
              label: const Text('Ver gráficas y tendencias'),
            )),
      const SizedBox(height: 12),
      _sessionCard(),
      const SizedBox(height: 16),
      if (!monitor.live)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
              'Sin datos en vivo. Inicia el agente en el computador y conecta por USB.'),
        ),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780 ? 3 : 2;
        return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards
                .map((card) => SizedBox(
                      width:
                          (constraints.maxWidth - 10 * (columns - 1)) / columns,
                      child: card,
                    ))
                .toList());
      }),
      if (cores.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('CPU por núcleo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 8, children: [
          for (var index = 0; index < cores.length; index++)
            SizedBox(
                width: 82,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${index + 1}: ${percent(cores[index])}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                          value: (cores[index] ?? 0).clamp(0, 100) / 100,
                          color: metricColor(cores[index], context)),
                    ])),
        ]),
      ],
      if (monitor.lastUpdate != null)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text(
              'Último dato recibido: ${timeLabel(monitor.lastUpdate!)}${monitor.live ? '' : ' · sin conexión'}',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mantener pantalla encendida'),
        subtitle:
            const Text('Mientras el panel esté conectado y en primer plano'),
        value: _keepAwake,
        onChanged: (value) {
          setState(() => _keepAwake = value);
          _updateAwake();
        },
      ),
    ]);
  }

  Widget _chartsPage({bool forceStacked = false}) {
    if (_wide && !forceStacked) return _wideCharts();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Tendencias en vivo',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
          'Compara cambios sostenidos y picos. Esta ventana muestra datos recibidos mientras la app está abierta.'),
      const SizedBox(height: 14),
      SegmentedButton<int>(
        key: const Key('chart-window'),
        segments: const [
          ButtonSegment(value: 1, label: Text('1 min')),
          ButtonSegment(value: 5, label: Text('5 min'))
        ],
        selected: {_chartWindow.inMinutes},
        onSelectionChanged: (values) =>
            setState(() => _chartWindow = Duration(minutes: values.single)),
      ),
      if (!monitor.live)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Sin datos en vivo. Conecta el equipo para empezar.')),
      const SizedBox(height: 12),
      _chart(0),
      _chart(1),
      _chart(2),
      const SizedBox(height: 8),
      const Text(
          'Los huecos indican muestras ausentes. El historial de sesión y sus CSV se conservan en el computador.'),
    ]);
  }

  bool _compactFits(BoxConstraints constraints) =>
      constraints.maxHeight >= 230 &&
      MediaQuery.textScalerOf(context).scale(1) <= 1.25;

  MetricChart _chart(int index,
      {bool compact = false, bool expanded = false, Duration? window}) {
    final titles = ['CPU y RAM', 'Actividad de disco', 'Tráfico de red'];
    final green =
        panelColor(context, const Color(0xff68dfc1), const Color(0xff006b54));
    final blue =
        panelColor(context, Colors.lightBlueAccent, Colors.blue.shade800);
    final amber =
        panelColor(context, Colors.amberAccent, Colors.brown.shade700);
    final purple =
        panelColor(context, Colors.purpleAccent, Colors.purple.shade700);
    final series = [
      [ChartSeries('cpu', 'CPU', green), ChartSeries('ram', 'RAM', blue)],
      [
        ChartSeries('disk_read', 'Lectura', green),
        ChartSeries('disk_write', 'Escritura', amber)
      ],
      [
        ChartSeries('net_down', 'Bajada', purple),
        ChartSeries('net_up', 'Subida', blue)
      ],
    ];
    const captions = [
      'Escala fija 0–100 %. Un pico aislado no confirma un problema. Si la carga se mantiene, revisa Procesos.',
      'Ambas curvas usan la misma escala automática. Es velocidad de transferencia, no espacio ocupado.',
      'Escala automática en bytes/s. Muestra tráfico del equipo, no la capacidad máxima de tu conexión.',
    ];
    return MetricChart(
        title: titles[index],
        points: monitor.live ? monitor.history.points : const <MetricPoint>[],
        series: series[index],
        window: window ?? _chartWindow,
        fixedMaximum: index == 0 ? 100 : null,
        formatValue: index == 0 ? percent : rate,
        caption: captions[index],
        compact: compact,
        expanded: expanded,
        onExpand: expanded
            ? null
            : () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                      builder: (context) => ExpandedChartPage(
                            monitor: monitor,
                            title: titles[index],
                            initialWindow: _chartWindow,
                            onWindowChanged: (window) =>
                                setState(() => _chartWindow = window),
                            chartBuilder: (window) =>
                                _chart(index, expanded: true, window: window),
                          )),
                ));
  }

  Widget _widePanel() => LayoutBuilder(builder: (context, constraints) {
        if (!monitor.live) {
          return Row(children: [
            SizedBox(
                width: constraints.maxWidth * .55,
                child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [_connectionCard()])),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                        monitor.running
                            ? 'Esperando datos del equipo…'
                            : 'Conecta el teléfono por USB, inicia el agente e introduce su token.',
                        style: Theme.of(context).textTheme.titleMedium))),
          ]);
        }
        if (!_compactFits(constraints)) return _dashboard();
        final cores = (monitor.metrics?['cpu']?['per_core'] as List?)
                ?.map(number)
                .toList() ??
            <double?>[];
        return Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              Expanded(
                  flex: 3,
                  child: Column(children: [
                    Expanded(child: _dashboard(compact: true)),
                    if (cores.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                              height: 24,
                              child: Row(children: [
                                Text('${cores.length} núcleos',
                                    style: const TextStyle(fontSize: 10)),
                                const SizedBox(width: 8),
                                ...List.generate(
                                    cores.length,
                                    (index) => Expanded(
                                        child: Tooltip(
                                            message:
                                                'Núcleo ${index + 1}: ${percent(cores[index])}',
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 2),
                                              child: LinearProgressIndicator(
                                                  value: (cores[index] ?? 0)
                                                          .clamp(0, 100) /
                                                      100,
                                                  color: metricColor(
                                                      cores[index], context),
                                                  minHeight: 8),
                                            )))),
                              ]))),
                  ])),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _chart(0, compact: true)),
            ]));
      });

  Widget _wideCharts() => LayoutBuilder(builder: (context, constraints) {
        if (!_compactFits(constraints)) return _chartsPage(forceStacked: true);
        return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Column(children: [
              SizedBox(
                  height: 40,
                  child: Row(children: [
                    const Text('Tendencias en vivo',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    SizedBox(
                        width: 160,
                        child: SegmentedButton<int>(
                          key: const Key('chart-window'),
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                              visualDensity: VisualDensity.compact),
                          segments: const [
                            ButtonSegment(value: 1, label: Text('1 min')),
                            ButtonSegment(value: 5, label: Text('5 min'))
                          ],
                          selected: {_chartWindow.inMinutes},
                          onSelectionChanged: (values) => setState(() =>
                              _chartWindow = Duration(minutes: values.single)),
                        )),
                    IconButton(
                        tooltip: 'Cómo leer las gráficas',
                        icon: const Icon(Icons.info_outline, size: 18),
                        onPressed: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: const Text('Cómo leer las gráficas'),
                                  content: const SingleChildScrollView(
                                      child: Text(
                                          'CPU y RAM: escala fija de 0 a 100 %.\n\nDisco y red: cada pareja comparte escala automática en bytes/s.\n\nMedia y pico corresponden a las muestras válidas de la ventana. Los huecos no son ceros.\n\nToca una gráfica para ampliarla. En la vista ampliada, toca o arrastra para consultar un valor; mantén pulsado para quitar la selección. Usa la X para volver.')),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Entendido'))
                                  ],
                                ))),
                  ])),
              Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    for (var index = 0; index < 3; index++)
                      Expanded(child: _chart(index, compact: true))
                  ])),
            ]));
      });

  Widget _processAction(Map<String, dynamic> group) => IconButton(
        tooltip: 'Gestionar procesos de ${group['app']}',
        onPressed: monitor.live &&
                monitor.capabilities.contains('process_actions') &&
                objectList(group['members']).isNotEmpty
            ? () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => FractionallySizedBox(
                    heightFactor: .95,
                    child: ProcessDetailsSheet(monitor: monitor, group: group)))
            : null,
        icon: const Icon(Icons.close, size: 18),
        style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      );

  Widget _wideProcesses() {
    final rows = monitor.processes
        .where((row) => (row['app']?.toString() ?? '')
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList()
      ..sort(
          (a, b) => (number(b[_sort]) ?? 0).compareTo(number(a[_sort]) ?? 0));
    final largest = rows.fold<double>(
        0,
        (peak, row) =>
            (number(row['mem']) ?? 0) > peak ? number(row['mem'])! : peak);
    return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 190,
              child: ListView(children: [
                const Text('Procesos del equipo',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                    key: const Key('process-search'),
                    decoration: const InputDecoration(
                        labelText: 'Buscar aplicación',
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 18)),
                    onChanged: (value) => setState(() => _query = value)),
                const SizedBox(height: 8),
                DropdownButton<String>(
                    isExpanded: true,
                    value: _sort,
                    onChanged: (value) => setState(() => _sort = value!),
                    items: const [
                      DropdownMenuItem(
                          value: 'mem',
                          child: Text('Ordenar por RAM',
                              style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(
                          value: 'cpu',
                          child: Text('Ordenar por CPU',
                              style: TextStyle(fontSize: 12))),
                    ]),
                Text('${rows.length} grupos · top 20 por RAM',
                    style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 8),
                if (!monitor.capabilities.contains('process_actions'))
                  const Text(
                      'Actualiza el agente del computador para habilitar el cierre.'),
                const Text(
                    'Barras: RAM relativa entre grupos visibles. CPU puede superar 100 % al usar varios núcleos.',
                    style: TextStyle(fontSize: 11)),
              ])),
          const SizedBox(width: 12),
          Expanded(
              child: !monitor.live
                  ? const Center(
                      child: Text('Conecta el equipo para ver procesos.'))
                  : rows.isEmpty
                      ? const Center(
                          child: Text('Sin aplicaciones que coincidan.'))
                      : LayoutBuilder(
                          builder: (context, constraints) => GridView.builder(
                                key: const PageStorageKey('wide-processes'),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            constraints.maxWidth >= 400 ? 2 : 1,
                                        mainAxisExtent:
                                            MediaQuery.textScalerOf(context)
                                                        .scale(1) >
                                                    1.25
                                                ? 170
                                                : 125,
                                        crossAxisSpacing: 6,
                                        mainAxisSpacing: 6),
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final row = rows[index];
                                  return Card(
                                      margin: EdgeInsets.zero,
                                      child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Row(children: [
                                                  Expanded(
                                                      child: Text(
                                                          row['app']
                                                                  ?.toString() ??
                                                              'Aplicación',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize:
                                                                      13))),
                                                  _processAction(row),
                                                ]),
                                                const Spacer(),
                                                Row(children: [
                                                  Expanded(
                                                      child: Text(
                                                          'CPU ${percent(number(row['cpu']))}',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      11))),
                                                  Text(
                                                      bytes(number(row['mem'])),
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: panelColor(
                                                              context,
                                                              Colors
                                                                  .lightBlueAccent,
                                                              Colors.blue
                                                                  .shade800)))
                                                ]),
                                                const SizedBox(height: 6),
                                                LinearProgressIndicator(
                                                    value: largest > 0
                                                        ? ((number(row['mem']) ??
                                                                    0) /
                                                                largest)
                                                            .clamp(0, 1)
                                                        : 0,
                                                    color: panelColor(
                                                        context,
                                                        Colors.lightBlueAccent,
                                                        Colors.blue.shade800),
                                                    minHeight: 5),
                                                const SizedBox(height: 5),
                                                Text(
                                                    '${row['count'] ?? 0} procesos',
                                                    style: const TextStyle(
                                                        fontSize: 10)),
                                              ])));
                                },
                              ))),
        ]));
  }

  Widget _wideSessions() => Padding(
      padding: const EdgeInsets.all(8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 245, child: ListView(children: [_sessionCard()])),
        const SizedBox(width: 8),
        Expanded(child: _sessionsPage(includeControl: false)),
      ]));

  (double, String)? _temperature() {
    final data = monitor.metrics?['temps']?['data'];
    if (data is! Map) return null;
    for (final entry in data.entries) {
      if (entry.value is! List) continue;
      for (final sensor in entry.value as List) {
        if (sensor is! Map) continue;
        final current = number(sensor['current']);
        if (current != null) {
          return (current, '${entry.key} ${sensor['label'] ?? ''}'.trim());
        }
      }
    }
    return null;
  }

  Widget _connectionCard() => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.usb, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(monitor.host ?? 'Sin equipo conectado',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(monitor.os == 'darwin'
                      ? 'macOS · USB'
                      : monitor.os == 'windows'
                          ? 'Windows · USB'
                          : 'Conexión USB'),
                ])),
            if (monitor.running)
              IconButton(
                  tooltip: 'Desconectar',
                  onPressed: monitor.disconnect,
                  icon: const Icon(Icons.link_off)),
          ]),
          if (!monitor.running) ...[
            const SizedBox(height: 14),
            TextField(
              key: const Key('token-field'),
              controller: _token,
              obscureText: !_showToken,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                  labelText: 'Token del computador',
                  hintText: 'Copia el token que muestra el agente',
                  suffixIcon: IconButton(
                      tooltip: 'Mostrar u ocultar token',
                      icon: Icon(
                          _showToken ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setState(() => _showToken = !_showToken))),
              onSubmitted: (_) => _connect(),
            ),
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Dirección del agente'),
                children: [
                  TextField(
                      key: const Key('url-field'),
                      controller: _url,
                      autocorrect: false,
                      decoration:
                          const InputDecoration(labelText: 'URL por USB')),
                  const SizedBox(height: 10),
                ]),
            FilledButton.icon(
                key: const Key('connect-button'),
                onPressed: _connect,
                icon: const Icon(Icons.link),
                label: const Text('Conectar')),
          ],
        ]),
      ));

  void _connect() {
    FocusScope.of(context).unfocus();
    monitor.connect(_url.text, _token.text);
  }

  Widget _sessionCard() {
    final active = monitor.activeSession;
    final started = number(active?['started_at']);
    final duration = started == null
        ? null
        : DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch((started * 1000).round()));
    final ready = monitor.connected &&
        monitor.sessionKnown &&
        monitor.capabilities.contains('sessions');
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      active == null
                          ? 'Sesión de trabajo'
                          : 'Sesión en curso · ${durationLabel(duration ?? Duration.zero)}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(active == null
                      ? 'Guarda métricas en el computador y genera un informe al terminar.'
                      : 'El computador sigue registrando aunque se desconecte el teléfono.'),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    key: const Key('session-button'),
                    onPressed: ready && !_busy ? _sessionAction : null,
                    icon: Icon(active == null
                        ? Icons.play_circle_outline
                        : Icons.stop_circle_outlined),
                    label: Text(_busy
                        ? 'Procesando…'
                        : active == null
                            ? 'Grabar sesión'
                            : 'Terminar y ver informe'),
                  ),
                ])));
  }

  Widget _processPage() {
    if (_wide) return _wideProcesses();
    final rows = monitor.processes
        .where((row) => (row['app']?.toString() ?? '')
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList()
      ..sort(
          (a, b) => (number(b[_sort]) ?? 0).compareTo(number(a[_sort]) ?? 0));
    final largestMemory = rows.fold<double>(
        0,
        (peak, row) =>
            (number(row['mem']) ?? 0) > peak ? number(row['mem'])! : peak);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Procesos del equipo',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      const Text(
          'Los 20 grupos de mayor uso de memoria. Las barras comparan RAM entre los grupos visibles; no son porcentaje de RAM total. CPU puede superar 100 % si usa varios núcleos.'),
      const SizedBox(height: 16),
      TextField(
          key: const Key('process-search'),
          decoration: const InputDecoration(
              labelText: 'Buscar aplicación', prefixIcon: Icon(Icons.search)),
          onChanged: (value) => setState(() => _query = value)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${rows.length} grupos'),
        DropdownButton<String>(
            value: _sort,
            onChanged: (value) => setState(() => _sort = value!),
            items: const [
              DropdownMenuItem(value: 'mem', child: Text('Ordenar por RAM')),
              DropdownMenuItem(value: 'cpu', child: Text('Ordenar por CPU')),
            ]),
      ]),
      if (!monitor.live)
        const Card(
            child: ListTile(
                title: Text('Conecta el computador para ver sus procesos.')))
      else if (rows.isEmpty)
        const Card(
            child: ListTile(title: Text('Sin aplicaciones que coincidan.')))
      else
        ...rows.map((row) => Card(
                child: ListTile(
              title: Text(row['app']?.toString() ?? 'Aplicación',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'CPU ${percent(number(row['cpu']))} · ${row['count'] ?? 0} procesos'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: largestMemory > 0
                            ? ((number(row['mem']) ?? 0) / largestMemory)
                                .clamp(0, 1)
                            : 0,
                        color: panelColor(context, Colors.lightBlueAccent,
                            Colors.blue.shade800),
                        minHeight: 6),
                    const SizedBox(height: 6),
                  ]),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(bytes(number(row['mem'])),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary)),
                _processAction(row),
              ]),
            ))),
    ]);
  }

  Widget _sessionsPage({bool includeControl = true}) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        if (includeControl) _sessionCard(),
        if (includeControl) const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: Text('Informes del equipo',
                  style: Theme.of(context).textTheme.titleLarge)),
          IconButton(
              tooltip: 'Actualizar historial',
              onPressed: monitor.connected &&
                      !_busy &&
                      monitor.capabilities.contains('history')
                  ? () => _run(monitor.loadHistory)
                  : null,
              icon: const Icon(Icons.refresh)),
        ]),
        const Text(
            'Historial local del computador conectado. Se muestran las últimas 30 sesiones.'),
        const SizedBox(height: 12),
        if (monitor.reports.isEmpty)
          const Card(
              child: ListTile(
                  title: Text('Todavía no hay informes.'),
                  subtitle: Text(
                      'Inicia y termina una sesión para guardar el primero.')))
        else
          ...monitor.reports.map((report) => Card(
                  child: ListTile(
                onTap: () => _showReport(report),
                leading: Icon(report['interrupted'] == true
                    ? Icons.warning_amber
                    : Icons.summarize_outlined),
                title: Text(dateLabel(number(report['started_at']))),
                subtitle: Text(
                    '${durationLabel(Duration(seconds: (number(report['duration_s']) ?? 0).round()))} · ${report['sample_count'] ?? 0} muestras${report['interrupted'] == true ? ' · interrumpida' : ''}'),
                trailing: const Icon(Icons.chevron_right),
              ))),
      ]);

  Future<void> _showReport(Map<String, dynamic> report) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => FractionallySizedBox(
            heightFactor: .85,
            child: SafeArea(
                child: Column(children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 8),
                child: Row(children: [
                  Expanded(
                      child: Text('Informe de sesión',
                          style: Theme.of(sheetContext).textTheme.titleLarge)),
                  IconButton(
                      key: const Key('close-report-button'),
                      tooltip: 'Cerrar informe',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close)),
                ]),
              ),
              Expanded(
                  child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  const SizedBox(height: 8),
                  Text(
                      '${report['host']} · ${dateLabel(number(report['started_at']))}'),
                  Text(
                      'Duración ${durationLabel(Duration(seconds: (number(report['duration_s']) ?? 0).round()))} · ${report['sample_count'] ?? 0} muestras'),
                  if (report['interrupted'] == true)
                    const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                            'El agente se interrumpió. El informe termina en la última muestra guardada.',
                            style: TextStyle(color: Colors.amber))),
                  const Divider(height: 30),
                  _reportRow('CPU promedio / pico',
                      '${percent(number(report['cpu']?['avg']))} / ${percent(number(report['cpu']?['peak']))}'),
                  _reportRow('RAM promedio / pico',
                      '${bytes(number(report['mem']?['avg_used']))} / ${bytes(number(report['mem']?['peak_used']))}'),
                  const SizedBox(height: 12),
                  const Text(
                      'No se dispone de medición de estrangulamiento térmico. Los valores ausentes se muestran como —.'),
                  const SizedBox(height: 20),
                  Text('Aplicaciones principales',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text(
                      'Promedio dentro de los grupos principales muestreados; no representa todos los procesos del equipo.'),
                  const SizedBox(height: 8),
                  ...objectList(report['top_apps']).map((app) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(app['app']?.toString() ?? 'Aplicación'),
                      subtitle:
                          Text('CPU media ${percent(number(app['avg_cpu']))}'),
                      trailing: Text(bytes(number(app['avg_mem']))))),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('export-button'),
                    onPressed: monitor.connected
                        ? () async {
                            try {
                              final response = await monitor.request(
                                  'session_export',
                                  {'session_id': report['session_id']});
                              if (!sheetContext.mounted) return;
                              await showDialog<void>(
                                  context: sheetContext,
                                  builder: (context) => AlertDialog(
                                        title: const Text(
                                            'CSV guardados en el computador'),
                                        content: SelectableText(
                                            '${response['export_path']}\n\nsamples.csv: detalle de 7 días\nminutes.csv: datos antiguos agregados\ntop_apps.csv: aplicaciones\nreport.json: informe'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Entendido'))
                                        ],
                                      ));
                            } catch (error) {
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(content: Text(error.toString())));
                              }
                            }
                          }
                        : null,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Exportar CSV al computador'),
                  ),
                  TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cerrar informe')),
                ],
              )),
            ]))),
      );

  Widget _reportRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
        ],
      ));
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label,
      required this.value,
      required this.subtitle,
      required this.color,
      this.compact = false});
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
      margin: EdgeInsets.zero,
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 0 : 155),
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontSize: compact ? 10 : null)),
          if (compact) const Spacer() else const SizedBox(height: 12),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.bold))),
          if (compact) const Spacer() else const SizedBox(height: 8),
          Text(subtitle,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: compact ? 10 : null)),
        ]),
      ));
}

String percent(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)} %';
String bytes(double? value) {
  if (value == null) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var index = 0;
  while (value! >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  return '${value.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
}

String rate(dynamic value) =>
    number(value) == null ? '—' : '${bytes(number(value))}/s';
Color metricColor(double? value, BuildContext context) => value == null
    ? Colors.grey
    : value >= 85
        ? panelColor(context, Colors.redAccent, Colors.red.shade800)
        : value >= 65
            ? panelColor(context, Colors.amberAccent, Colors.brown.shade700)
            : panelColor(
                context, const Color(0xff68dfc1), const Color(0xff006b54));

Color panelColor(BuildContext context, Color dark, Color light) =>
    Theme.of(context).brightness == Brightness.dark ? dark : light;
String timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
String dateLabel(double? timestamp) {
  if (timestamp == null) return 'Sin fecha';
  final date = DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).round());
  return '${date.day}/${date.month}/${date.year} ${timeLabel(date)}';
}

String durationLabel(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 99999999);
  return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
