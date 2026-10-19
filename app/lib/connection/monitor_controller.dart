import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/metric_history.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  rejected,
  error
}

class MonitorController extends ChangeNotifier {
  MonitorController({
    Future<WebSocket> Function(String)? connector,
    this.handshakeTimeout = const Duration(seconds: 8),
    this.retryDelay = const Duration(seconds: 1),
    this.staleAfter = const Duration(seconds: 8),
  }) : _connector = connector ?? WebSocket.connect;

  final Future<WebSocket> Function(String) _connector;
  final Duration handshakeTimeout;
  final Duration retryDelay;
  final Duration staleAfter;
  ConnectionStatus status = ConnectionStatus.disconnected;
  String? detail;
  String? host;
  String? os;
  Set<String> capabilities = {};
  Map<String, dynamic>? metrics;
  List<Map<String, dynamic>> processes = [];
  Map<String, dynamic>? activeSession;
  bool sessionKnown = false;
  List<Map<String, dynamic>> reports = [];
  DateTime? lastUpdate;
  final history = MetricHistory();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  Timer? _handshake;
  Timer? _watchdog;
  bool _wanted = false;
  bool _disposed = false;
  int _generation = 0;
  int _failures = 0;
  int _requestId = 0;
  String _url = '';
  String _token = '';
  final _pending = <String, Completer<Map<String, dynamic>>>{};

  bool get connected => status == ConnectionStatus.connected;
  bool get running => _wanted;
  bool get live => connected && metrics != null;
  String get label => switch (status) {
        ConnectionStatus.disconnected => 'Desconectado',
        ConnectionStatus.connecting => 'Conectando',
        ConnectionStatus.connected => 'Conectado',
        ConnectionStatus.reconnecting => 'Reconectando',
        ConnectionStatus.rejected => 'Token rechazado',
        ConnectionStatus.error => 'Revisar conexión',
      };

