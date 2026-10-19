import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Navegación lateral: conserva la altura para métricas y gráficas.
class LandscapeShell extends StatelessWidget {
  const LandscapeShell(
      {super.key,
      required this.selectedIndex,
      required this.onSelected,
      required this.status,
      required this.connected,
      required this.body,
      required this.actions,
      this.host,
      this.detail});
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String status;
  final bool connected;
  final String? host;
  final String? detail;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Row(children: [
        SizedBox(
            width: 76,
            child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                      child: SizedBox(
                          height: math.max(
                              350 * MediaQuery.textScalerOf(context).scale(1),
                              constraints.maxHeight),
                          child: NavigationRail(
                            selectedIndex: selectedIndex,
                            onDestinationSelected: onSelected,
                            minWidth: 76,
                            labelType: NavigationRailLabelType.all,
                            groupAlignment: -1,
                            leading: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Icon(Icons.monitor_heart_outlined,
                                    color:
                                        Theme.of(context).colorScheme.primary)),
                            destinations: const [
                              NavigationRailDestination(
                                  icon: Icon(Icons.dashboard_outlined),
                                  selectedIcon: Icon(Icons.dashboard),
                                  label: Text('Panel',
                                      style: TextStyle(fontSize: 11))),
                              NavigationRailDestination(
                                  icon: Icon(Icons.show_chart),
                                  label: Text('Gráficas',
                                      style: TextStyle(fontSize: 11))),
                              NavigationRailDestination(
                                  icon: Icon(Icons.apps),
                                  label: Text('Procesos',
                                      style: TextStyle(fontSize: 11))),
                              NavigationRailDestination(
                                  icon: Icon(Icons.history),
                                  label: Text('Sesiones',
                                      style: TextStyle(fontSize: 11))),
                            ],
                          )),
                    ))),
        const VerticalDivider(width: 1),
        Expanded(
            child: Column(children: [
          SizedBox(
              height: 44,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LayoutBuilder(
                      builder: (context, constraints) => constraints.maxWidth <
                                  720 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.25
                          ? Row(children: [
                              Icon(Icons.circle,
                                  size: 7,
                                  color: connected
                                      ? Colors.greenAccent
                                      : Colors.amber),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(
                                      '${host ?? 'PC Monitor'} · $status',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14))),
                              ...actions,
                            ])
                          : Row(children: [
                              const Text('PC Monitor',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(host ?? 'Conexión USB',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall)),
                              const SizedBox(width: 8),
                              Icon(Icons.circle,
                                  size: 7,
                                  color: connected
                                      ? Colors.greenAccent
                                      : Colors.amber),
                              const SizedBox(width: 5),
                              Text(status,
                                  style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 10),
                              ...actions,
                            ])))),
          if (detail != null)
            Container(
                width: double.infinity,
                color: Colors.amber.withValues(alpha: .10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Text(detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 11))),
          Expanded(child: body),
        ])),
      ])));
}
