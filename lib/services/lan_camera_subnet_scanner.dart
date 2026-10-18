import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import 'lan_camera_discovery_service.dart';

class LanScanCancelToken {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

class LanScanRange {
  const LanScanRange(this.hosts, this.broadcast, this.description, this.warning);
  final List<String> hosts;
  final String broadcast;
  final String description;
  final String? warning;
}

/// Complemento TCP do Minha Câmera: limitado à LAN Wi-Fi atual, sem senhas.
/// A porta aberta NÃO garante câmera; RTSP exige confirmação pelo OPTIONS.
class LanCameraSubnetScanner {
  const LanCameraSubnetScanner._();
  static const _channel = MethodChannel('vigiaia/native');
  static const _ports = <int>[554, 8554, 10554, 8555, 7447, 80, 8080, 5000];

  static Future<LanScanRange> localRange() async {
    if (!Platform.isAndroid) {
      return const LanScanRange([], '', '', 'Varredura TCP disponível apenas no Android.');
    }
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>('lanScanRange');
      if (data != null) {
        final hosts = (data['hosts'] as List?)?.whereType<String>().toList() ?? [];
        return LanScanRange(
          hosts.take(254).toList(growable: false),
          data['broadcast'] as String? ?? '',
          data['description'] as String? ?? '',
          data['error'] as String?,
        );
      }
    } catch (_) {
      // Compatibilidade com Android antigo: somente interfaces WLAN/AP, nunca celular.
    }
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final network in interfaces) {
      if (!RegExp(r'^(wlan|ap|swlan|softap)').hasMatch(network.name.toLowerCase())) continue;
      for (final address in network.addresses) {
        final octets = address.address.split('.').map(int.tryParse).toList();
        if (octets.length != 4 || octets.any((e) => e == null)) continue;
        final prefix = '${octets[0]}.${octets[1]}.${octets[2]}';
        return LanScanRange(
          [for (var i = 1; i < 255; i++) if (i != octets[3]) '$prefix.$i'],
          '$prefix.255', '$prefix.0/24',
          'Máscara Wi-Fi indisponível; busca limitada ao /24 local.',
        );
      }
    }
    return const LanScanRange([], '', '',
      'Sem rede Wi-Fi/hotspot IPv4. Verifique a conexão, permissões e isolamento do roteador.');
  }

  static Future<void> multicast(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('lanMulticastLock', {'enabled': enabled});
    } catch (_) { /* Em aparelhos sem suporte, a varredura TCP permanece. */ }
  }

  static Future<void> scan({
    required LanScanRange range,
    required LanScanCancelToken cancel,
    required void Function(LanCameraCandidate) onFound,
    void Function(int checked, int total)? onProgress,
  }) async {
    final hosts = range.hosts.where(_privateHost).take(254).toList(growable: false);
    if (hosts.isEmpty || cancel.cancelled) return;
    var index = 0;
    var done = 0;
    Future<void> worker() async {
      while (!cancel.cancelled && index < hosts.length) {
        final host = hosts[index++];
        try {
          final candidate = await probeHost(host, cancel);
          if (candidate != null && !cancel.cancelled) onFound(candidate);
        } catch (_) { /* Host fora do ar não deve interromper outros testes. */ }
        done++;
        if (!cancel.cancelled && (done % 8 == 0 || done == hosts.length)) {
          onProgress?.call(done, hosts.length);
        }
      }
    }
    await Future.wait(List.generate(min(24, hosts.length), (_) => worker()));
  }

  static bool _privateHost(String host) {
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((e) => e == null || e < 0 || e > 255)) return false;
    final a = parts[0]!, b = parts[1]!;
    return a == 10 || a == 192 && b == 168 ||
      a == 172 && b >= 16 && b <= 31 || a == 169 && b == 254;
  }

  static Future<LanCameraCandidate?> probeHost(String host, LanScanCancelToken cancel) async {
    if (!_privateHost(host)) return null;
    for (final port in _ports) {
      if (cancel.cancelled) return null;
      Socket? socket;
      try {
        socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 320));
        // Nunca enviar credenciais ou iniciar fluxo de vídeo durante a busca.
        final request = 'OPTIONS rtsp://$host:$port/ RTSP/1.0\r\n'
            'CSeq: 1\r\nUser-Agent: VigiaIA-LanScan\r\n\r\n';
        socket.add(ascii.encode(request));
        await socket.flush();
        String response = '';
        try {
          response = await socket
              .take(1)
              .map((chunk) => latin1.decode(chunk))
              .first
              .timeout(const Duration(milliseconds: 500));
        } on TimeoutException { /* Porta TCP aberta, mas serviço silencioso. */ }
        final firstLine = response.split(RegExp(r'[\r\n]')).first;
        final confirmed = firstLine.toUpperCase().startsWith('RTSP/');
        final http = firstLine.toUpperCase().startsWith('HTTP/');
        final type = confirmed ? LanCameraKind.rtsp : LanCameraKind.network;
        final protocol = confirmed ? 'RTSP confirmado' : http ? 'HTTP detectado' : 'TCP aberto (não verificado)';
        return LanCameraCandidate(
          host: host, kind: type, port: port, protocol: protocol,
          name: confirmed ? 'Câmera RTSP · $host' : 'Dispositivo na rede · $host',
        );
      } on SocketException { /* Host não responde nesta porta. */
      } on TimeoutException { /* Respeitar o tempo limite para cada conexão. */
      } finally {
        socket?.destroy();
      }
    }
    return null;
  }
}
