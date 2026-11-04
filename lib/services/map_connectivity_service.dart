import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/map_connectivity_status.dart';

typedef MapConnectivityProbe = Future<bool> Function();

class MapConnectivityService extends ChangeNotifier {
  MapConnectivityService({
    MapConnectivityProbe? probe,
    this.probeInterval = const Duration(seconds: 15),
    this.offlineProbeInterval = const Duration(seconds: 60),
    this.failuresBeforeOffline = 2,
  }) : _probe = probe ?? _defaultProbe;

  static final MapConnectivityService instance = MapConnectivityService();

  final MapConnectivityProbe _probe;
  final Duration probeInterval;
  final Duration offlineProbeInterval;
  final int failuresBeforeOffline;
  final Set<Object> _consumers = <Object>{};

  Timer? _timer;
  bool _checking = false;
  int _consecutiveFailures = 0;
  MapConnectivityState _state = MapConnectivityState.unknown;
  DateTime? _lastCheckedAt;

  MapConnectivityState get state => _state;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  bool get isOnline => _state.isOnline;
  bool get isOffline => _state.isOffline;
  bool get checking => _checking;
  Duration get currentPollingInterval => _state.isOffline
      ? offlineProbeInterval
      : probeInterval;

  void _restartPolling() {
    _timer?.cancel();
    _timer = null;
    if (_consumers.isEmpty) return;
    _timer = Timer.periodic(
      currentPollingInterval,
      (_) => unawaited(checkNow()),
    );
  }

  Future<void> acquire(Object consumer) async {
    final first = _consumers.isEmpty;
    _consumers.add(consumer);
    if (first) _restartPolling();
    await checkNow(force: true);
  }

  void release(Object consumer) {
    _consumers.remove(consumer);
    if (_consumers.isNotEmpty) return;
    _timer?.cancel();
    _timer = null;
  }

  Future<MapConnectivityState> checkNow({bool force = false}) async {
    if (_checking) return _state;
    if (!force && _consumers.isEmpty) return _state;
    _checking = true;
    final previous = _state;
    try {
      final online = await _probe();
      _lastCheckedAt = DateTime.now();
      if (online) {
        _consecutiveFailures = 0;
        _state = MapConnectivityState.online;
      } else {
        _registerFailure();
      }
    } catch (_) {
      _lastCheckedAt = DateTime.now();
      _registerFailure();
    } finally {
      _checking = false;
    }
    if (_state != previous) {
      _restartPolling();
      notifyListeners();
    }
    return _state;
  }

  void _registerFailure() {
    _consecutiveFailures += 1;
    final threshold = failuresBeforeOffline < 1 ? 1 : failuresBeforeOffline;
    if (_state == MapConnectivityState.unknown ||
        _consecutiveFailures >= threshold) {
      _state = MapConnectivityState.offline;
    }
  }

  /// HTTPS validado (TLS e status esperado), não apenas resolução DNS.
  /// Uma página de login de Wi-Fi não deve ser considerada internet funcional.
  static final List<Uri> connectivityEndpoints = <Uri>[
    Uri.https('connectivitycheck.gstatic.com', '/generate_204'),
    Uri.https('www.google.com', '/generate_204'),
  ];

  static bool validProbeResponse(Uri endpoint, int statusCode) =>
      endpoint.scheme == 'https' &&
      endpoint.path == '/generate_204' &&
      (endpoint.host == 'connectivitycheck.gstatic.com' ||
          endpoint.host == 'www.google.com') &&
      statusCode == HttpStatus.noContent;

  static Future<bool> _defaultProbe() async {
    // Um cliente por rodada, fechado mesmo em timeout/erro de certificado.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..idleTimeout = const Duration(seconds: 2);
    try {
      for (final endpoint in connectivityEndpoints) {
        try {
          final request = await client.getUrl(endpoint)
              .timeout(const Duration(seconds: 4));
          request.followRedirects = false;
          request.persistentConnection = false;
          request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
          final response = await request.close()
              .timeout(const Duration(seconds: 4));
          final valid = validProbeResponse(endpoint, response.statusCode);
          // Não baixamos conteúdo de páginas de login, erro ou redirecionamento.
          await response.drain<void>()
              .timeout(const Duration(seconds: 2));
          if (valid) return true;
        } catch (_) {
          // HTTPS indisponível; tenta o segundo endereço, sem bloquear mapa local.
        }
      }
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
