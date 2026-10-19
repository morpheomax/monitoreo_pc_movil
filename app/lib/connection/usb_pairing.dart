import 'dart:convert';
import 'dart:io';

class UsbCredentials {
  const UsbCredentials(this.url, this.token, this.host, this.os);
  final String url;
  final String token;
  final String host;
  final String os;
}

/// El enlace de un uso llega desde ADB; jamás aceptar hosts externos/redirecciones.
Future<UsbCredentials> fetchUsbCredentials(String link) async {
  final uri = Uri.tryParse(link);
  if (uri == null ||
      uri.scheme != 'http' ||
      uri.host != '127.0.0.1' ||
      !uri.hasPort ||
      uri.port < 1 ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !RegExp(r'^/pair/[A-Za-z0-9_-]{43}$').hasMatch(uri.path)) {
    throw const FormatException('Enlace USB inválido');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request =
        await client.getUrl(uri).timeout(const Duration(seconds: 5));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw const FormatException('Conexión USB vencida o ya utilizada');
    }
    // Limitar tamaño y duración, incluso si otro proceso ocupa el puerto local.
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 5))) {
      bytes.addAll(chunk);
      if (bytes.length > 4096) {
        throw const FormatException('Respuesta inválida');
      }
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic> || data['v'] != 1) {
      throw const FormatException('Protocolo USB inválido');
    }
    final url = data['url'];
    final token = data['token'];
    final host = data['host'];
    final os = data['os'];
    final agent = url is String ? Uri.tryParse(url) : null;
    if (agent == null ||
        agent.scheme != 'ws' ||
        agent.host != '127.0.0.1' ||
        agent.userInfo.isNotEmpty ||
        !agent.hasPort ||
        agent.port < 1 ||
        agent.hasQuery ||
        agent.hasFragment ||
        agent.path.isNotEmpty ||
        token is! String ||
        token.trim().isEmpty ||
        token.length > 1024 ||
        host is! String ||
        host.isEmpty ||
        host.length > 255 ||
        os is! String ||
        !{'Windows', 'Darwin', 'Linux'}.contains(os)) {
      throw const FormatException('Datos del equipo inválidos');
    }
    return UsbCredentials(
        url as String, token, host, os == 'Darwin' ? 'macOS' : os);
  } finally {
    client.close(force: true);
  }
}
