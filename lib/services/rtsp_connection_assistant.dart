import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Caminhos conhecidos do Minha Câmera. São tentativas, NÃO endereços
/// garantidos para uma marca ou para um aparelho específico.
class RtspPathOption {
  const RtspPathOption(this.label, this.path);
  final String label;
  final String path;
}

class RtspConnectionAssistant {
  const RtspConnectionAssistant._();

  static const paths = <RtspPathOption>[
    RtspPathOption('Padrão (sem caminho)', ''),
    RtspPathOption('Stream principal · /stream1', '/stream1'),
    RtspPathOption('Stream leve · /stream2', '/stream2'),
    RtspPathOption('ONVIF · /onvif1', '/onvif1'),
    RtspPathOption('ONVIF · /onvif2', '/onvif2'),
    RtspPathOption('Dahua / Intelbras · principal', '/cam/realmonitor?channel=1&subtype=0'),
    RtspPathOption('Dahua / Intelbras · secundário', '/cam/realmonitor?channel=1&subtype=1'),
    RtspPathOption('Hikvision · principal', '/Streaming/Channels/101'),
    RtspPathOption('Hikvision · secundário', '/Streaming/Channels/102'),
    RtspPathOption('Reolink · principal', '/h264Preview_01_main'),
    RtspPathOption('Reolink · secundário', '/h264Preview_01_sub'),
    RtspPathOption('Canal 0 · /live/ch00_0', '/live/ch00_0'),
    RtspPathOption('Canal 1 · /live/ch00_1', '/live/ch00_1'),
    RtspPathOption('Canal 1 · /11', '/11'),
    RtspPathOption('Canal 1 · /12', '/12'),
    RtspPathOption('SDP · /live.sdp', '/live.sdp'),
    RtspPathOption('Vídeo · /video1', '/video1'),
  ];

  static const extraPaths = <String>[
    '/stream0', '/live/main', '/live/0/MAIN', '/ch1/main',
    '/h264/ch1/main/av_stream', '/media/video1', '/0', '/1',
  ];

  static String normalizedPath(String input) {
    final text = input.trim();
    if (text.isEmpty || text == '/' || text.toLowerCase() == 'default') {
      return '';
    }
    return text.startsWith('/') ? text : '/$text';
  }

  static String normalizedHost(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return '';
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.scheme.toLowerCase() == 'rtsp') {
      return parsed.host;
    }
    return raw;
  }

  static bool validHost(String input) {
    if (input.isEmpty || input.length > 253 || input.contains(RegExp(r'[\s/@?#\\]'))) {
      return false;
    }
    final address = InternetAddress.tryParse(input);
    if (address != null) return address.type == InternetAddressType.IPv4;
    return RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?$').hasMatch(input) &&
        !input.contains('..');
  }

  static bool isPrivateIpv4(String host) {
    final addr = InternetAddress.tryParse(host);
    if (addr == null || addr.type != InternetAddressType.IPv4) return false;
    final p = addr.rawAddress;
    return p[0] == 127 || p[0] == 10 || p[0] == 192 && p[1] == 168 ||
        p[0] == 172 && p[1] >= 16 && p[1] <= 31 ||
        p[0] == 169 && p[1] == 254;
  }

  static Uri? parseInput(String input) {
    final value = input.trim();
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme.toLowerCase() == 'rtsp' &&
        validHost(uri.host) && !uri.hasFragment && (!uri.hasPort || uri.port > 0 && uri.port <= 65535)
        ? uri : null;
  }

  /// A URI retornada tem credenciais percent-encoded; nunca a exibir em logs.
  static String? buildUrl({
    required String host, required int port, required String path,
    String username = '', String password = '',
  }) {
    final cleanHost = normalizedHost(host);
    if (!validHost(cleanHost) || port < 1 || port > 65535) return null;
    final cleanPath = normalizedPath(path);
    if (cleanPath.contains(RegExp(r'[\r\n#]'))) return null;
    final userInfo = username.isEmpty && password.isEmpty ? '' :
        '${Uri.encodeComponent(username)}:${Uri.encodeComponent(password)}@';
    final value = 'rtsp://$userInfo$cleanHost:$port$cleanPath';
    return parseInput(value) == null ? null : value;
  }

  static String withoutCredentials(String url) {
    final uri = parseInput(url);
    if (uri == null) return '';
    return uri.replace(userInfo: '').toString();
  }

  static String redact(String text, {String username = '', String password = ''}) {
    var sanitized = text.replaceAll(RegExp(r'rtsp://[^\s/@]+@', caseSensitive: false), 'rtsp://***@');
    for (final secret in <String>[username, password]) {
      if (secret.isNotEmpty) sanitized = sanitized.replaceAll(secret, '***');
    }
    return sanitized;
  }
}

enum RtspProbeState { video, authRequired, credentialsRejected, pathNotFound, unavailable, unsupported, noVideo }

