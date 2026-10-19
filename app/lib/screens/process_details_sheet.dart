import 'package:flutter/material.dart';

import '../connection/monitor_controller.dart';

/// La agrupación es visual: cada acción conserva PID, ruta y creación propios.
class ProcessDetailsSheet extends StatefulWidget {
  const ProcessDetailsSheet(
      {super.key, required this.monitor, required this.group});
  final MonitorController monitor;
  final Map<String, dynamic> group;

  @override
  State<ProcessDetailsSheet> createState() => _ProcessDetailsSheetState();
}

class _ProcessDetailsSheetState extends State<ProcessDetailsSheet> {
  bool _busy = false;
  bool _confirming = false;
  final Set<int> _finished = {};
  String? _result;

  Future<void> _terminate(Map<String, dynamic> member) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final prepared = await widget.monitor.prepareProcess(member);
      if (!mounted) return;
      final process = prepared['process'] as Map<String, dynamic>;
      setState(() => _confirming = true);
      final force = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Finalizar ${process['name']}'),
          scrollable: true,
          content:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PID ${process['pid']}'),
            SelectableText(process['exe']?.toString() ?? '—'),
            const SizedBox(height: 12),
            const Text(
                'Guarda tu trabajo antes de continuar. El cierre puede perder cambios sin guardar y afectar a la aplicación. En Windows, Finalizar también termina el proceso directamente.'),
            const SizedBox(height: 8),
            const Text(
                'La confirmación vence en 30 segundos. Se actúa únicamente sobre este PID; no se cierran todos los procesos del grupo.'),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Forzar cierre')),
            FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Finalizar')),
          ],
        ),
      );
      if (!mounted || force == null) return;
      setState(() => _confirming = false);
      final result = await widget.monitor
          .terminateProcess(prepared['ticket'] as String, force: force);
      if (!mounted) return;
      setState(() {
        _result = result['message']?.toString();
        if (result['status'] == 'terminated') {
          _finished.add((member['pid'] as num).toInt());
        }
      });
    } catch (error) {
      if (mounted) {
        setState(
            () => _result = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 8),
            child: Row(children: [
              Expanded(
                  child: Text(widget.group['app']?.toString() ?? 'Procesos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'Cerrar detalle de procesos',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
          ),
          if (_busy && !_confirming) const LinearProgressIndicator(),
          if (_result != null)
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(_result!, key: const Key('process-action-result'))),
          Expanded(
              child: ListenableBuilder(
            listenable: widget.monitor,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                const Text(
                    'Selecciona el proceso que quieres finalizar. Los procesos protegidos no permiten cierre.'),
                const SizedBox(height: 8),
                for (final member in objectList(widget.group['members']))
                  _member(member),
              ],
            ),
          )),
        ]),
      );

  Widget _member(Map<String, dynamic> member) {
    final finished = _finished.contains(member['pid']);
    final reason = member['blocked_reason']?.toString();
    final allowed = member['can_terminate'] == true;
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(
                  '${member['name'] ?? 'Proceso'} · PID ${member['pid']}',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          if (finished)
            const Icon(Icons.check_circle_outline)
          else if (!allowed)
            const Icon(Icons.lock_outline)
          else
            IconButton(
              key: ValueKey('terminate-${member['pid']}'),
              tooltip: 'Finalizar PID ${member['pid']}',
              onPressed: !_busy && widget.monitor.live
                  ? () => _terminate(member)
                  : null,
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.close),
            ),
        ]),
        SelectableText(member['exe']?.toString() ?? 'Ruta no disponible',
            style: Theme.of(context).textTheme.bodySmall),
        if (finished)
          const Text('Finalizado')
        else if (!allowed)
          Text(reason ?? 'Identidad no verificable; cierre bloqueado.'),
      ]),
    ));
  }
}
