import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Descoberta acionada pelo usuario e limitada no tempo. Nunca devolve tokens,
/// senhas ou URLs /live/ protegidas; pareamento Vigia IA continua por QR.
enum LanCameraKind { vigiaIa, onvif, rtsp, network }

class LanCameraCandidate {
  const LanCameraCandidate({
    required this.host,
    required this.kind,
    required this.name,
    this.onvifServiceUrl,
    this.port,
    this.protocol,
  });
  final String host;
  final LanCameraKind kind;
  final String name;
  final String? onvifServiceUrl;
  final int? port;
  final String? protocol;
  String get key => '${kind.name}:$host';
}

class LanCameraDiscoveryService {
  const LanCameraDiscoveryService._();

  static const int _vigiaPort = 8766;
  static const String _vigiaProbe = 'VIGIAIA_DISCOVER_V1';

  static bool _privateIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = <int>[];
    for (final part in parts) {
      if (part.isEmpty || (part.length > 1 && part.startsWith('0'))) return false;
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
      octets.add(value);
    }
    final a = octets[0];
    final b = octets[1];
    return a == 10 || (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) || (a == 169 && b == 254) ||
        (a == 100 && b >= 64 && b <= 127);
  }

  /// Aceita apenas host privado fornecido pela rede, nunca URL arbitraria.
  static LanCameraCandidate? parseResponse(String payload, String fromHost) {
    if (!_privateIpv4(fromHost) || payload.length > 12288) return null;
    if (payload.startsWith('VIGIAIA_HERE_V1|')) {
      final model = payload.substring('VIGIAIA_HERE_V1|'.length).trim();
      return LanCameraCandidate(
        host: fromHost,
        kind: LanCameraKind.vigiaIa,
        name: model.isEmpty ? 'Vigia IA · $fromHost' : 'Vigia IA · ${model.substring(0, min(model.length, 48))}',
      );
    }
    if (!payload.contains('ProbeMatches') && !payload.contains('ProbeMatch')) {
      return null;
    }
    // WS-Discovery ONVIF retorna XAddrs com o endpoint HTTP do servico,
    // nao uma URL RTSP comprovada. Nunca inferir token/caminho de video.
    final match = RegExp(r'<(?:[A-Za-z0-9_]+:)?XAddrs\b[^>]*>([^<]+)</(?:[A-Za-z0-9_]+:)?XAddrs>',
        caseSensitive: false).firstMatch(payload);
    if (match == null) return null;
    for (final raw in match.group(1)!.split(RegExp(r'\s+'))) {
      final uri = Uri.tryParse(raw.trim());
      if (uri == null || !{'http', 'https'}.contains(uri.scheme) ||
          uri.userInfo.isNotEmpty || uri.hasFragment || !_privateIpv4(uri.host) ||
          uri.host != fromHost) {
        continue;
      }
      return LanCameraCandidate(
        host: uri.host,
        kind: LanCameraKind.onvif,
        name: 'Câmera ONVIF · ${uri.host}',
        onvifServiceUrl: uri.toString(),
      );
    }
    return null;
  }

  static Future<List<LanCameraCandidate>> discover({
    Duration timeout = const Duration(seconds: 5),
    void Function(LanCameraCandidate candidate)? onFound,
    void Function(String status)? onStatus,
    bool Function()? cancelled,
    List<String>? targetBroadcasts,
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final results = <String, LanCameraCandidate>{};
    StreamSubscription<RawSocketEvent>? subscription;
    try {
      socket.broadcastEnabled = true;
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        while (true) {
          final datagram = socket.receive();
          if (datagram == null) break;
          if (datagram.data.length > 12288) continue;
          final candidate = parseResponse(
            utf8.decode(datagram.data, allowMalformed: true),
            datagram.address.address,
          );
          if (candidate != null && !results.containsKey(candidate.key) &&
              results.length < 48) {
            results[candidate.key] = candidate;
            onFound?.call(candidate);
          }
        }
      });
      final probe = utf8.encode(_vigiaProbe);
      // Broadcast IPv4 funciona em varias redes hotspot e LAN simples.
      for (final address in <String>{'255.255.255.255', ...?targetBroadcasts}) {
        try { socket.send(probe, InternetAddress(address), _vigiaPort); }
        on SocketException { /* Broadcast bloqueado por interface. */ }
      }
      final random = Random.secure();
      final uuid = List<int>.generate(16, (_) => random.nextInt(256))
          .map((e) => e.toRadixString(16).padLeft(2, '0')).join();
      final xml = '''<?xml version="1.0" encoding="UTF-8"?>
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
 xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
 xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
 xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
<e:Header><w:MessageID>urn:uuid:$uuid</w:MessageID>
<w:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>
<w:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>
</e:Header><e:Body><d:Probe><d:Types>dn:NetworkVideoTransmitter</d:Types>
</d:Probe></e:Body></e:Envelope>''';
      try {
        socket.send(utf8.encode(xml), InternetAddress('239.255.255.250'), 3702);
      } on SocketException {
        // Algumas interfaces nao permitem multicast.
      }
      onStatus?.call('Aguardando respostas de ONVIF e Vigia IA…');
      final waitUntil = DateTime.now().add(timeout);
      while (cancelled?.call() != true && DateTime.now().isBefore(waitUntil)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return List<LanCameraCandidate>.unmodifiable(results.values);
    } finally {
      await subscription?.cancel();
      socket.close();
    }
  }
}