class RtspProbeResult {
  const RtspProbeResult(this.state, this.message, {this.statusCode});
  final RtspProbeState state;
  final String message;
  final int? statusCode;
  bool get verifiedVideo => state == RtspProbeState.video;
}

class _RtspReply {
  const _RtspReply(this.code, this.headers, this.body);
  final int code;
  final Map<String, String> headers;
  final String body;
}

/// Testa DESCRIBE/SDP em rede local mediante ação do usuário. Não inicia PLAY,
/// não armazena a senha e não declara sucesso apenas por porta aberta.
class RtspConnectionProbe {
  const RtspConnectionProbe._();

  static Future<RtspProbeResult> test({
    required String host, required int port, required String path,
    String username = '', String password = '',
  }) async {
    if (!RtspConnectionAssistant.isPrivateIpv4(host)) {
      return const RtspProbeResult(RtspProbeState.unsupported,
        'Teste automático restrito a endereços IPv4 da rede privada. É possível cadastrar manualmente.');
    }
    final uri = RtspConnectionAssistant.buildUrl(host: host, port: port, path: path);
    if (uri == null) {
      return const RtspProbeResult(RtspProbeState.unsupported, 'Endereço RTSP inválido.');
    }
    try {
      final first = await _request(host, port, uri);
      if (first == null) {
        return const RtspProbeResult(RtspProbeState.unavailable,
          'Câmera não respondeu ao DESCRIBE; confira Wi-Fi, IP e porta.');
      }
      if (first.code == 401) {
        if (username.isEmpty && password.isEmpty) {
          return const RtspProbeResult(RtspProbeState.authRequired,
            'Câmera exige usuário e senha RTSP (401).', statusCode: 401);
        }
        final auth = _authorization(
          first.headers['www-authenticate'] ?? '', uri, username, password);
        if (auth == null) {
          return const RtspProbeResult(RtspProbeState.unsupported,
            'A câmera usa uma autenticação não suportada pelo teste.');
        }
        final second = await _request(host, port, uri, authorization: auth);
        if (second == null) {
          return const RtspProbeResult(RtspProbeState.unavailable,
            'Câmera encerrou a conexão após pedir autenticação.');
        }
        return _interpret(second);
      }
      return _interpret(first);
    } catch (_) {
      return const RtspProbeResult(RtspProbeState.unavailable,
        'Sem resposta da câmera. Confira endereço, porta e rede Wi-Fi.');
    }
  }

  static RtspProbeResult _interpret(_RtspReply reply) => switch (reply.code) {
    200 => RegExp(r'^m=video\s', multiLine: true, caseSensitive: false).hasMatch(reply.body)
        ? const RtspProbeResult(RtspProbeState.video,
            'Vídeo confirmado: DESCRIBE 200 com faixa de vídeo no SDP.', statusCode: 200)
        : const RtspProbeResult(RtspProbeState.noVideo,
            'RTSP respondeu 200, mas não anunciou vídeo no SDP.', statusCode: 200),
    401 || 403 => RtspProbeResult(RtspProbeState.credentialsRejected,
        'Credenciais não aceitas ou acesso proibido (${reply.code}).', statusCode: reply.code),
    404 || 454 => RtspProbeResult(RtspProbeState.pathNotFound,
        'Caminho de vídeo não encontrado (${reply.code}).', statusCode: reply.code),
    _ => RtspProbeResult(RtspProbeState.unsupported,
        'RTSP retornou ${reply.code}; vídeo não confirmado.', statusCode: reply.code),
  };

