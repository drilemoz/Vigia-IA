import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_connectivity_status.dart';
import 'package:vigiaia/services/map_connectivity_service.dart';

void main() {
  test('somente HTTPS 204 em endpoints confiaveis confirma conexao', () {
    final endpoint = Uri.https('connectivitycheck.gstatic.com', '/generate_204');
    expect(MapConnectivityService.validProbeResponse(
      endpoint, HttpStatus.noContent,
    ), isTrue);
    expect(MapConnectivityService.validProbeResponse(
      endpoint, HttpStatus.found,
    ), isFalse);
    expect(MapConnectivityService.validProbeResponse(
      endpoint, HttpStatus.ok,
    ), isFalse);
    expect(MapConnectivityService.validProbeResponse(
      Uri.http('connectivitycheck.gstatic.com', '/generate_204'),
      HttpStatus.noContent,
    ), isFalse);
    expect(MapConnectivityService.validProbeResponse(
      Uri.https('example.com', '/generate_204'),
      HttpStatus.noContent,
    ), isFalse);
  });

  test('primeira falha parte do estado desconhecido para offline', () async {
    final service = MapConnectivityService(probe: () async => false);
    final state = await service.checkNow(force: true);
    expect(state, MapConnectivityState.offline);
  });

  test('uma falha isolada nao derruba uma conexao previamente online', () async {
    var online = true;
    final service = MapConnectivityService(
      probe: () async => online,
      failuresBeforeOffline: 2,
    );
    await service.checkNow(force: true);
    expect(service.state, MapConnectivityState.online);

    online = false;
    await service.checkNow(force: true);
    expect(service.state, MapConnectivityState.online);
    await service.checkNow(force: true);
    expect(service.state, MapConnectivityState.offline);
  });

  test('uma resposta positiva recupera o estado offline', () async {
    var online = false;
    final service = MapConnectivityService(probe: () async => online);
    await service.checkNow(force: true);
    expect(service.state, MapConnectivityState.offline);

    online = true;
    await service.checkNow(force: true);
    expect(service.state, MapConnectivityState.online);
  });
}