  void connect(String url, String token) {
    disconnect();
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        uri.scheme != 'ws' ||
        !{'127.0.0.1', 'localhost', '::1', '[::1]'}.contains(uri.host) ||
        uri.userInfo.isNotEmpty) {
      status = ConnectionStatus.error;
      detail = 'Para USB usa ws://127.0.0.1:8765.';
      _notify();
      return;
    }
    if (token.trim().isEmpty) {
      status = ConnectionStatus.error;
      detail = 'Escribe el token que muestra el computador.';
      _notify();
      return;
    }
    _url = uri.toString();
    _token = token.trim();
    host = null;
    os = null;
    reports = [];
    activeSession = null;
    history.clear();
    lastUpdate = null;
    _failures = 0;
    _wanted = true;
    _open();
  }

  Future<void> _open() async {
    final generation = ++_generation;
    status = _failures == 0
        ? ConnectionStatus.connecting
        : ConnectionStatus.reconnecting;
    detail = _failures == 0
        ? 'Validando conexión y token…'
        : 'Buscando el equipo. Revisa USB y el agente.';
    _notify();
    try {
      final pending = _connector(_url);
      // Una conexión tardía no puede resucitar después de Desconectar o cambiar equipo.
      pending.then((socket) {
        if (generation != _generation || !_wanted) socket.close();
      }, onError: (Object _) {});
      final socket = await pending.timeout(handshakeTimeout);
      if (generation != _generation || !_wanted) {
        socket.close();
        return;
      }
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 5);
      _subscription = socket.listen(
        (data) => _message(data, generation),
        onDone: () => _lost(generation),
        onError: (Object _) => _lost(generation),
      );
      socket.add(jsonEncode({
        'v': 1,
        'type': 'hello',
        'token': _token,
        'client': 'android',
        'app_version': '0.7.0'
      }));
      _handshake = Timer(handshakeTimeout, () => _lost(generation));
    } catch (_) {
      _lost(generation);
    }
  }

  void _message(dynamic raw, int generation) {
    if (generation != _generation || !_wanted) return;
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! Map<String, dynamic> || decoded['v'] != 1) {
        _stop(ConnectionStatus.error,
            'El agente usa un protocolo incompatible. Actualiza las fuentes del computador.');
        return;
      }
      final type = decoded['type'];
      if (type == 'error') {
        _stop(
            decoded['code'] == 'unauthorized'
                ? ConnectionStatus.rejected
                : ConnectionStatus.error,
            decoded['message']?.toString() ?? 'El agente rechazó la conexión.');
        return;
      }
      if (type == 'welcome') {
        if (decoded['host'] is! String || decoded['capabilities'] is! List) {
          throw const FormatException('Welcome inválido');
        }
        _handshake?.cancel();
        status = ConnectionStatus.connected;
        detail = null;
        host = decoded['host'] as String;
        os = decoded['os']?.toString();
        capabilities =
            (decoded['capabilities'] as List).whereType<String>().toSet();
        _failures = 0;
        lastUpdate = DateTime.now();
        _watchdog?.cancel();
        _watchdog =
            Timer.periodic(const Duration(seconds: 1), (_) => checkFreshness());
      } else if (!connected) {
        throw const FormatException('Falta welcome');
      } else if (type == 'metrics') {
        if (decoded['cpu'] is! Map || decoded['mem'] is! Map) {
          throw const FormatException('Métricas inválidas');
        }
        metrics = decoded;
        lastUpdate = DateTime.now();
        final used = number(decoded['mem']['used']);
        final total = number(decoded['mem']['total']);
        history.add(lastUpdate!, {
          'cpu': number(decoded['cpu']['total']),
          'ram': used != null && total != null && total > 0
              ? used / total * 100
              : null,
          'disk_read': number(decoded['disk']?['read_bps']),
          'disk_write': number(decoded['disk']?['write_bps']),
          'net_down': number(decoded['net']?['down_bps']),
          'net_up': number(decoded['net']?['up_bps']),
        });
      } else if (type == 'processes') {
        processes = objectList(decoded['groups']);
      } else if (type == 'session_state') {
        sessionKnown = true;
        activeSession = decoded['active'] is Map<String, dynamic>
            ? decoded['active'] as Map<String, dynamic>
            : null;
      } else if (type == 'session_history') {
        reports = objectList(decoded['reports']);
      }
      final pending = _pending.remove(decoded['id']);
      if (pending != null) {
        if (decoded['ok'] == false) {
          pending.completeError(StateError(decoded['message']?.toString() ??
              'No se pudo realizar la acción.'));
        } else {
          pending.complete(decoded);
        }
      }
      _notify();
    } catch (_) {
      _stop(ConnectionStatus.error,
          'El agente envió un mensaje inválido. Revisa su versión.');
    }
  }

  void checkFreshness() {
    if (connected &&
        lastUpdate != null &&
        DateTime.now().difference(lastUpdate!) > staleAfter) {
      _lost(_generation);
    }
  }

  void _lost(int generation) {
    if (generation != _generation || !_wanted) return;
    ++_generation;
    _closeTransport();
    _clearLiveData();
    _failPending(
        'Se perdió la conexión. Comprueba el estado de la sesión al reconectar.');
    status = ConnectionStatus.reconnecting;
    _failures++;
    // Espera creciente acotada: no castigar al equipo ni al teléfono si el agente está apagado.
    final factor = 1 << (_failures - 1).clamp(0, 4);
    final milliseconds = (retryDelay.inMilliseconds * factor).clamp(1, 15000);
    detail =
        'Sin datos en vivo. Reintentando en ${(milliseconds / 1000).ceil()} s. Revisa USB y el agente.';
    _retry = Timer(Duration(milliseconds: milliseconds), _open);
    _notify();
  }

  Future<Map<String, dynamic>> request(String type,
      [Map<String, dynamic> fields = const {}]) {
    if (!connected) {
      return Future.error(
          StateError('Conecta el computador antes de continuar.'));
    }
    final id = '$_generation-${++_requestId}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    try {
      _socket!.add(jsonEncode({'v': 1, 'type': type, 'id': id, ...fields}));
    } catch (_) {
      _pending.remove(id);
      completer.completeError(StateError('No se pudo enviar la petición.'));
    }
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      throw StateError(
          'Sin respuesta. Reconecta para comprobar el estado antes de repetir.');
    }).whenComplete(() => _pending.remove(id));
  }

  Future<Map<String, dynamic>> prepareProcess(Map<String, dynamic> member) =>
      request('process_prepare', {
        'token': _token,
        'process': {
          for (final key in ['pid', 'exe', 'create_time']) key: member[key]
        },
      });

  Future<Map<String, dynamic>> terminateProcess(String ticket,
          {required bool force}) =>
      request('process_terminate', {
        'token': _token,
        'ticket': ticket,
        'confirmed': true,
        'force': force,
      });

  Future<void> loadHistory() async {
    await request('session_history');
  }

  void disconnect() => _stop(ConnectionStatus.disconnected, null);

  void _stop(ConnectionStatus next, String? reason) {
    _wanted = false;
    ++_generation;
    _token = '';
    _retry?.cancel();
    _closeTransport();
    _clearLiveData();
    _failPending('Conexión cerrada.');
    status = next;
    detail = reason;
    _notify();
  }

  void _closeTransport() {
    _handshake?.cancel();
    _watchdog?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
  }

  void _clearLiveData() {
    history.gap(DateTime.now());
    metrics = null;
    processes = [];
    capabilities = {};
    sessionKnown = false;
  }

  void _failPending(String message) {
    for (final pending in _pending.values) {
      pending.completeError(StateError(message));
    }
    _pending.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }
}

double? number(dynamic value) =>
    value is num && value.isFinite ? value.toDouble() : null;
List<Map<String, dynamic>> objectList(dynamic value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : [];