  static Future<_RtspReply?> _request(
      String host, int port, String uri, {String? authorization}) async {
    Socket? socket;
    StreamSubscription<List<int>>? subscription;
    try {
      socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 1400));
      final result = Completer<_RtspReply?>();
      final received = <int>[];
      subscription = socket.listen((chunk) {
        received.addAll(chunk);
        if (received.length > 128 * 1024) {
          if (!result.isCompleted) { result.complete(null); }
          return;
        }
        final separator = _headerSeparator(received);
        if (separator < 0) return;
        final header = latin1.decode(received.sublist(0, separator));
        final lines = header.split(RegExp(r'\r?\n'));
        final status = RegExp(r'^RTSP/\d+\.\d+\s+(\d{3})').firstMatch(lines.first);
        if (status == null) {
          if (!result.isCompleted) { result.complete(null); }
          return;
        }
        final headers = <String, String>{};
        for (final line in lines.skip(1)) {
          final colon = line.indexOf(':');
          if (colon > 0) {
            headers[line.substring(0, colon).trim().toLowerCase()] =
                line.substring(colon + 1).trim();
          }
        }
        final length = int.tryParse(headers['content-length'] ?? '0') ?? 0;
        if (length < 0 || length > 96 * 1024) {
          if (!result.isCompleted) { result.complete(null); }
          return;
        }
        final bodyStart = separator + (received[separator] == 13 ? 4 : 2);
        if (received.length < bodyStart + length) return;
        final body = utf8.decode(received.sublist(bodyStart, bodyStart + length), allowMalformed: true);
        if (!result.isCompleted) {
          result.complete(_RtspReply(int.parse(status.group(1)!), headers, body));
        }
      }, onError: (Object _) {
        if (!result.isCompleted) { result.complete(null); }
      }, onDone: () {
        if (!result.isCompleted) { result.complete(null); }
      });
      final payload = StringBuffer()
        ..write('DESCRIBE $uri RTSP/1.0\r\n')
        ..write('CSeq: 1\r\n')
        ..write('Accept: application/sdp\r\n')
        ..write('User-Agent: VigiaIA\r\n');
      if (authorization != null) payload.write('Authorization: $authorization\r\n');
      payload.write('\r\n');
      socket.add(ascii.encode(payload.toString()));
      await socket.flush();
      return await result.future.timeout(const Duration(milliseconds: 2200), onTimeout: () => null);
    } finally {
      await subscription?.cancel();
      socket?.destroy();
    }
  }

  static int _headerSeparator(List<int> bytes) {
    for (var i = 0; i + 3 < bytes.length; i++) {
      if (bytes[i] == 13 && bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 && bytes[i + 3] == 10) { return i; }
    }
    for (var i = 0; i + 1 < bytes.length; i++) {
      if (bytes[i] == 10 && bytes[i + 1] == 10) { return i; }
    }
    return -1;
  }

  static String? _authorization(String header, String uri, String user, String pass) {
    if (header.isEmpty) return null;
    if (header.toLowerCase().startsWith('basic')) {
      return 'Basic ${base64.encode(utf8.encode('$user:$pass'))}';
    }
    if (!header.toLowerCase().startsWith('digest')) return null;
    final params = <String, String>{};
    for (final match in RegExp(r'(\w+)\s*=\s*(?:"([^"]*)"|([^,\s]+))').allMatches(header)) {
      params[match.group(1)!.toLowerCase()] = match.group(2) ?? match.group(3)!;
    }
    final realm = params['realm'];
    final nonce = params['nonce'];
    final algorithm = (params['algorithm'] ?? 'MD5').toUpperCase();
    final qopList = (params['qop'] ?? '').split(',').map((e) => e.trim().toLowerCase()).toList();
    if (realm == null || nonce == null || algorithm != 'MD5' ||
        (params.containsKey('qop') && !qopList.contains('auth'))) {
      return null;
    }
    String md5Text(String input) => md5.convert(utf8.encode(input)).toString();
    final ha1 = md5Text('$user:$realm:$pass');
    final ha2 = md5Text('DESCRIBE:$uri');
    // Cnonce não contém material secreto, mas não deve reutilizar o nonce em outro host.
    final cnonce = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final hasQop = params.containsKey('qop');
    final digest = hasQop
        ? md5Text('$ha1:$nonce:00000001:$cnonce:auth:$ha2')
        : md5Text('$ha1:$nonce:$ha2');
    String quoted(String value) => value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    final fields = <String>[
      'username="${quoted(user)}"', 'realm="${quoted(realm)}"',
      'nonce="${quoted(nonce)}"', 'uri="${quoted(uri)}"',
      'response="$digest"', 'algorithm=MD5',
      if (hasQop) ...['qop=auth', 'nc=00000001', 'cnonce="$cnonce"'],
      if (params['opaque'] != null) 'opaque="${quoted(params['opaque']!)}"',
    ];
    return 'Digest ${fields.join(', ')}';
  }

  static Future<(String?, RtspProbeResult)> findVideo({
    required String host, required int port,
    String username = '', String password = '',
    String initialPath = '',
    void Function(int, int)? onProgress,
    bool Function()? cancelled,
  }) async {
    final candidates = <String>{
      if (initialPath.isNotEmpty) RtspConnectionAssistant.normalizedPath(initialPath),
      ...RtspConnectionAssistant.paths.map((option) => option.path),
      ...RtspConnectionAssistant.extraPaths,
    }.take(20).toList(growable: false);
    RtspProbeResult last = const RtspProbeResult(RtspProbeState.pathNotFound,
      'Nenhum caminho foi confirmado. Use o caminho indicado pela câmera/DVR.');
    for (var index = 0; index < candidates.length; index++) {
      if (cancelled?.call() == true) break;
      onProgress?.call(index + 1, candidates.length);
      final result = await test(host: host, port: port,
        path: candidates[index], username: username, password: password);
      if (result.verifiedVideo) return (candidates[index], result);
      if (result.state == RtspProbeState.authRequired ||
          result.state == RtspProbeState.credentialsRejected ||
          result.state == RtspProbeState.unavailable ||
          result.state == RtspProbeState.unsupported) {
        return (null, result);
      }
      last = result;
    }
    return (null, RtspProbeResult(last.state,
      'Nenhum dos ${candidates.length} caminhos testados confirmou vídeo. Confira o perfil ONVIF e o manual da câmera.'));
  }
}
