import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pc_monitor/connection/usb_pairing.dart';

void main() {
  const nonce = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';

  test('rechaza destinos externos y enlaces con parámetros antes de acceder',
      () async {
    for (final link in [
      'http://example.com:1234/pair/$nonce',
      'http://localhost:1234/pair/$nonce',
      'https://127.0.0.1:1234/pair/$nonce',
      'http://127.0.0.1:1234/pair/$nonce?token=other',
      'http://user@127.0.0.1:1234/pair/$nonce',
      'http://127.0.0.1:1234/pair/short',
    ]) {
      await expectLater(fetchUsbCredentials(link), throwsFormatException);
    }
  });

  test('recibe token en memoria, valida versión y no sigue redirecciones',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var mode = 'valid';
    server.listen((request) async {
      if (mode == 'redirect') {
        request.response.statusCode = 302;
        request.response.headers.set('location', 'http://example.com');
      } else {
        request.response.write(jsonEncode({
          'v': mode == 'version' ? 2 : 1,
          'url': mode == 'external'
              ? 'ws://example.com:8765'
              : 'ws://127.0.0.1:8765',
          'token': 'test-memory-only',
          'host': 'Test Mac',
          'os': 'Darwin',
        }));
      }
      await request.response.close();
    });
    final link = 'http://127.0.0.1:${server.port}/pair/$nonce';
    final credentials = await fetchUsbCredentials(link);
    expect(credentials.host, 'Test Mac');
    expect(credentials.os, 'macOS');
    expect(credentials.token, 'test-memory-only');
    for (final invalid in ['redirect', 'version', 'external']) {
      mode = invalid;
      await expectLater(fetchUsbCredentials(link), throwsFormatException);
    }
  });
}
