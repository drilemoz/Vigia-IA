import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../models/bike_trip_plan.dart';
import '../models/map_destination_search.dart';
import '../models/offline_map_package.dart';
import '../models/offline_poi_package.dart';
import '../models/planned_bike_trip.dart';
import 'route_corridor_index.dart';

/// Resultado de conferência **local** e sob demanda. Limites MBTiles são apenas
/// metadados: nem a presença do arquivo nem o retângulo provam tiles nos zooms.
class TripOfflineReadinessReport {
  const TripOfflineReadinessReport({
    required this.checkedAt,
    required this.availableMaps,
    required this.missingMapFiles,
    required this.mapsWithoutBounds,
    required this.mapsNeedingRefresh,
    required this.routeSamples,
    required this.samplesWithinMapBounds,
    required this.samplesWithUnknownCoverage,
    required this.samplesOutsideAvailableBounds,
    required this.daysOutsideMapBounds,
    required this.offlinePoiPackages,
    required this.offlinePoisNearRoute,
    required this.savedItineraryPlaces,
    required this.stages,
    required this.stagesWithManualChecks,
    required this.intermediateStopsWithoutOvernightCheck,
    required this.warnings,
  });

  final DateTime checkedAt;
  final int availableMaps;
  final int missingMapFiles;
  final int mapsWithoutBounds;
  final int mapsNeedingRefresh;
  final int routeSamples;
  final int samplesWithinMapBounds;
  final int samplesWithUnknownCoverage;
  final int samplesOutsideAvailableBounds;
  final List<int> daysOutsideMapBounds;
  final int offlinePoiPackages;
  final int offlinePoisNearRoute;
  final int savedItineraryPlaces;
  final int stages;
  final int stagesWithManualChecks;
  final int intermediateStopsWithoutOvernightCheck;
  final List<String> warnings;

  /// Nunca usar como autorização automática para sair: não testa tiles reais,
  /// acesso rodoviário, disponibilidade de água ou validade de previsão.
  bool get needsReview => warnings.isNotEmpty;
}

typedef TripOfflineMapProbe = Future<bool> Function(OfflineMapPackage package);

class TripOfflineReadinessService {
  const TripOfflineReadinessService._();

