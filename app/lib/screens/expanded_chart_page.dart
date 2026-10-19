import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../connection/monitor_controller.dart';

/// Reutiliza la gráfica original y su controlador; ampliar no abre otra conexión.
class ExpandedChartPage extends StatefulWidget {
  const ExpandedChartPage({
    super.key,
    required this.monitor,
    required this.title,
    required this.initialWindow,
    required this.onWindowChanged,
    required this.chartBuilder,
  });
  final MonitorController monitor;
  final String title;
  final Duration initialWindow;
  final ValueChanged<Duration> onWindowChanged;
  final Widget Function(Duration window) chartBuilder;

  @override
  State<ExpandedChartPage> createState() => _ExpandedChartPageState();
}

class _ExpandedChartPageState extends State<ExpandedChartPage> {
  late Duration _window = widget.initialWindow;

  @override
  Widget build(BuildContext context) => Scaffold(
        key: const Key('expanded-chart-page'),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: widget.monitor,
            builder: (context, _) => Column(children: [
              SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    child: Row(children: [
                      Expanded(
                          child: Text(
                        widget.monitor.live
                            ? widget.title
                            : '${widget.title} · Sin datos en vivo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      )),
                      SizedBox(
                          width: 160,
                          child: SegmentedButton<int>(
                            key: const Key('expanded-chart-window'),
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                                visualDensity: VisualDensity.compact),
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1 min')),
                              ButtonSegment(value: 5, label: Text('5 min')),
                            ],
                            selected: {_window.inMinutes},
                            onSelectionChanged: (values) {
                              final window = Duration(minutes: values.single);
                              setState(() => _window = window);
                              widget.onWindowChanged(window);
                            },
                          )),
                      IconButton(
                        key: const Key('close-expanded-chart'),
                        tooltip: 'Cerrar gráfica ampliada',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ]),
                  )),
              Expanded(child: LayoutBuilder(builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final chart = widget.chartBuilder(_window);
                // Texto grande o poca altura: desplazar contenido, manteniendo la X fija.
                if (scale > 1.25 || constraints.maxHeight < 280) {
                  return SingleChildScrollView(
                      child: SizedBox(
                          height: math.max(constraints.maxHeight, 420 * scale),
                          child: chart));
                }
                return chart;
              })),
            ]),
          ),
        ),
      );
}
