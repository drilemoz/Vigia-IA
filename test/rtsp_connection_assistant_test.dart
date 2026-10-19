import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/rtsp_connection_assistant.dart';

Future<ServerSocket> mockRtsp(Future<String> Function(String) response) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((client) async {
    try {
      final request = await client
          .transform(utf8.decoder)
          .first.timeout(const Duration(seconds: 2));
      final reply = await response(request);
      client.write(reply);
      await client.flush();
    } finally {
      client.destroy();
    }
  });
  return server;
}

String rtspReply(int code, {String body = '', String otherHeaders = ''}) =>
    'RTSP/1.0 $code ${code == 200 ? 'OK' : code == 401 ? 'Unauthorized' : 'Not Found'}\r\n'
    'CSeq: 1\r\n$otherHeaders'
    'Content-Type: application/sdp\r\n'
    'Content-Length: ${utf8.encode(body).length}\r\n\r\n$body';

void main() {
  group('Assistente RTSP', () {
    test('preserva caminho/query e codifica senha com @ e símbolos', () {
      final url = RtspConnectionAssistant.buildUrl(
        host: '192.168.100.209', port: 554,
        path: '/cam/realmonitor?channel=1&subtype=0',
        username: 'admin', password: '@um:sinal#?');
      expect(url, isNotNull);
      final uri = RtspConnectionAssistant.parseInput(url!);
      expect(uri, isNotNull);
      expect(uri!.host, '192.168.100.209');
      expect(uri.path, '/cam/realmonitor');
      expect(uri.query, 'channel=1&subtype=0');
      expect(url, contains('%40'));
      expect(url, isNot(contains('@um:sinal')));
      expect(RtspConnectionAssistant.withoutCredentials(url),
          'rtsp://192.168.100.209:554/cam/realmonitor?channel=1&subtype=0');
    });

    test('URL válida não exige /stream1 nem caminho arbitrário', () {
      expect(RtspConnectionAssistant.parseInput('rtsp://192.168.1.20:554/'), isNotNull);
      expect(RtspConnectionAssistant.parseInput('rtsp://192.168.1.20'), isNotNull);
      expect(RtspConnectionAssistant.parseInput('http://192.168.1.20/stream1'), isNull);
      expect(RtspConnectionAssistant.buildUrl(host: '192.168.1.20',
          port: 70000, path: '/stream1'), isNull);
      expect(RtspConnectionAssistant.normalizedPath('Default'), '');
      expect(RtspConnectionAssistant.normalizedPath('stream1'), '/stream1');
    });

    test('lista inclui opções comuns do Minha Câmera', () {
      final paths = RtspConnectionAssistant.paths.map((x) => x.path).toSet();
      expect(paths, contains('/stream1'));
      expect(paths, contains('/Streaming/Channels/101'));
      expect(paths, contains('/cam/realmonitor?channel=1&subtype=0'));
      expect(paths, contains('/h264Preview_01_main'));
    });
  });

  group('Teste RTSP real por TCP loopback', () {
    test('DESCRIBE 200 com vídeo no SDP confirma apenas a descrição', () async {
      final server = await mockRtsp((_) async => rtspReply(200,
          body: 'v=0\r\nm=video 0 RTP/AVP 96\r\na=rtpmap:96 H264/90000\r\n'));
      addTearDown(server.close);
      final result = await RtspConnectionProbe.test(host: '127.0.0.1',
          port: server.port, path: '/stream1');
      expect(result.state, RtspProbeState.video);
      expect(result.verifiedVideo, isTrue);
    });

    test('porta RTSP não equivale a vídeo', () async {
      final server = await mockRtsp((_) async => rtspReply(404));
      addTearDown(server.close);
      final result = await RtspConnectionProbe.test(host: '127.0.0.1',
          port: server.port, path: '/stream1');
      expect(result.state, RtspProbeState.pathNotFound);
      expect(result.verifiedVideo, isFalse);
    });

    test('login Basic anunciado pelo servidor usa segunda requisição', () async {
      final server = await mockRtsp((request) async {
        if (request.contains('Authorization: Basic ')) {
          return rtspReply(200, body: 'v=0\r\nm=video 0 RTP/AVP 96\r\n');
        }
        return rtspReply(401,
          otherHeaders: 'WWW-Authenticate: Basic realm="camera"\r\n');
      });
      addTearDown(server.close);
      final result = await RtspConnectionProbe.test(host: '127.0.0.1',
          port: server.port, path: '/stream1', username: 'admin', password: 'secret');
      expect(result.verifiedVideo, isTrue);
    });

    test('servidor com autenticação exigida não é confundido com falha de porta', () async {
      final server = await mockRtsp((_) async => rtspReply(401,
          otherHeaders: 'WWW-Authenticate: Digest realm="camera", nonce="abc", qop="auth"\r\n'));
      addTearDown(server.close);
      final result = await RtspConnectionProbe.test(host: '127.0.0.1',
          port: server.port, path: '/stream1');
      expect(result.state, RtspProbeState.authRequired);
    });
  });
}
