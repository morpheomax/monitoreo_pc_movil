import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pc_monitor/connection/monitor_controller.dart';

Future<void> waitUntil(bool Function() condition) async {
  final limit = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(limit)) fail('No se alcanzó el estado esperado');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void send(WebSocket socket, String type,
        [Map<String, dynamic> fields = const {}]) =>
    socket.add(jsonEncode({'v': 1, 'type': type, ...fields}));

void main() {
  late HttpServer server;
  late List<WebSocket> sockets;
  late MonitorController controller;
  late String url;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'ws://127.0.0.1:${server.port}';
    sockets = [];
    controller = MonitorController(
        retryDelay: const Duration(milliseconds: 20),
        handshakeTimeout: const Duration(milliseconds: 150));
  });
  tearDown(() async {
    controller.dispose();
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  });

  test('token rechazado no provoca reintentos ni falso conectado', () async {
    var attempts = 0;
    server.listen((request) async {
      attempts++;
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {
        send(socket, 'error',
            {'code': 'unauthorized', 'message': 'Token inválido'});
        socket.close();
      });
    });
    controller.connect(url, 'wrong');
    await waitUntil(() => controller.status == ConnectionStatus.rejected);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(attempts, 1);
    expect(controller.connected, false);
    expect(controller.metrics, isNull);
  });

  test('recupera conexión y sesión sin conservar métricas obsoletas', () async {
    var attempts = 0;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      attempts++;
      socket.listen((_) {
        send(socket, 'welcome', {
          'host': 'test-pc',
          'os': 'windows',
          'capabilities': ['metrics', 'sessions']
        });
        send(socket, 'session_state', {
          'active': {'id': 'same-session', 'started_at': 1}
        });
        send(socket, 'metrics', {
          'cpu': {'total': 20},
          'mem': {'used': 50, 'total': 100}
        });
      });
    });
    controller.connect(url, 'secret');
    await waitUntil(() => controller.live);
    expect(controller.activeSession?['id'], 'same-session');
    await sockets.first.close();
    await waitUntil(() => controller.status == ConnectionStatus.reconnecting);
    expect(controller.metrics, isNull);
    await waitUntil(() => attempts >= 2 && controller.live);
    expect(controller.activeSession?['id'], 'same-session');
  });

  test('cancelar una conexión tardía impide enviar credenciales', () async {
    var sentHello = false;
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) => sentHello = true);
    });
    final lateSocket = Completer<WebSocket>();
    controller.dispose();
    controller = MonitorController(connector: (_) => lateSocket.future);
    controller.connect(url, 'secret');
    controller.disconnect();
    lateSocket.complete(await WebSocket.connect(url));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(controller.status, ConnectionStatus.disconnected);
    expect(sentHello, false);
  });

  test('timeout del handshake reintenta y desconectar cancela los reintentos',
      () async {
    var attempts = 0;
    server.listen((request) async {
      attempts++;
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
    });
    controller.connect(url, 'secret');
    await waitUntil(() => attempts >= 2);
    controller.disconnect();
    final stoppedAt = attempts;
    await Future<void>.delayed(const Duration(milliseconds: 220));
    expect(attempts, stoppedAt);
    expect(controller.status, ConnectionStatus.disconnected);
  });

  test('errores de sesión se muestran sin desconectar el monitor', () async {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((raw) {
        final message = jsonDecode(raw as String) as Map<String, dynamic>;
        if (message['type'] == 'hello') {
          send(socket, 'welcome', {
            'host': 'pc',
            'capabilities': ['sessions']
          });
        } else {
          send(socket, 'ack', {
            'id': message['id'],
            'ok': false,
            'message': 'Ya hay una sesión activa'
          });
        }
      });
    });
    controller.connect(url, 'secret');
    await waitUntil(() => controller.connected);
    await expectLater(controller.request('session_start'), throwsStateError);
    expect(controller.connected, true);
  });
}
