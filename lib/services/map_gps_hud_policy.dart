import '../models/map_route_point.dart';
import 'location_tracking_service.dart';
import 'map_telemetry_policy.dart';

/// Estado do GPS no HUD: separa falha da permissão de leitura simplesmente antiga.
/// Nunca promove uma coordenada histórica a posição atual.
class MapGpsHudPolicy {
  const MapGpsHudPolicy._();

  static String label({
    required LocationTrackingAvailability? availability,
    required MapRoutePoint? point,
    DateTime? now,
  }) {
    switch (availability) {
      case null:
        return 'GPS iniciando';
      case LocationTrackingAvailability.servicesDisabled:
        return 'Localização desligada';
      case LocationTrackingAvailability.permissionDenied:
        return 'Sem permissão GPS';
      case LocationTrackingAvailability.permissionDeniedForever:
        return 'Permissão bloqueada';
      case LocationTrackingAvailability.ready:
        if (point == null) return 'Aguardando posição';
        if (MapTelemetryPolicy.isFresh(point, now: now)) return 'GPS ativo';
        final age = (now ?? DateTime.now()).difference(point.recordedAt);
        if (age.isNegative) return 'Horário GPS inválido';
        if (age.inMinutes < 1) return 'Leitura GPS antiga';
        if (age.inHours < 1) return 'Última posição: ${age.inMinutes} min';
        return 'Última posição: ${age.inHours} h';
    }
  }
}