  /// Não solicita GPS, rede, permissões novas ou serviços em segundo plano.
  /// Verifica existência/tamanho dos arquivos locais sem ler a base inteira.
  /// A [mapProbe] opcional permite testar a regra sem I/O em testes Dart.
  static Future<TripOfflineReadinessReport> inspect({
    required PlannedBikeTrip trip,
    required BikeTripPlan plan,
    required List<OfflineMapPackage> offlineMaps,
    required List<OfflinePoiPackage> offlinePoiPackages,
    DateTime? now,
    TripOfflineMapProbe? mapProbe,
  }) async {
    final checkedAt = now ?? DateTime.now();
    final usableMaps = <OfflineMapPackage>[];
    var unavailableFiles = 0;
    var withoutBounds = 0;
    var needRefresh = 0;
    for (final package in offlineMaps) {
      bool exists;
      try {
        exists = await (mapProbe?.call(package) ?? _isLocalNonEmptyFile(package));
      } catch (_) {
        exists = false;
      }
      if (!exists) {
        unavailableFiles++;
        continue;
      }
      usableMaps.add(package);
      if (!_hasValidBounds(package)) {
        withoutBounds++;
      }
      if (package.expiresAt != null &&
          checkedAt.isAfter(package.expiresAt!)) {
        needRefresh++;
      }
    }

    final route = trip.selectedRoute;
    final points = route.points;
    final samples = points.length < 2
        ? <LatLng>[]
        : RouteCorridorIndex.searchSamples(
            points, intervalMeters: 5000, maximumSamples: 121);
    var inside = 0;
    var unknown = 0;
    var outside = 0;
    final daysOutside = <int>{};
    final hasUnknownBounds = usableMaps.any((map) => !_hasValidBounds(map));
    for (var index = 0; index < samples.length; index++) {
      final point = samples[index];
      if (usableMaps.any((map) => _hasValidBounds(map) && map.contains(
            latitude: point.latitude, longitude: point.longitude))) {
        inside++;
      } else if (hasUnknownBounds) {
        unknown++;
      } else {
        outside++;
        if (plan.days.isNotEmpty) {
          // searchSamples distribui posições por distância da geometria;
          // os limites das etapas usam a distância do provedor roteador.
          final progress = route.distanceMeters *
              (samples.length <= 1 ? 0 : index / (samples.length - 1));
          for (final stage in plan.days) {
            if (progress >= stage.startDistanceMeters - 1 &&
                progress <= stage.endDistanceMeters + 1) {
              daysOutside.add(stage.day);
              break;
            }
          }
        }
      }
    }

    // Somente pacotes realmente persistidos no aparelho. Locais guardados
    // dentro da viagem são contabilizados separadamente como itinerário salvo.
    var south = 90.0;
    var north = -90.0;
    var west = 180.0;
    var east = -180.0;
    for (final point in points) {
      if (point.latitude < south) { south = point.latitude; }
      if (point.latitude > north) { north = point.latitude; }
      if (point.longitude < west) { west = point.longitude; }
      if (point.longitude > east) { east = point.longitude; }
    }
    final unique = <String>{};
    final poiCandidates = <MapDestinationSearchResult>[];
    var truncated = false;
    for (final package in offlinePoiPackages) {
      for (final poi in package.items) {
        if (!poi.latitude.isFinite || !poi.longitude.isFinite ||
            poi.latitude.abs() > 90 || poi.longitude.abs() > 180 ||
            poi.latitude < south - 0.04 || poi.latitude > north + 0.04 ||
            poi.longitude < west - 0.04 || poi.longitude > east + 0.04) {
          continue;
        }
        final key = '${poi.category.name}:${poi.latitude.toStringAsFixed(5)}:'
            '${poi.longitude.toStringAsFixed(5)}';
        if (!unique.add(key)) {
          continue;
        }
        if (poiCandidates.length >= 1200) {
          truncated = true;
          break;
        }
        poiCandidates.add(MapDestinationSearchResult(
          id: key,
          title: poi.title,
          subtitle: poi.subtitle,
          latitude: poi.latitude,
          longitude: poi.longitude,
          distanceMeters: 0,
          kind: MapDestinationKind.pointOfInterest,
          source: 'offline',
          poiCategory: poi.category,
        ));
      }
      if (truncated) {
        break;
      }
    }
    final located = points.length < 2
        ? const <RouteCorridorPlace>[]
        : RouteCorridorIndex.locate(
            route: points,
            routeDistanceMeters: route.distanceMeters,
            places: poiCandidates,
            maximumProximityMeters: 2500,
            maximumResults: 300,
          );

    var checkedStages = 0;
    var unconfirmedOvernights = 0;
    for (var index = 0; index < plan.days.length; index++) {
      final stage = plan.days[index];
      final applicable = trip.stopChecks.where((check) => check.matches(
        stage: stage,
        selectedRouteIndex: trip.selectedIndex,
      ));
      final confirmed = applicable.any((check) =>
          check.accessChecked || check.waterChecked || check.overnightChecked);
      if (confirmed) {
        checkedStages++;
      }
      if (index < plan.days.length - 1 &&
          !applicable.any((check) => check.overnightChecked)) {
        unconfirmedOvernights++;
      }
    }

    final warnings = <String>[];
    if (points.length < 2 || !route.distanceMeters.isFinite ||
        route.distanceMeters <= 0) {
      warnings.add('A geometria da rota está incompleta; revise o planejamento salvo.');
    }
    if (usableMaps.isEmpty) {
      warnings.add('Nenhum arquivo MBTiles utilizável foi encontrado no armazenamento local.');
    }
    if (unavailableFiles > 0) {
      warnings.add('$unavailableFiles mapa(s) cadastrado(s) com arquivo ausente, vazio ou inacessível.');
    }
    if (outside > 0) {
      final days = daysOutside.toList()..sort();
      warnings.add('$outside amostra(s) da rota fora dos limites declarados dos mapas disponíveis.'
          '${days.isEmpty ? '' : ' Revisar etapas: ${days.take(12).join(', ')}${days.length > 12 ? '…' : ''}.'}');
    }
    if (unknown > 0) {
      warnings.add('$unknown amostra(s) com cobertura desconhecida: existe MBTiles sem limites geográficos.');
    }
    if (needRefresh > 0) {
      warnings.add('$needRefresh mapa(s) indica(m) necessidade de atualização; conferir validade/licença.');
    }
    if (offlinePoiPackages.isEmpty) {
      warnings.add('Nenhum pacote de pontos de apoio offline cadastrado para consulta regional.');
    } else if (located.isEmpty && trip.places.isEmpty) {
      warnings.add('Não foram identificados apoios próximos da rota nos pontos locais examinados.');
    }
    if (truncated) {
      warnings.add('Muitos pontos locais: análise limitada a 1.200 candidatos; resultado parcial.');
    }
    if (unconfirmedOvernights > 0) {
      warnings.add('$unconfirmedOvernights parada(s) intermediária(s) ainda sem pernoite conferido manualmente.');
    }
    if (checkedStages < plan.days.length) {
      warnings.add('${plan.days.length - checkedStages} etapa(s) sem conferência manual válida de acesso, água ou pernoite.');
    }
    return TripOfflineReadinessReport(
      checkedAt: checkedAt,
      availableMaps: usableMaps.length,
      missingMapFiles: unavailableFiles,
      mapsWithoutBounds: withoutBounds,
      mapsNeedingRefresh: needRefresh,
      routeSamples: samples.length,
      samplesWithinMapBounds: inside,
      samplesWithUnknownCoverage: unknown,
      samplesOutsideAvailableBounds: outside,
      daysOutsideMapBounds: List<int>.unmodifiable(daysOutside.toList()..sort()),
      offlinePoiPackages: offlinePoiPackages.length,
      offlinePoisNearRoute: located.length,
      savedItineraryPlaces: trip.places.length,
      stages: plan.days.length,
      stagesWithManualChecks: checkedStages,
      intermediateStopsWithoutOvernightCheck: unconfirmedOvernights,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  static bool _hasValidBounds(OfflineMapPackage package) {
    final west = package.west;
    final south = package.south;
    final east = package.east;
    final north = package.north;
    if (west == null || south == null || east == null || north == null) {
      return false;
    }
    return west.isFinite && south.isFinite && east.isFinite && north.isFinite &&
        west >= -180 && east <= 180 && south >= -90 && north <= 90 &&
        west <= east && south <= north;
  }

  static Future<bool> _isLocalNonEmptyFile(OfflineMapPackage package) async {
    if (package.path.trim().isEmpty) {
      return false;
    }
    final file = File(package.path);
    final stat = await file.stat();
    return stat.type == FileSystemEntityType.file && stat.size > 0;
  }
}
