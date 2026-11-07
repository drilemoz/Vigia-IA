import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/bike_trip_plan.dart';
import '../models/offline_map_package.dart';
import '../models/route_explorer_models.dart';
import '../models/map_cycling_route.dart';
import '../models/map_destination_search.dart';
import '../models/map_route_point.dart';
import '../models/map_navigation_target.dart';
import '../models/map_travel_mode.dart';
import '../models/planned_bike_trip.dart';
import '../models/trip_weather_day_forecast.dart';
import '../models/trip_stop_check.dart';
import '../services/bike_trip_planner.dart';
import '../services/bike_trip_editor_bridge.dart';
import '../services/bike_trip_schedule.dart';
import '../services/trip_terrain_service.dart';
import '../services/trip_offline_readiness_service.dart';
import '../services/trip_effort_reserve_service.dart';
import '../services/trip_weather_forecast_service.dart';
import '../services/bike_trip_schedule_settings_service.dart';
import '../services/location_tracking_service.dart';
import '../services/native_platform_service.dart';
import '../services/planned_trip_export_service.dart';
import '../services/map_cycling_route_service.dart';
import '../services/map_destination_search_service.dart';
import '../services/map_view_settings_service.dart';
import '../services/offline_map_service.dart';
import '../services/planned_bike_trip_service.dart';
import '../services/route_explorer_service.dart';
import '../services/route_corridor_index.dart';
import '../services/retained_mbtiles_tile_provider.dart';
import '../services/saved_bike_route_service.dart';
import '../widgets/main_navigation_bar.dart';
import '../widgets/main_navigation_routes.dart';
import 'map_workspace_shell.dart';

/// Planejamento voluntário: não inicia localização, vídeo, IA ou serviço em
/// primeiro plano. Busca remota somente ao enviar pesquisa/cálculo/apoios.
class TripPlanningScreen extends StatefulWidget {
  const TripPlanningScreen({
    super.key,
    this.initialTrip,
    this.returnToMap = false,
  });

  /// Abre o mesmo editor com a geometria já calculada no mapa, sem rede.
  final PlannedBikeTrip? initialTrip;
  /// Em Mapas, devolve a seleção editada em vez de abrir uma segunda tela de mapa.
  final bool returnToMap;

  @override
  State<TripPlanningScreen> createState() => _TripPlanningScreenState();
}

class _TripPlanningScreenState extends State<TripPlanningScreen> {
  final _previewKey = GlobalKey();
  final _originField = TextEditingController();
  final _destinationField = TextEditingController();
  final _citySearch = MapDestinationSearchService.instance;
  final _offlineMaps = OfflineMapService.instance;
  final _savedPois = RouteExplorerService.instance;
  RetainedMbTilesTileProvider? _previewOfflineTileProvider;
  String? _previewOfflineMapId;
  int _previewMinZoom = 0;
  int _previewMaxZoom = 19;
  MapCyclingRoute? _cachedPoiRoute;
  String? _cachedPoiPackageSignature;
  List<RouteExplorerResult> _cachedPoiMarkers = const [];
  PlannedBikeTrip? _cachedTripForPlaces;
  List<RouteCorridorPlace> _cachedTripMatches = const [];
  final _routeProvider = MapCyclingRouteService();
  final _library = const PlannedBikeTripService();
  final _scheduleSettings = BikeTripScheduleSettingsService.instance;
  final _lastMapPreview = const SavedBikeRouteService();
  final _planner = const BikeTripPlanner();
  final _planCache = Expando<BikeTripPlan>('trip-stage-plan');

  MapDestinationSearchResult? _origin;
  MapDestinationSearchResult? _destination;
  PlannedBikeTrip? _draft;
  List<PlannedBikeTrip> _saved = const <PlannedBikeTrip>[];
  bool _lookingForOrigin = true;
  bool _locating = false;
  StateSetter? _wizardRefresh;
  bool _busy = false;
  bool _loadingLibrary = true;
  bool _libraryReadFailed = false;
  bool _fetchingPlaces = false;
  bool _fetchingWeather = false;
  bool _checkingOfflineReadiness = false;
  PlannedBikeTrip? _lastReadinessTrip;
  TripOfflineReadinessReport? _lastReadinessReport;
  bool _showOnlineBaseMap = false;
  String? _message;
  double _speedKmh = 15;
  double _hoursPerDay = 5;
  bool _balanceDays = true;
  bool _smartStages = true;
  bool _forceLunch = false;
  int _breakEveryKm = 20;
  int _breakMinutes = 10;
  int _lunchMinutes = 40;
  TimeOfDay _departure = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _citySearch.addListener(_searchChanged);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await Future.wait(<Future<void>>[
        _citySearch.initialize(),
        _offlineMaps.initialize(),
        _savedPois.initialize(),
        MapViewSettingsService.instance.initialize(),
        _scheduleSettings.initialize(),
      ]);
      var trips = await _library.load();
      // Migração conservadora da última rota Bike das versões antigas.
      // Não apaga o arquivo de compatibilidade nem duplica a mesma importação.
      final legacy = await _lastMapPreview.load();
      if (legacy != null && legacy.target.travelMode == MapTravelMode.bicycle &&
          legacy.routes.isNotEmpty) {
        final route = legacy.routes[legacy.selectedIndex];
        final start = route.points.first;
        final legacyId = 'legacy-map-${start.latitude.toStringAsFixed(5)}-'
            '${start.longitude.toStringAsFixed(5)}-'
            '${legacy.target.latitude.toStringAsFixed(5)}-'
            '${legacy.target.longitude.toStringAsFixed(5)}-'
            '${route.distanceMeters.round()}';
        final exists = trips.any((item) => item.id == legacyId ||
            (item.destination.latitude - legacy.target.latitude).abs() < 0.00001 &&
            (item.destination.longitude - legacy.target.longitude).abs() < 0.00001 &&
            (item.selectedRoute.distanceMeters - route.distanceMeters).abs() < 1);
        if (!exists) {
          final prefs = MapViewSettingsService.instance.bikeTravelPreferences;
          final schedule = _scheduleSettings.value;
          final imported = BikeTripEditorBridge.fromMapRoute(
            saved: legacy,
            preferences: prefs,
            departureMinute: schedule.departureMinute,
            breakEveryKm: schedule.breakEveryKm,
            breakMinutes: schedule.breakMinutes,
            lunchMinutes: schedule.lunchMinutes,
            forceLunch: schedule.forceLunch,
            id: legacyId,
          );
          await _library.upsert(imported);
          trips = await _library.load();
        }
      }
      if (!mounted) return;
      final preferences = MapViewSettingsService.instance.bikeTravelPreferences;
      final schedule = _scheduleSettings.value;
      final initial = widget.initialTrip;
      _selectPreviewMapForRoute(initial?.selectedRoute);
      setState(() {
        _saved = trips;
        _speedKmh = initial?.averageSpeedKmh ?? preferences.averageSpeedKmh;
        _hoursPerDay = initial?.ridingHoursPerDay ?? preferences.ridingHoursPerDay;
        _balanceDays = initial?.balanceDays ?? preferences.balanceDays;
        _smartStages = initial?.smartStages ?? true;
        _departure = TimeOfDay(
          hour: (initial?.departureMinute ?? schedule.departureMinute) ~/ 60,
          minute: (initial?.departureMinute ?? schedule.departureMinute) % 60,
        );
        _breakEveryKm = initial?.breakEveryKm ?? schedule.breakEveryKm;
        _breakMinutes = initial?.breakMinutes ?? schedule.breakMinutes;
        _lunchMinutes = initial?.lunchMinutes ?? schedule.lunchMinutes;
        _forceLunch = initial?.forceLunch ?? schedule.forceLunch;
        if (initial != null) {
          _draft = initial;
          _origin = initial.origin;
          _destination = initial.destination;
          _originField.text = initial.origin.title;
          _destinationField.text = initial.destination.title;
        }
        _loadingLibrary = false;
      });
      if (initial != null && initial.places.isEmpty) {
        unawaited(_fillLocalPlaces(initial));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingLibrary = false;
        _libraryReadFailed = true;
        _message = 'Não foi possível ler a biblioteca local. Seus arquivos não foram apagados.';
      });
    }
  }

  void _searchChanged() {
    if (!mounted) return;
    setState(() {});
    _refreshWizard();
  }

  void _refreshWizard() {
    final refresh = _wizardRefresh;
    if (mounted && refresh != null) refresh(() {});
  }

  @override
  void dispose() {
    _citySearch.removeListener(_searchChanged);
    _previewOfflineTileProvider?.release();
    _originField.dispose();
    _destinationField.dispose();
    super.dispose();
  }

  MapRoutePoint get _reference => MapRoutePoint(
    latitude: _origin?.latitude ?? _destination?.latitude ?? 0,
    longitude: _origin?.longitude ?? _destination?.longitude ?? 0,
    recordedAt: DateTime.now(),
    accuracyMeters: 0,
    speedMetersPerSecond: 0,
  );

  void _typing(String value, {required bool origin}) {
    setState(() {
      _lookingForOrigin = origin;
      if (origin) {
        _origin = null;
      } else {
        _destination = null;
      }
      _draft = null;
      _message = null;
    });
    _refreshWizard();
    _citySearch.updateLocalQuery(
      query: value,
      current: _reference,
      offlineMaps: _offlineMaps.packages,
      offlinePoiPackages: const [],
      onlyDownloaded: true,
    );
  }

  Future<void> _searchCity({required bool origin}) async {
    if (_busy) return;
    final text = (origin ? _originField : _destinationField).text.trim();
    if (text.length < 2) {
      _notify('Digite pelo menos duas letras da cidade.');
      return;
    }
    setState(() => _lookingForOrigin = origin);
    _refreshWizard();
    await _citySearch.searchSubmitted(
      query: text,
      current: _reference,
      onlineAllowed: true,
      // Origem ainda não selecionada: busca global sem preferência em (0,0).
      preferRegion: _origin != null,
      offlineMaps: _offlineMaps.packages,
      offlinePoiPackages: const [],
    );
  }

  void _selectCity(MapDestinationSearchResult place) {
    // Não selecionar POI inadvertidamente como cidade de origem/destino.
    setState(() {
      if (_lookingForOrigin) {
        _origin = place;
        _originField.text = place.title;
      } else {
        _destination = place;
        _destinationField.text = place.title;
      }
      _draft = null;
      _message = null;
    });
    _refreshWizard();
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(_citySearch.rememberRecentPlace(place));
    _citySearch.updateLocalQuery(
      query: '', current: _reference,
      offlineMaps: _offlineMaps.packages,
      offlinePoiPackages: const [], onlyDownloaded: true,
    );
  }

  void _activateCityField({required bool origin}) {
    setState(() => _lookingForOrigin = origin);
    _citySearch.updateLocalQuery(
      query: (origin ? _originField : _destinationField).text,
      current: _reference,
      offlineMaps: _offlineMaps.packages,
      offlinePoiPackages: const [],
      onlyDownloaded: true,
    );
    _refreshWizard();
  }

  /// GPS só é ligado nesta ação explícita. Sem escuta contínua nem geocoding.
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() { _locating = true; _message = null; });
    _refreshWizard();
    try {
      final service = LocationTrackingService.instance;
      final availability = await service.ensureAvailable(requestPermission: true);
      if (availability != LocationTrackingAvailability.ready) {
        final detail = switch (availability) {
          LocationTrackingAvailability.servicesDisabled =>
            'Ative a localização do Android e tente novamente.',
          LocationTrackingAvailability.permissionDeniedForever =>
            'Autorize a localização para o Vigia IA nas configurações do Android.',
          _ => 'Permissão de localização não concedida. Use uma cidade manualmente.',
        };
        if (mounted) setState(() => _message = detail);
        return;
      }
      final position = await service.currentPosition().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final location = MapDestinationSearchResult(
        id: 'gps:${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}',
        title: 'Meu local',
        subtitle: 'GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
        latitude: position.latitude,
        longitude: position.longitude,
        distanceMeters: 0,
        kind: MapDestinationKind.place,
        source: 'gps',
      );
      setState(() {
        _origin = location;
        _originField.text = 'Meu local (GPS)';
        _lookingForOrigin = true;
        _draft = null;
        _message = null;
      });
      _citySearch.updateLocalQuery(
        query: '', current: _reference, offlineMaps: _offlineMaps.packages,
        offlinePoiPackages: const [], onlyDownloaded: true,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Não foi possível obter uma posição GPS atual. Confira sinal e permissão.');
      }
    } finally {
      if (mounted) {
        setState(() => _locating = false);
        _refreshWizard();
      }
    }
  }

  Future<void> _persistDefaults() async {
    try {
      await MapViewSettingsService.instance.setBikeTravelPreferences(
        BikeTravelPreferences(
          averageSpeedKmh: _speedKmh,
          ridingHoursPerDay: _hoursPerDay,
          balanceDays: _balanceDays,
        ),
      );
      await _scheduleSettings.save(BikeTripScheduleSettings(
        departureMinute: _departure.hour * 60 + _departure.minute,
        breakEveryKm: _breakEveryKm,
        breakMinutes: _breakMinutes,
        lunchMinutes: _lunchMinutes,
        forceLunch: _forceLunch,
      ));
    } catch (_) {
      _notify('Não foi possível salvar as preferências do planejamento.');
    }
  }

  Future<void> _newRouteWizard() async {
    if (_busy || _loadingLibrary) return;
    _originField.clear();
    _destinationField.clear();
    setState(() {
      _origin = null;
      _destination = null;
      _draft = null;
      _message = null;
      _lookingForOrigin = true;
    });
    _citySearch.updateLocalQuery(
      query: '', current: _reference, offlineMaps: _offlineMaps.packages,
      offlinePoiPackages: const [], onlyDownloaded: true,
    );
    var step = 0;
    var shouldCalculate = false;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (ctx, dialogSetState) {
            _wizardRefresh = dialogSetState;
            final validCities = _origin != null && _destination != null &&
                (_origin!.latitude - _destination!.latitude).abs() +
                (_origin!.longitude - _destination!.longitude).abs() > 0.000002;
            final keyboardInset = MediaQuery.viewInsetsOf(ctx).bottom;
            final maxHeight = MediaQuery.sizeOf(ctx).height -
                keyboardInset - MediaQuery.paddingOf(ctx).vertical - 32;
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 510, maxHeight: maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(step == 0 ? Icons.route_rounded : Icons.directions_bike_rounded,
                      color: Theme.of(ctx).colorScheme.primary, size: 29),
                    const SizedBox(height: 8),
                    Text(step == 0 ? 'Nova rota · 1 de 2' : 'Ritmo da pedalada · 2 de 2',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Flexible(child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                      children: step == 0 ? <Widget>[
                        Text('Digite o destino e toque em Buscar (ou na lupa). Selecione um resultado para continuar. Locais salvos funcionam offline.',
                          style: Theme.of(ctx).textTheme.bodySmall),
                        const SizedBox(height: 14),
                        _cityField(origin: true),
                        const SizedBox(height: 6),
                        OutlinedButton.icon(
                          onPressed: _locating ? null : () => unawaited(_useCurrentLocation()),
                          icon: Icon(_locating ? Icons.hourglass_top : Icons.my_location_rounded),
                          label: Text(_locating ? 'Localizando…' : 'Usar meu local como origem'),
                        ),
                        const SizedBox(height: 12),
                        _cityField(origin: false),
                        const SizedBox(height: 8),
                        _searchResults(),
                        if (_message != null) Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(_message!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                        ),
                      ] : <Widget>[
                        Text('${_origin!.title} → ${_destination!.title}',
                            textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.titleSmall),
                        const SizedBox(height: 10),
                        _settings(),
                        const SizedBox(height: 6),
                        Text('Os tempos são estimativas, não incluem relevo e vento.',
                            style: Theme.of(ctx).textTheme.bodySmall),
                      ],
                      ),
                    )),
                    const SizedBox(height: 10),
                    OverflowBar(alignment: MainAxisAlignment.end,
                      spacing: 8, overflowSpacing: 6, children: [
                      TextButton(onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar')),
                      if (step == 1)
                        OutlinedButton(onPressed: () => dialogSetState(() => step = 0),
                          child: const Text('Voltar')),
                      FilledButton.icon(
                        onPressed: step == 0
                            ? (validCities && !_locating
                                ? () { FocusManager.instance.primaryFocus?.unfocus();
                                    dialogSetState(() => step = 1); }
                                : null)
                            : () { shouldCalculate = true; Navigator.pop(ctx); },
                        icon: Icon(step == 0 ? Icons.arrow_forward_rounded : Icons.route_rounded),
                        label: Text(step == 0 ? 'Avançar' : 'Ver trajeto'),
                      ),
                    ]),
                  ]),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      _wizardRefresh = null;
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (shouldCalculate && mounted) {
      await _persistDefaults();
      if (mounted) await _calculate();
    }
  }

  Future<void> _exportTrip(PlannedBikeTrip trip, String format) async {
    try {
      final isGpx = format == 'gpx';
      final content = isGpx
          ? PlannedTripExportService.toGpx(trip)
          : PlannedTripExportService.toJson(trip);
      final name = 'vigiaia_viagem_${DateTime.now().millisecondsSinceEpoch}.$format';
      final saved = await NativePlatformService.instance.saveBytesWithPicker(
        fileName: name,
        mimeType: isGpx ? 'application/gpx+xml' : 'application/json',
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      if (!mounted) return;
      if (saved != null && saved.isNotEmpty) {
        _notify('Arquivo .$format exportado com sucesso.');
      } else {
        _notify('Exportação cancelada ou não concluída.');
      }
    } catch (_) {
      _notify('Não foi possível exportar esta rota.');
    }
  }

  Future<void> _discardOrDeleteCurrent(PlannedBikeTrip trip) async {
    final alreadySaved = _saved.any((saved) => saved.id == trip.id);
    if (alreadySaved) {
      await _delete(trip);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar rota?'),
        content: const Text('Esta rota ainda não foi salva. Descartar o resultado atual?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Descartar')),
        ],
      ),
    );
    if (discard == true && mounted) setState(() => _draft = null);
  }

  Widget _routeActions(PlannedBikeTrip trip) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Expanded(child: FilledButton.icon(
        onPressed: _libraryReadFailed ? null : () => unawaited(_save()),
        icon: const Icon(Icons.save_outlined, size: 19),
        label: const Text('Salvar'),
      )),
      const SizedBox(width: 6),
      Expanded(child: OutlinedButton.icon(
        onPressed: _libraryReadFailed && _saved.any((t) => t.id == trip.id)
            ? null : () => unawaited(_discardOrDeleteCurrent(trip)),
        icon: const Icon(Icons.delete_outline_rounded, size: 19),
        label: const Text('Apagar'),
      )),
      const SizedBox(width: 6),
      Expanded(child: PopupMenuButton<String>(
        tooltip: 'Exportar planejamento',
        onSelected: (format) => unawaited(_exportTrip(trip, format)),
        itemBuilder: (ctx) => const [
          PopupMenuItem(value: 'gpx', child: Text('Exportar trajeto GPX')),
          PopupMenuItem(value: 'json', child: Text('Exportar planejamento JSON')),
        ],
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.ios_share_rounded, size: 19),
              SizedBox(width: 4),
              Flexible(child: Text('Exportar', maxLines: 1)),
            ]),
          ),
        ),
      )),
    ]),
  );

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _calculate() async {
    final origin = _origin;
    final destination = _destination;
    if (_busy || origin == null || destination == null) {
      _notify('Selecione origem e destino da lista de cidades.');
      return;
    }
    if ((origin.latitude - destination.latitude).abs() < 0.000001 &&
        (origin.longitude - destination.longitude).abs() < 0.000001) {
      _notify('Origem e destino precisam ser diferentes.');
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      final routes = await _routeProvider.fetchAlternatives(
        origin: LatLng(origin.latitude, origin.longitude),
        destination: LatLng(destination.latitude, destination.longitude),
        alternativeCount: 2,
      );
      if (!mounted) return;
      final trip = PlannedBikeTrip(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        savedAt: DateTime.now(),
        origin: origin, destination: destination,
        routes: routes, selectedIndex: 0,
        averageSpeedKmh: _speedKmh,
        ridingHoursPerDay: _hoursPerDay,
        departureMinute: _departure.hour * 60 + _departure.minute,
        breakEveryKm: _breakEveryKm,
        breakMinutes: _breakMinutes,
        lunchMinutes: _lunchMinutes,
        balanceDays: _balanceDays,
        smartStages: _smartStages,
        forceLunch: _forceLunch,
      );
      // A primeira lista de cidades e apoios é inteiramente local. Não liga
      // GPS nem executa Overpass em segundo plano.
      List<MapDestinationSearchResult> localPlaces = const [];
      try {
        localPlaces = await _citySearch.placesAlongRoute(
          route: trip.selectedRoute.points,
          current: _reference,
          onlineAllowed: false,
          offlineMaps: _offlineMaps.packages,
          offlinePoiPackages: _savedPois.offlinePackages,
        );
      } catch (_) {
        // O trajeto continua utilizável, mesmo com índice local corrompido.
      }
      if (!mounted) return;
      _selectPreviewMapForRoute(trip.selectedRoute);
      setState(() => _draft = trip.copyWith(places: localPlaces));
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Rota não calculada. Confira a internet e os nomes das cidades. Nenhuma distância foi inventada.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  BikeTripPlan _plan(PlannedBikeTrip trip) {
    final cached = _planCache[trip];
    if (cached != null) {
      return cached;
    }
    final plan = _planner.buildPlan(
    routePoints: trip.selectedRoute.points,
    routeDistanceMeters: trip.selectedRoute.distanceMeters,
    preferences: BikeTravelPreferences(
      averageSpeedKmh: trip.averageSpeedKmh,
      ridingHoursPerDay: trip.ridingHoursPerDay,
      balanceDays: trip.balanceDays,
    ),
    destinationLabel: trip.destination.title,
    candidates: trip.places,
    elevationsMeters: trip.selectedRoute.elevationsMeters,
    climbReserveMinutesPer100m: trip.climbReserveMinutesPer100m,
    smartStages: trip.smartStages,
    );
    _planCache[trip] = plan;
    return plan;
  }

  void _refreshDraftPreferences() {
    final draft = _draft;
    if (draft != null) {
      setState(() => _draft = draft.copyWith(
        averageSpeedKmh: _speedKmh,
        ridingHoursPerDay: _hoursPerDay,
        departureMinute: _departure.hour * 60 + _departure.minute,
        breakEveryKm: _breakEveryKm,
        breakMinutes: _breakMinutes,
        lunchMinutes: _lunchMinutes,
        balanceDays: _balanceDays,
        smartStages: _smartStages,
        forceLunch: _forceLunch,
        weatherDays: const <TripWeatherDayForecast>[],
      ));
    }
    _refreshWizard();
  }

  Future<void> _findStops({required bool online}) async {
    final draft = _draft;
    if (draft == null || _fetchingPlaces) return;
    setState(() => _fetchingPlaces = true);
    try {
      await RouteExplorerService.instance.initialize();
      final places = await _citySearch.placesAlongRoute(
        route: draft.selectedRoute.points,
        current: _reference,
        onlineAllowed: online,
        offlineMaps: _offlineMaps.packages,
        offlinePoiPackages: RouteExplorerService.instance.offlinePackages,
      );
      if (!mounted || _draft?.id != draft.id) return;
      setState(() => _draft = draft.copyWith(places: places,
          weatherDays: const <TripWeatherDayForecast>[]));
      _notify(places.isEmpty
          ? 'Nenhum apoio confirmado. Os pernoites permanecem aproximados.'
          : '${places.length} local(is) identificado(s); confira os desvios e serviços.');
    } catch (_) {
      _notify('Não foi possível buscar apoios. A rota permanece disponível.');
    } finally {
      if (mounted) setState(() => _fetchingPlaces = false);
    }
  }

  Future<void> _selectStartDate() async {
    final trip = _draft;
    if (trip == null || _fetchingWeather) {
      return;
    }
    final now = DateTime.now();
    final firstDate = DateTime(2020);
    final lastDate = DateTime(now.year + 2);
    final savedDate = trip.startDate ?? now;
    final initialDate = savedDate.isBefore(firstDate) ? firstDate :
        savedDate.isAfter(lastDate) ? lastDate : savedDate;
    final chosen = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Data prevista de partida',
    );
    if (!mounted || chosen == null || _draft?.id != trip.id) {
      return;
    }
    setState(() => _draft = trip.copyWith(startDate: chosen,
        weatherDays: const <TripWeatherDayForecast>[]));
  }

  Future<void> _checkTripWeather() async {
    final trip = _draft;
    final chosenDate = trip?.startDate;
    if (trip == null || chosenDate == null || _fetchingWeather) {
      return;
    }
    setState(() => _fetchingWeather = true);
    try {
      final result = await const TripWeatherForecastService().fetch(
        route: trip.selectedRoute,
        days: _plan(trip).days,
        startDate: chosenDate,
        departureMinute: trip.departureMinute,
        breakEveryKm: trip.breakEveryKm,
        breakMinutes: trip.breakMinutes,
        lunchMinutes: trip.lunchMinutes,
        forceLunch: trip.forceLunch,
        climbReserveMinutesPer100m: trip.climbReserveMinutesPer100m,
      );
      if (!mounted || _draft?.id != trip.id ||
          _draft?.startDate != trip.startDate ||
          _draft?.selectedIndex != trip.selectedIndex ||
          _draft?.averageSpeedKmh != trip.averageSpeedKmh ||
          _draft?.ridingHoursPerDay != trip.ridingHoursPerDay ||
          _draft?.departureMinute != trip.departureMinute ||
          _draft?.breakEveryKm != trip.breakEveryKm ||
          _draft?.breakMinutes != trip.breakMinutes ||
          _draft?.lunchMinutes != trip.lunchMinutes ||
          _draft?.forceLunch != trip.forceLunch ||
          _draft?.balanceDays != trip.balanceDays ||
          _draft?.smartStages != trip.smartStages ||
          !identical(_draft?.places, trip.places) ||
          _draft?.climbReserveMinutesPer100m != trip.climbReserveMinutesPer100m) {
        return;
      }
      final merged = <int, TripWeatherDayForecast>{
        for (final old in trip.weatherDays) old.day: old,
        for (final forecast in result.forecasts) forecast.day: forecast,
      };
      setState(() => _draft = trip.copyWith(weatherDays: merged.values.toList()));
      _notify(result.forecasts.isEmpty
          ? 'Sem previsão disponível para estas datas. Verifique conexão e horizonte de 16 dias.'
          : '${result.forecasts.length} etapa(s) com previsão obtida; '
              '${result.errors} consulta(s) falharam. Salve a viagem para manter os dados offline.');
    } catch (_) {
      _notify('Falha ao consultar o clima. As previsões salvas foram preservadas.');
    } finally {
      if (mounted) setState(() => _fetchingWeather = false);
    }
  }

  String _formatTripDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Widget _weatherDayLine(int dayNumber, PlannedBikeTrip trip) {
    TripWeatherDayForecast? forecast;
    for (final value in trip.weatherDays) {
      if (value.day == dayNumber) {
        forecast = value;
        break;
      }
    }
    if (forecast == null) {
      return const Text('Clima: sem previsão para esta etapa.',
          style: TextStyle(fontSize: 12));
    }
    final hour = forecast.estimatedAt.toLocal();
    final checked = forecast.updatedAt.toLocal();
    final currentTime = DateTime.now();
    final stale = currentTime.difference(forecast.updatedAt) >
        const Duration(hours: 6) ||
        forecast.estimatedAt.isBefore(currentTime.subtract(const Duration(hours: 1)));
    String display(double? value, String unit, {int digits = 0}) => value == null
        ? 'indisponível' : '${value.toStringAsFixed(digits)}$unit';
    final risky = (forecast.rainProbabilityPercent ?? 0) >= 60 ||
        (forecast.precipitationMm ?? 0) >= 5 ||
        (forecast.windGustKmh ?? 0) >= 40 ||
        (forecast.weatherCode ?? 0) >= 95;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Clima previsto ~${_formatTripDate(hour)} '
          '${BikeTripDaySchedule.formatMinute(hour.hour * 60 + hour.minute)}'
          '${stale ? ' · dados antigos' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      Text('Chuva: ${display(forecast.rainProbabilityPercent, '%')} · '
          'precipitação na hora: ${display(forecast.precipitationMm, ' mm', digits: 1)} · '
          'vento: ${display(forecast.windSpeedKmh, ' km/h')} · '
          'rajadas: ${display(forecast.windGustKmh, ' km/h')} · '
          'temperatura: ${display(forecast.temperatureC, ' °C')}'),
      if (risky)
        const Text('Atenção: chuva, vento ou trovoada potencialmente adversos. '
            'Não substitui avisos oficiais.', style: TextStyle(fontSize: 12)),
      Text('Open-Meteo.com · consultado em ${_formatTripDate(checked)} '
          '${BikeTripDaySchedule.formatMinute(checked.hour * 60 + checked.minute)}. '
          'Previsão pontual, não cobre toda a etapa.',
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Future<void> _save() async {
    if (_libraryReadFailed) {
      _notify('Biblioteca indisponível. Não vou sobrescrever viagens antigas.');
      return;
    }
    final draft = _draft;
    if (draft == null) return;
    try {
      await _library.upsert(draft);
      final latest = await _library.load();
      if (!mounted) return;
      setState(() => _saved = latest);
      _notify('Viagem salva, incluindo o traçado para consulta offline.');
    } catch (_) {
      _notify('Não foi possível salvar; viagens anteriores não foram apagadas.');
    }
  }

  Future<void> _delete(PlannedBikeTrip trip) async {
    if (_libraryReadFailed) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir planejamento?'),
        content: Text('Excluir ${trip.origin.title} → ${trip.destination.title} apenas da biblioteca?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final updated = _saved.where((item) => item.id != trip.id).toList();
      await _library.saveAll(updated);
      if (mounted) {
        setState(() {
          _saved = updated;
          if (_draft?.id == trip.id) {
            _draft = null;
          }
        });
      }
    } catch (_) {
      _notify('Não foi possível excluir a viagem.');
    }
  }

  Future<void> _fillLocalPlaces(PlannedBikeTrip trip) async {
    if (trip.places.isNotEmpty) return;
    try {
      final places = await _citySearch.placesAlongRoute(
        route: trip.selectedRoute.points,
        current: _reference,
        onlineAllowed: false,
        offlineMaps: _offlineMaps.packages,
        offlinePoiPackages: _savedPois.offlinePackages,
      );
      if (!mounted || places.isEmpty || _draft?.id != trip.id ||
          _draft?.selectedIndex != trip.selectedIndex ||
          _draft!.places.isNotEmpty) {
        return;
      }
      setState(() => _draft = trip.copyWith(places: places,
          weatherDays: const <TripWeatherDayForecast>[]));
    } catch (_) {
      // Não altera viagens salvas quando o índice de localidades falha.
    }
  }

  void _loadTrip(PlannedBikeTrip trip) {
    _selectPreviewMapForRoute(trip.selectedRoute);
    setState(() {
      _draft = trip;
      _origin = trip.origin;
      _destination = trip.destination;
      _originField.text = trip.origin.title;
      _destinationField.text = trip.destination.title;
      _speedKmh = trip.averageSpeedKmh;
      _hoursPerDay = trip.ridingHoursPerDay;
      _balanceDays = trip.balanceDays;
      _smartStages = trip.smartStages;
      _forceLunch = trip.forceLunch;
      _departure = TimeOfDay(hour: trip.departureMinute ~/ 60,
          minute: trip.departureMinute % 60);
      _breakEveryKm = trip.breakEveryKm;
      _breakMinutes = trip.breakMinutes;
      _lunchMinutes = trip.lunchMinutes;
      _message = null;
    });
    if (trip.places.isEmpty) unawaited(_fillLocalPlaces(trip));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final previewContext = _previewKey.currentContext;
      if (mounted && previewContext != null) {
        Scrollable.ensureVisible(previewContext,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _openMap(PlannedBikeTrip trip, {LatLng? focusPoint}) async {
    try {
      // Mesmo contrato de Rota salva já utilizado pela navegação. Não
      // substitui outras viagens da biblioteca, apenas a prévia única do mapa.
      await _lastMapPreview.save(SavedBikeRoute(
        target: MapNavigationTarget(
          latitude: trip.destination.latitude, longitude: trip.destination.longitude,
          label: trip.destination.title, startedAt: DateTime.now(),
          travelMode: MapTravelMode.bicycle,
        ),
        routes: trip.routes, selectedIndex: trip.selectedIndex,
      ));
      if (!mounted) return;
      if (widget.returnToMap) {
        Navigator.of(context).pop<BikeTripEditorResult>(
          BikeTripEditorResult(trip: trip, focusPoint: focusPoint));
        return;
      }
      _notify('Prévia preparada. No mapa, abra “Rota salva” para visualizar.');
      await Navigator.push<void>(context,
        MaterialPageRoute<void>(builder: (_) => MapWorkspaceShell(
          initialFocusPoint: focusPoint,
          initialSavedRoute: SavedBikeRoute(
            target: MapNavigationTarget(
              latitude: trip.destination.latitude,
              longitude: trip.destination.longitude,
              label: trip.destination.title,
              startedAt: DateTime.now(),
              travelMode: MapTravelMode.bicycle,
            ),
            routes: trip.routes,
            selectedIndex: trip.selectedIndex,
          ),
        )));
    } catch (_) {
      _notify('Não foi possível preparar a prévia no mapa.');
    }
  }

  Widget _cityField({required bool origin}) {
    final selected = origin ? _origin : _destination;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(origin ? 'Origem' : 'Destino', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      TextField(
        controller: origin ? _originField : _destinationField,
        decoration: InputDecoration(
          prefixIcon: Icon(origin ? Icons.trip_origin_rounded : Icons.flag_outlined),
          labelText: origin ? 'Cidade de partida' : 'Cidade de chegada',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: 'Buscar cidade online',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => unawaited(_searchCity(origin: origin)),
          ),
        ),
        textInputAction: TextInputAction.search,
        autocorrect: false,
        onTap: () => _activateCityField(origin: origin),
        onChanged: (text) => _typing(text, origin: origin),
        onSubmitted: (_) => unawaited(_searchCity(origin: origin)),
      ),
      if (selected != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Selecionada: ${selected.title}',
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
        ),
    ]);
  }

  Widget _searchResults() {
    final results = _citySearch.results.where((item) =>
      item.kind != MapDestinationKind.pointOfInterest).take(8).toList();
    final activeText = (_lookingForOrigin ? _originField : _destinationField).text.trim();
    final selected = _lookingForOrigin ? _origin : _destination;
    if (activeText.isEmpty ||
        (selected != null && selected.title == activeText)) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton.icon(
        onPressed: _citySearch.searchLoading ? null :
            () => unawaited(_searchCity(origin: _lookingForOrigin)),
        icon: _citySearch.searchLoading
            ? const SizedBox(width: 17, height: 17,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.search_rounded, size: 19),
        label: Text(_citySearch.searchLoading
            ? 'Buscando "$activeText"…' : 'Buscar "$activeText" online',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      if (_citySearch.searchStatusMessage != null)
        Padding(padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(_citySearch.searchStatusMessage!,
            style: Theme.of(context).textTheme.bodySmall)),
      if (results.isNotEmpty) ...[
        Text('Selecione um resultado para habilitar Avançar',
            style: Theme.of(context).textTheme.labelSmall),
        for (final place in results)
          ListTile(
            dense: true,
            leading: Icon(Icons.location_city_rounded, color: Theme.of(context).colorScheme.primary),
            title: Text(place.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(place.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: place.storedLocally ? const Icon(Icons.offline_pin_outlined, size: 18) : null,
            onTap: () => _selectCity(place),
          ),
      ],
    ]);
  }

  Widget _settings() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ritmo da viagem', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text('Velocidade média: ${_speedKmh.toStringAsFixed(0)} km/h'),
      Slider(value: _speedKmh, min: 5, max: 40, divisions: 35,
          label: '${_speedKmh.toStringAsFixed(0)} km/h',
          onChanged: (v) { setState(() => _speedKmh = v); _refreshDraftPreferences(); },
          onChangeEnd: (_) => unawaited(_persistDefaults())),
      Text('Pedal por dia: ${_hoursPerDay.toStringAsFixed(0)} h'),
      Slider(value: _hoursPerDay, min: 1, max: 12, divisions: 11,
          label: '${_hoursPerDay.toStringAsFixed(0)} h',
          onChanged: (v) { setState(() => _hoursPerDay = v); _refreshDraftPreferences(); },
          onChangeEnd: (_) => unawaited(_persistDefaults())),
      SwitchListTile.adaptive(
        dense: true, contentPadding: EdgeInsets.zero,
        title: const Text('Equilibrar os dias'),
        subtitle: const Text('Equilibra o tempo estimado ou, no modo tradicional, a distância por dia'),
        value: _balanceDays,
        onChanged: (value) {
          setState(() => _balanceDays = value);
          _refreshDraftPreferences();
          unawaited(_persistDefaults());
        },
      ),
      SwitchListTile.adaptive(
        dense: true, contentPadding: EdgeInsets.zero,
        title: const Text('Divisão inteligente dos dias'),
        subtitle: const Text('Considera a reserva para subidas documentadas e prioriza paradas próximas da rota. Funciona offline.'),
        value: _smartStages,
        onChanged: (value) {
          setState(() => _smartStages = value);
          _refreshDraftPreferences();
        },
      ),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: () async {
            final value = await showTimePicker(context: context, initialTime: _departure);
            if (value == null || !mounted) return;
            setState(() => _departure = value);
            _refreshDraftPreferences();
            unawaited(_persistDefaults());
          },
          icon: const Icon(Icons.schedule_rounded, size: 18),
          label: FittedBox(fit: BoxFit.scaleDown,
            child: Text('Saída ${_departure.format(context)}')),
        )),
        const SizedBox(width: 8),
        Expanded(child: _choice('A cada', _breakEveryKm,
          const [15, 20, 30], 'km', (v) {
            setState(() => _breakEveryKm = v); _refreshDraftPreferences(); unawaited(_persistDefaults());
          })),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _choice('Pausa', _breakMinutes,
          const [5, 10, 15, 20], 'min', (v) {
            setState(() => _breakMinutes = v); _refreshDraftPreferences(); unawaited(_persistDefaults());
          })),
        const SizedBox(width: 8),
        Expanded(child: _choice('Almoço', _lunchMinutes,
          const [0, 30, 40, 60], 'min', (v) {
            setState(() { _lunchMinutes = v; _forceLunch = true; }); _refreshDraftPreferences(); unawaited(_persistDefaults());
          })),
      ]),
      CheckboxListTile(
        dense: true, contentPadding: EdgeInsets.zero,
        title: const Text('Almoço automático'),
        value: !_forceLunch,
        onChanged: (value) {
          setState(() => _forceLunch = !(value ?? true));
          _refreshDraftPreferences();
          unawaited(_persistDefaults());
        },
      ),
    ]),
  );

  Widget _choice(String label, int selected, List<int> options, String unit,
      ValueChanged<int> change) => PopupMenuButton<int>(
    tooltip: '$label ($selected $unit)',
    onSelected: change,
    itemBuilder: (_) => [for (final v in options)
      PopupMenuItem(value: v, child: Text('$v $unit'))],
    child: Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(children: [
        const Icon(Icons.tune_rounded, size: 17),
        const SizedBox(width: 6),
        Expanded(child: FittedBox(fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('$label: $selected $unit', maxLines: 1))),
        const Icon(Icons.arrow_drop_down_rounded, size: 18),
      ]),
    ),
  );

  // A prévia usa apenas pacotes MBTiles autorizados e presentes no aparelho.
  // O mapa é selecionado pela intersecção aproximada com a geometria; isso
  // NÃO confirma que todos os tiles existam para os zooms necessários.
  void _selectPreviewMapForRoute(MapCyclingRoute? route) {
    final maps = _offlineMaps.packages;
    if (maps.isEmpty) {
      _openPreviewMap(null);
      return;
    }
    final points = route?.points ?? const <LatLng>[];
    final step = points.isEmpty ? 1 : (points.length / 40).ceil();
    OfflineMapPackage? best;
    int bestHits = -1;
    for (final package in maps) {
      final hits = points.isEmpty ? 0 : <int>[
        for (var i = 0; i < points.length; i += step)
          if (package.hasBounds && package.contains(
            latitude: points[i].latitude,
            longitude: points[i].longitude,
          )) i,
      ].length;
      if (hits > bestHits || (hits == bestHits &&
          package.id == _offlineMaps.activeId)) {
        best = package;
        bestHits = hits;
      }
    }
    _openPreviewMap(best);
  }

  void _openPreviewMap(OfflineMapPackage? package) {
    if (_previewOfflineMapId == package?.id &&
        (package == null || _previewOfflineTileProvider != null)) {
      return;
    }
    _previewOfflineTileProvider?.release();
    _previewOfflineTileProvider = null;
    _previewOfflineMapId = package?.id;
    _previewMinZoom = 0;
    _previewMaxZoom = 19;
    if (package == null) return;
    RetainedMbTilesTileProvider? provider;
    try {
      provider = RetainedMbTilesTileProvider.fromPath(path: package.path);
      final metadata = provider.delegate.mbtiles.getMetadata();
      final minZoom = (metadata.minZoom ?? 0).floor().clamp(0, 22).toInt();
      final maxZoom = (metadata.maxZoom ?? 19).ceil()
          .clamp(minZoom, 22).toInt();
      _previewMinZoom = minZoom;
      _previewMaxZoom = maxZoom;
      _previewOfflineTileProvider = provider;
    } catch (_) {
      provider?.release();
      // A rota ainda pode ser visualizada sem mapa-base. Nenhum dado é apagado.
    }
  }

  OfflineMapPackage? get _selectedPreviewMap {
    for (final item in _offlineMaps.packages) {
      if (item.id == _previewOfflineMapId) return item;
    }
    return null;
  }

  String _previewCoverageMessage(MapCyclingRoute route) {
    final package = _selectedPreviewMap;
    if (package == null) return 'Nenhum MBTiles disponível. Importe um na aba Mapas.';
    if (_previewOfflineTileProvider == null) {
      return 'Não foi possível abrir este MBTiles. Verifique o arquivo na aba Mapas.';
    }
    if (!package.hasBounds) {
      return 'MBTiles aberto sem limites geográficos informados. Cobertura não verificada.';
    }
    final points = route.points;
    final step = (points.length / 80).ceil().clamp(1, 100000).toInt();
    var matches = 0;
    var count = 0;
    for (var i = 0; i < points.length; i += step) {
      count++;
      if (package.contains(
        latitude: points[i].latitude,
        longitude: points[i].longitude,
      )) {
        matches++;
      }
    }
    if (matches < count) {
      return 'Atenção: $matches de $count amostras da rota estão dentro '
          'dos limites do MBTiles; trechos podem ficar sem mapa.';
    }
    return 'Rota dentro dos limites declarados do MBTiles. A presença '
        'de todos os tiles e níveis de zoom não foi verificada.';
  }

  List<RouteExplorerResult> _offlinePoisOnRoute(MapCyclingRoute route) {
    final packages = _savedPois.offlinePackages;
    if (packages.isEmpty || route.points.length < 2) {
      return const <RouteExplorerResult>[];
    }
    final signature = packages.map((p) =>
        '${p.id}:${p.itemCount}:${p.updatedAt.millisecondsSinceEpoch}').join('|');
    if (identical(_cachedPoiRoute, route) &&
        _cachedPoiPackageSignature == signature) {
      return _cachedPoiMarkers;
    }
    final source = <String, RouteExplorerResult>{};
    final candidates = <MapDestinationSearchResult>[];
    var south = double.infinity;
    var north = double.negativeInfinity;
    var west = double.infinity;
    var east = double.negativeInfinity;
    for (final point in route.points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    for (final package in packages) {
      for (final poi in package.items) {
        // Caixa grosseira antes da projeção precisa evita varrer arquivos
        // enormes a cada desenho da tela; não substitui o teste geodésico.
        if (poi.latitude < south - 0.04 || poi.latitude > north + 0.04 ||
            poi.longitude < west - 0.04 || poi.longitude > east + 0.04) {
          continue;
        }
        final key = '${poi.category.name}:${poi.latitude.toStringAsFixed(5)}:'
            '${poi.longitude.toStringAsFixed(5)}';
        if (source.containsKey(key)) continue;
        source[key] = poi;
        candidates.add(MapDestinationSearchResult(
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
        // Evita varrer milhões de elementos em pacotes enormes na UI.
        if (candidates.length >= 650) break;
      }
      if (candidates.length >= 650) break;
    }
    final located = RouteCorridorIndex.locate(
      route: route.points,
      routeDistanceMeters: route.distanceMeters,
      places: candidates,
      maximumProximityMeters: 2500,
      maximumResults: 40,
    );
    final markers = <RouteExplorerResult>[
      for (final match in located)
        if (source[match.place.id] != null) source[match.place.id]!,
    ];
    _cachedPoiRoute = route;
    _cachedPoiPackageSignature = signature;
    _cachedPoiMarkers = markers;
    return markers;
  }

  List<RouteCorridorPlace> _nearbyRoutePlaces(PlannedBikeTrip trip) {
    if (identical(_cachedTripForPlaces, trip)) return _cachedTripMatches;
    final located = RouteCorridorIndex.locate(
      route: trip.selectedRoute.points,
      routeDistanceMeters: trip.selectedRoute.distanceMeters,
      places: trip.places,
      maximumProximityMeters: 3500,
      maximumResults: 100,
    );
    _cachedTripForPlaces = trip;
    _cachedTripMatches = located;
    return located;
  }

  Widget _preview(PlannedBikeTrip trip) {
    final route = trip.selectedRoute;
    final plan = _plan(trip);
    final estimate = plan.estimate;
    final terrain = TripTerrainService.forDays(route: route, days: plan.days);
    final simulatedDays = <BikeTripDayPlan>[
      for (var i = 0; i < plan.days.length; i++)
        TripEffortReserveService.adjustedDay(
          day: plan.days[i], terrain: terrain[i],
          minutesPer100Meters: trip.climbReserveMinutesPer100m,
        ),
    ];
    final plannedRideSeconds = simulatedDays.fold<int>(0,
        (sum, day) => sum + day.ridingDuration.inSeconds);
    final reservedMinutes = ((plannedRideSeconds -
        plan.days.fold<int>(0, (sum, day) => sum + day.ridingDuration.inSeconds)) / 60)
        .round();
    final departureDate = trip.startDate;
    return Column(key: _previewKey, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      Text('Resultado do planejamento', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (trip.routes.length > 1)
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (var i = 0; i < trip.routes.length; i++)
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
              label: Text('Rota ${i + 1} · ${(trip.routes[i].distanceMeters / 1000).toStringAsFixed(0)} km'
                  '${trip.routes[i].ascentMeters == null ? '' : ' · +${trip.routes[i].ascentMeters!.toStringAsFixed(0)} m'}'),
              selected: trip.selectedIndex == i,
              onSelected: (_) {
                _selectPreviewMapForRoute(trip.routes[i]);
                final next = trip.copyWith(selectedIndex: i, places: const [],
                    weatherDays: const <TripWeatherDayForecast>[]);
                setState(() => _draft = next);
                unawaited(_fillLocalPlaces(next));
              },
            )),
        ])),
      const SizedBox(height: 8),
      _routeMap(trip),
      _offlineReadinessCard(trip, plan),
      if (plan.days.length > 1)
        const Text('Os marcadores numerados no mapa indicam os finais de etapa. '
            'Paradas e acessos precisam de confirmação; rotas muito longas '
            'mostram até 80 marcadores.', style: TextStyle(fontSize: 11)),
      if (_savedPois.offlinePackages.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Pontos salvos próximos ao trajeto aparecem no mapa, '
              'mesmo sem GPS ou internet.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      _routeActions(trip),
      const SizedBox(height: 6),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        Text('${trip.origin.title} → ${trip.destination.title}',
          style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _metric('Distância', '${estimate.distanceKm.toStringAsFixed(1)} km', Icons.route_rounded)),
          Expanded(child: _metric('Pedalando', '${(plannedRideSeconds / 3600).toStringAsFixed(1)} h', Icons.timer_outlined)),
          Expanded(child: _metric('Dias', '${estimate.dayCount}', Icons.calendar_today_outlined)),
        ]),
        const SizedBox(height: 8),
        if (route.ascentMeters != null || route.descentMeters != null)
          Text('Relevo do provedor: subida '
              '${route.ascentMeters?.toStringAsFixed(0) ?? '?'} m · descida '
              '${route.descentMeters?.toStringAsFixed(0) ?? '?'} m',
              style: const TextStyle(fontSize: 12)),
        Text(reservedMinutes > 0
            ? 'Cenário: ${estimate.ridingHours.toStringAsFixed(1)} h base + '
                '$reservedMinutes min de reserva para subidas documentadas.'
            : 'Tempo base: velocidade média fixa. Sem reserva de subida aplicada.',
          style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
        Text(trip.smartStages
            ? 'Divisão inteligente ativa: dias organizados pelo tempo base e pela reserva de subidas com altitude disponível. Paradas sugeridas não são pernoites confirmados.'
            : 'Divisão tradicional: os dias seguem a distância e a velocidade médias, sem aumentar o número de dias por subida.',
          style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
        const Text('Simulação, não previsão: bagagem, vento, segurança do acesso e disponibilidade de hospedagem não são calculados.',
          style: TextStyle(fontSize: 11), textAlign: TextAlign.center),
      ]))),
      const SizedBox(height: 8),
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Reserva de tempo e limite de chegada',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        const Text('Escolha quantos minutos acrescentar a cada 100 m de subida '
            'presentes no perfil de elevação. Zero desativa. Não há extrapolação '
            'quando faltam altitudes.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 7),
        Row(children: [
          Expanded(child: _choice('Subidas', trip.climbReserveMinutesPer100m,
              const [0, 5, 10, 15, 20], 'min/100m', (value) {
            setState(() => _draft = trip.copyWith(
              climbReserveMinutesPer100m: value,
              weatherDays: const <TripWeatherDayForecast>[],
            ));
          })),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonFormField<int>(
            key: ValueKey('chegada-limite-${trip.id}-${trip.latestArrivalMinute}'),
            initialValue: trip.latestArrivalMinute,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Chegar até', border: OutlineInputBorder(), isDense: true,
            ),
            items: [for (final hour in const [15, 16, 17, 18, 19, 20, 21])
              DropdownMenuItem(value: hour * 60, child: Text('$hour:00'))],
            onChanged: (value) {
              if (value != null) {
                setState(() => _draft = trip.copyWith(latestArrivalMinute: value));
              }
            },
          )),
        ]),
        const SizedBox(height: 5),
        const Text('Limite de chegada pessoal; não representa a hora do pôr do sol. '
            'Para guardar alterações, use Salvar viagem.',
            style: TextStyle(fontSize: 11)),
      ]))),
      const SizedBox(height: 8),
      Card(child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Clima por etapa · consulta manual',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(departureDate == null
              ? 'Escolha uma data de partida para relacionar o clima aos dias de pedal.'
              : 'Partida prevista: ${_formatTripDate(departureDate)}. '
                  'Previsões já consultadas são preservadas ao salvar a viagem.'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _fetchingWeather ? null : () => unawaited(_selectStartDate()),
              icon: const Icon(Icons.event_outlined),
              label: const Text('Data de partida'),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: departureDate == null || _fetchingWeather
                  ? null : () => unawaited(_checkTripWeather()),
              icon: const Icon(Icons.cloud_outlined),
              label: const Text('Consultar clima'),
            )),
          ]),
          if (_fetchingWeather) const LinearProgressIndicator(),
          const Text('Open-Meteo.com (CC BY 4.0) · até 16 dias de previsão; no máximo 8 consultas '
              'por toque. Sem internet, apenas dados consultados e salvos. '
              'Confira avisos oficiais antes de pedalar.',
              style: TextStyle(fontSize: 11)),
        ]),
      )),
      const SizedBox(height: 6),
      Text(_showOnlineBaseMap
        ? 'Mapa-base online: requer internet. A geometria permanece salva.'
        : _previewCoverageMessage(route),
        style: Theme.of(context).textTheme.bodySmall),
      if (_offlineMaps.packages.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DropdownButtonFormField<String>(
            key: ValueKey('preview-mbtiles-$_previewOfflineMapId'),
            initialValue: _previewOfflineMapId,
            decoration: const InputDecoration(
              labelText: 'Mapa offline para esta rota',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final package in _offlineMaps.packages)
                DropdownMenuItem(value: package.id, child: Text(
                  package.name, overflow: TextOverflow.ellipsis,
                )),
            ],
            onChanged: (value) {
              for (final package in _offlineMaps.packages) {
                if (package.id == value) {
                  setState(() => _openPreviewMap(package));
                  break;
                }
              }
            },
          ),
        ),
      SwitchListTile.adaptive(
        dense: true, contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar mapa-base online'),
        subtitle: const Text('Consome internet; não baixa mapas para uso offline.'),
        value: _showOnlineBaseMap,
        onChanged: (v) => setState(() => _showOnlineBaseMap = v),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _fetchingPlaces ? null : () => unawaited(_findStops(online: false)),
          icon: const Icon(Icons.offline_pin_outlined), label: const Text('Apoios salvos'),
        )),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(
          onPressed: _fetchingPlaces ? null : () => unawaited(_findStops(online: true)),
          icon: const Icon(Icons.travel_explore_rounded), label: const Text('Buscar apoios'),
        )),
      ]),
      if (_fetchingPlaces) const LinearProgressIndicator(),
      if (trip.places.isNotEmpty) ...[
        const SizedBox(height: 8),
        Card(child: ExpansionTile(
          initiallyExpanded: true,
          title: const Text('Localidades e apoios próximos do traçado'),
          subtitle: Text('${_nearbyRoutePlaces(trip).length} local(is) em ordem de percurso · '
              'até 3,5 km em linha reta'),
          children: [
            for (final match in _nearbyRoutePlaces(trip))
              ListTile(
                dense: true,
                leading: Icon(match.place.kind == MapDestinationKind.pointOfInterest
                    ? Icons.local_cafe_outlined : Icons.location_city_outlined),
                title: Text(match.place.title),
                subtitle: Text('km ${(match.routeDistanceMeters / 1000).toStringAsFixed(1)} '
                    '· ${match.place.kind.label} · '
                    '${match.proximityMeters.toStringAsFixed(0)} m da linha '
                    '· ${match.place.storedLocally ? 'local' : 'online'}'),
                onTap: () => unawaited(_openMap(trip,
                    focusPoint: LatLng(match.place.latitude, match.place.longitude))),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text('Proximidade em linha reta não confirma passagem pela via, acesso seguro, água ou hospedagem. '
                  'Ordem e quilômetros aproximados a partir da geometria.'),
            ),
          ],
        )),
      ] else
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Nenhuma cidade ou apoio identificado no corredor salvo. '
              'Use “Apoios salvos” ou “Buscar apoios” quando houver internet.',
            style: Theme.of(context).textTheme.bodySmall),
        ),
      const SizedBox(height: 8),
      Text('Etapas da viagem', style: Theme.of(context).textTheme.titleMedium),
      Builder(builder: (context) {
        final verified = plan.days.where((stage) =>
            trip.stopChecks.any((check) => check.matches(
              stage: stage, selectedRouteIndex: trip.selectedIndex))).length;
        return Text('Conferências salvas: $verified de ${plan.days.length} paradas. '
            'Abra cada etapa e toque em Conferir para anotar acesso, água, '
            'pernoite e observações sem internet.',
            style: Theme.of(context).textTheme.bodySmall);
      }),
      const Text('Abra cada dia para conferir horários, altitude, clima e '
          'avisos de planejamento. Os limites são suas preferências, não '
          'garantia de segurança.', style: TextStyle(fontSize: 12)),
      for (var i = 0; i < simulatedDays.length; i++)
        _dayCard(simulatedDays[i], trip, terrain[i]),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => unawaited(_openMap(trip)),
        icon: const Icon(Icons.map_outlined),
        label: Text(widget.returnToMap ? 'Voltar aos Mapas com esta rota' : 'Abrir prévia nos Mapas'),
      ),
      const SizedBox(height: 6),
      const Text('A biblioteca guarda cidades, geometria, instruções e etapas. Não faz recálculo sem internet. Para os mapas da região, use o gerenciador offline na aba Mapas.',
        style: TextStyle(fontSize: 12)),
    ]);
  }

  Future<void> _checkOfflineReadiness(PlannedBikeTrip trip, BikeTripPlan plan) async {
    if (_checkingOfflineReadiness) {
      return;
    }
    setState(() => _checkingOfflineReadiness = true);
    try {
      final result = await TripOfflineReadinessService.inspect(
        trip: trip,
        plan: plan,
        offlineMaps: _offlineMaps.packages,
        offlinePoiPackages: _savedPois.offlinePackages,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lastReadinessTrip = trip;
        _lastReadinessReport = result;
      });
    } catch (_) {
      if (mounted) {
        _notify('Não foi possível conferir os arquivos locais. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _checkingOfflineReadiness = false);
      }
    }
  }

  Widget _offlineReadinessCard(PlannedBikeTrip trip, BikeTripPlan plan) {
    // O diagnóstico é sob demanda e somente vale para a mesma instância
    // imutável da viagem. Editou o plano? Deve repetir a conferência.
    final report = identical(_lastReadinessTrip, trip)
        ? _lastReadinessReport : null;
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Preparação offline antes de sair',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        const Text('Confira sem internet e sem GPS se existem mapas locais, '
            'quais trechos estão dentro dos limites declarados dos MBTiles, '
            'pontos de apoio salvos e paradas conferidas. A análise não faz '
            'download nem verifica cada tile do mapa.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _checkingOfflineReadiness
              ? null : () => unawaited(_checkOfflineReadiness(trip, plan)),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(_checkingOfflineReadiness
              ? 'Conferindo arquivos locais…' : 'Verificar preparação offline'),
        ),
        if (_checkingOfflineReadiness) const LinearProgressIndicator(),
        if (report != null) ...[
          const SizedBox(height: 8),
          Text(report.needsReview
              ? 'Há itens a revisar antes da viagem.'
              : 'Nenhuma pendência básica encontrada; teste os mapas e paradas na prática.',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('MBTiles presentes: ${report.availableMaps} '
              '· ausentes/inacessíveis: ${report.missingMapFiles}'),
          Text('Amostras da rota nos limites declarados: '
              '${report.samplesWithinMapBounds}/${report.routeSamples} '
              '· desconhecidas: ${report.samplesWithUnknownCoverage} '
              '· fora dos limites: ${report.samplesOutsideAvailableBounds}'),
          Text('Pacotes de pontos: ${report.offlinePoiPackages} '
              '· apoios próximos identificados: ${report.offlinePoisNearRoute} '
              '· localidades guardadas na viagem: ${report.savedItineraryPlaces}'),
          Text('Etapas com conferência manual válida: '
              '${report.stagesWithManualChecks}/${report.stages} '
              '· pernoites intermediários pendentes: '
              '${report.intermediateStopsWithoutOvernightCheck}'),
          if (report.warnings.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final warning in report.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.warning_amber_outlined, size: 17),
                  const SizedBox(width: 6),
                  Expanded(child: Text(warning, style: const TextStyle(fontSize: 12))),
                ]),
              ),
          ],
          const SizedBox(height: 5),
          Text('Verificado ${report.checkedAt.toLocal().day}/'
              '${report.checkedAt.toLocal().month} às '
              '${report.checkedAt.toLocal().hour.toString().padLeft(2, '0')}:'
              '${report.checkedAt.toLocal().minute.toString().padLeft(2, '0')}. '
              'Amostragem e retângulos geográficos não garantem tiles em todos '
              'os zooms, acesso por estrada, água ou hospedagem. '
              'Repetir após modificar a viagem ou os mapas.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    ));
  }

  Widget _metric(String title, String value, IconData icon) => Column(children: [
    Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
    const SizedBox(height: 3),
    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    Text(title, style: Theme.of(context).textTheme.labelSmall),
  ]);

  Widget _routeMap(PlannedBikeTrip trip) {
    final route = trip.selectedRoute;
    final points = route.points;
    final routePoints = points.length <= 1200 ? points : <LatLng>[
      for (var i = 0; i < points.length; i += (points.length / 1200).ceil()) points[i],
      points.last,
    ];
    final offlinePois = _offlinePoisOnRoute(route);
    final stageStops = _plan(trip).days;
    final provider = _previewOfflineTileProvider;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(height: 290, child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: FlutterMap(
          key: ValueKey('${_draft?.id}-${_draft?.selectedIndex}-'
              '$_showOnlineBaseMap-$_previewOfflineMapId'),
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: routePoints,
              padding: const EdgeInsets.all(32),
              minZoom: 2,
              maxZoom: 14,
            ),
          ),
          children: [
            if (!_showOnlineBaseMap && provider != null)
              TileLayer(
                key: ValueKey('planning-offline-$_previewOfflineMapId'),
                tileProvider: provider,
                minNativeZoom: _previewMinZoom,
                maxNativeZoom: _previewMaxZoom,
              ),
            if (_showOnlineBaseMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vigiaia.app',
                maxNativeZoom: 19,
              ),
            PolylineLayer(polylines: [
              Polyline(points: routePoints,
                color: Theme.of(context).colorScheme.primary, strokeWidth: 5),
            ]),
            if (offlinePois.isNotEmpty)
              MarkerLayer(markers: [
                for (final poi in offlinePois)
                  Marker(
                    point: LatLng(poi.latitude, poi.longitude),
                    width: 28, height: 28,
                    child: Tooltip(
                      message: '${poi.title} · ${poi.category.label} (salvo)',
                      child: InkWell(
                        onTap: () => _notify('${poi.title} · ${poi.category.label} · pacote offline'),
                        child: const Icon(Icons.place_rounded,
                          color: Colors.deepOrange, size: 22),
                      ),
                    ),
                  ),
              ]),
            if (trip.places.isNotEmpty)
              MarkerLayer(markers: [
                for (final match in _nearbyRoutePlaces(trip).take(32))
                  Marker(
                    point: LatLng(match.place.latitude, match.place.longitude),
                    width: 28, height: 28,
                    child: Tooltip(
                      message: '${match.place.title} · ${match.place.kind.label}',
                      child: InkWell(
                        onTap: () => _notify('${match.place.title} · ${match.place.kind.label} '
                            '· proximidade em linha reta, acesso não verificado'),
                        child: const Icon(Icons.location_city_rounded,
                          color: Colors.indigo, size: 22),
                      ),
                    ),
                  ),
              ]),
            // Marcação dos finais de etapa usando dados da própria viagem.
            // Corresponde ao plano atual; não pressupõe pernoite disponível.
            if (stageStops.length > 1)
              MarkerLayer(markers: [
                for (final day in stageStops.take(80))
                  if (day.day < stageStops.length)
                    Marker(
                      point: LatLng(day.stopLatitude, day.stopLongitude),
                      width: 35, height: 35,
                      child: Tooltip(
                        message: 'Dia ${day.day}: ${day.stopLabel} '
                            '${day.usesKnownPlace ? '(local candidato)' : '(parada aproximada)'}',
                        child: InkWell(
                          onTap: () => _notify('Parada do dia ${day.day}: '
                              '${day.stopLabel}. Confirme acesso e segurança.'),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text('${day.day}', style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold, fontSize: 12,
                            )),
                          ),
                        ),
                      ),
                    ),
              ]),
            MarkerLayer(markers: [
              Marker(point: points.first, width: 32, height: 32,
                  child: const Icon(Icons.trip_origin_rounded,
                    color: Colors.green, size: 28)),
              Marker(point: points.last, width: 32, height: 32,
                  child: const Icon(Icons.location_on_rounded,
                    color: Colors.red, size: 32)),
            ]),
            if (_showOnlineBaseMap)
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ]),
          ],
        ),
      )),
    );
  }

  TripStopCheck? _checkForDay(PlannedBikeTrip trip, int day) {
    for (final check in trip.stopChecks) {
      if (check.routeIndex == trip.selectedIndex && check.day == day) {
        return check;
      }
    }
    return null;
  }

  /// A anotação é persistida imediatamente, mesmo se a viagem ainda não
  /// estiver na biblioteca. Não requer GPS, permissões ou conexão de rede.
  Future<void> _editStopCheck(BikeTripDayPlan day, PlannedBikeTrip trip) async {
    if (_libraryReadFailed || _busy) {
      _notify('Biblioteca offline indisponível. Nenhuma anotação foi alterada.');
      return;
    }
    final previous = _checkForDay(trip, day.day);
    final valid = previous?.matches(stage: day,
        selectedRouteIndex: trip.selectedIndex) ?? false;
    var access = valid && previous!.accessChecked;
    var water = valid && previous!.waterChecked;
    var overnight = valid && previous!.overnightChecked;
    final notesController = TextEditingController(text: valid ? previous!.notes : '');
    final TripStopCheck? edited;
    try {
      edited = await showDialog<TripStopCheck>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, updateDialog) => AlertDialog(
            title: Text('Conferir parada · dia ${day.day}'),
            content: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.stopLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Km ${(day.endDistanceMeters / 1000).toStringAsFixed(1)} da rota. '
                    'Marque apenas informações verificadas pessoalmente.'),
                if (previous != null && !valid)
                  const Padding(padding: EdgeInsets.only(top: 8),
                    child: Text('A etapa mudou. A conferência anterior está desatualizada; '
                        'revise cada item para esta nova parada.',
                        style: TextStyle(fontSize: 12))),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Acesso pela via conferido'),
                  value: access,
                  onChanged: (value) => updateDialog(() => access = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Água conferida'),
                  value: water,
                  onChanged: (value) => updateDialog(() => water = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pernoite conferido'),
                  value: overnight,
                  onChanged: (value) => updateDialog(() => overnight = value ?? false),
                ),
                TextField(
                  controller: notesController,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas offline',
                    hintText: 'Ex.: telefone, horário, fonte da confirmação',
                    border: OutlineInputBorder(),
                  ),
                ),
                const Text('A marcação é manual, não garante serviço disponível '
                    'na data da passagem. As notas entram no JSON exportado.',
                    style: TextStyle(fontSize: 12)),
              ],
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              if (previous != null)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, TripStopCheck(
                    day: day.day,
                    routeIndex: trip.selectedIndex,
                    endDistanceMeters: day.endDistanceMeters,
                    latitude: day.stopLatitude,
                    longitude: day.stopLongitude,
                    checkedAt: DateTime.now(),
                  )),
                  child: const Text('Limpar'),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, TripStopCheck(
                  day: day.day,
                  routeIndex: trip.selectedIndex,
                  endDistanceMeters: day.endDistanceMeters,
                  latitude: day.stopLatitude,
                  longitude: day.stopLongitude,
                  checkedAt: DateTime.now(),
                  accessChecked: access,
                  waterChecked: water,
                  overnightChecked: overnight,
                  notes: notesController.text.trim(),
                )),
                child: const Text('Salvar no aparelho'),
              ),
            ],
          ),
        ),
      );
    } finally {
      notesController.dispose();
    }
    if (edited == null || !mounted) {
      return;
    }
    final current = _draft;
    if (current == null || current.id != trip.id ||
        current.selectedIndex != trip.selectedIndex ||
        day.day > _plan(current).days.length ||
        !_isSameStop(_plan(current).days[day.day - 1], day)) {
      _notify('A rota ou a parada mudou. Reabra a conferência antes de salvar.');
      return;
    }
    final updatedChecks = <TripStopCheck>[
      for (final check in current.stopChecks)
        if (check.day != day.day || check.routeIndex != current.selectedIndex) check,
      if (edited.hasDetails) edited,
    ];
    // Nenhuma anotação nova deve sumir silenciosamente por corte no JSON.
    if (updatedChecks.length > 400) {
      _notify('Limite de 400 conferências: remova um registro antigo antes de salvar.');
      return;
    }
    // A biblioteca salva 40 viagens. Não expulsa uma viagem antiga apenas
    // porque o usuário quis anotar a parada de um rascunho novo.
    if (!_saved.any((saved) => saved.id == current.id) &&
        _saved.length >= PlannedBikeTripService.maximumTrips) {
      _notify('Biblioteca cheia (40 viagens). Exclua uma viagem conscientemente antes de salvar.');
      return;
    }
    final updated = current.copyWith(
        stopChecks: List<TripStopCheck>.unmodifiable(updatedChecks));
    try {
      await _library.upsert(updated);
      final refreshed = await _library.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _saved = refreshed;
        if (identical(_draft, current)) {
          _draft = updated;
        }
      });
      _notify(edited.hasDetails ? 'Conferência salva no aparelho para consulta offline.'
          : 'Conferência removida do armazenamento local.');
    } catch (_) {
      _notify('Não foi possível salvar a conferência. Nenhum registro anterior foi apagado.');
    }
  }

  bool _isSameStop(BikeTripDayPlan current, BikeTripDayPlan previous) =>
      current.day == previous.day &&
      (current.endDistanceMeters - previous.endDistanceMeters).abs() <= 250 &&
      (current.stopLatitude - previous.stopLatitude).abs() <= 0.00005 &&
      (current.stopLongitude - previous.stopLongitude).abs() <= 0.00005;

  Widget _dayCard(BikeTripDayPlan day, PlannedBikeTrip trip, TripDayTerrain terrain) {
    final schedule = BikeTripSchedule.forDay(
      day: day,
      departureMinute: trip.departureMinute,
      breakEveryKm: trip.breakEveryKm,
      breakDurationMinutes: trip.breakMinutes,
      lunchDurationMinutes: trip.lunchMinutes,
      forceLunch: trip.forceLunch,
    );
    final savedCheck = _checkForDay(trip, day.day);
    final checkValid = savedCheck?.matches(
        stage: day, selectedRouteIndex: trip.selectedIndex) ?? false;
    final notices = TripDayReadinessService.notices(
      day: day, schedule: schedule,
      targetRidingHours: trip.ridingHoursPerDay,
      latestArrivalMinute: trip.latestArrivalMinute,
      terrain: terrain,
      minutesPer100Meters: trip.climbReserveMinutesPer100m,
      overnightManuallyChecked: checkValid && savedCheck?.overnightChecked == true,
      accessManuallyChecked: checkValid && savedCheck?.accessChecked == true,
    );
    final checkedItems = <String>[
      if (checkValid && savedCheck?.accessChecked == true) 'acesso',
      if (checkValid && savedCheck?.waterChecked == true) 'água',
      if (checkValid && savedCheck?.overnightChecked == true) 'pernoite',
    ];
    final climbReserve = TripEffortReserveService.reserveMinutes(
      terrain: terrain, minutesPer100Meters: trip.climbReserveMinutesPer100m,
    );
    return Card(child: ExpansionTile(
      leading: CircleAvatar(child: Text('${day.day}')),
      title: Text('Dia ${day.day} · ${(day.distanceMeters / 1000).toStringAsFixed(1)} km'),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(day.stopLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(savedCheck == null ? 'Parada ainda não conferida'
            : checkValid ? 'Conferência manual salva offline'
            : 'Conferência antiga: parada alterada, revisar',
            style: TextStyle(fontSize: 12, color: checkValid
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error)),
        if (notices.isNotEmpty)
          Text('${notices.length} aviso(s) para revisar',
              style: TextStyle(color: Theme.of(context).colorScheme.error,
                  fontSize: 12)),
      ]),
      trailing: IconButton(
        tooltip: 'Ver parada no mapa',
        icon: const Icon(Icons.map_outlined),
        onPressed: () => unawaited(_openMap(trip,
          focusPoint: LatLng(day.stopLatitude, day.stopLongitude))),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      children: [
        Text('Pedal: ${(day.ridingDuration.inMinutes / 60).toStringAsFixed(1)} h · '
          'Saída ${BikeTripDaySchedule.formatMinute(schedule.departureMinute)} · '
          'Chegada ~${BikeTripDaySchedule.formatMinute(schedule.arrivalMinute)}'),
        Text('${schedule.breakCount} pausa(s) (${schedule.breakMinutes} min); '
          'almoço ${schedule.lunchMinutes} min.'),
        if (climbReserve > 0)
          Text('Reserva simulada para subida: +$climbReserve min '
              '(incluída no horário acima).'),
        for (final notice in notices)
          Padding(padding: const EdgeInsets.only(top: 4), child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16),
              const SizedBox(width: 5),
              Expanded(child: Text(notice, style: const TextStyle(fontSize: 12))),
            ],
          )),
        if (terrain.hasSamples)
          Text('Perfil de elevação: +${terrain.ascentMeters.toStringAsFixed(0)} m '
              '/ -${terrain.descentMeters.toStringAsFixed(0)} m · '
              'cobertura ${(terrain.coverageFraction * 100).toStringAsFixed(0)}% '
              '(estimativa das altitudes do provedor).')
        else
          const Text('Desnível nesta etapa: indisponível (sem perfil altimétrico).'),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(checkValid
              ? (checkedItems.isEmpty
                  ? 'Anotação salva, sem serviços conferidos.'
                  : 'Conferido por você: ${checkedItems.join(' · ')}')
              : 'Sem serviços conferidos para esta parada.',
              style: Theme.of(context).textTheme.bodySmall)),
          TextButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => unawaited(_editStopCheck(day, trip)),
            label: const Text('Conferir'),
          ),
        ]),
        if (checkValid && savedCheck!.notes.isNotEmpty)
          Text('Nota offline: ${savedCheck.notes}',
              style: Theme.of(context).textTheme.bodySmall),
        if (savedCheck != null && !checkValid)
          const Text('Registro de outra posição/etapa: precisa ser conferido novamente.',
              style: TextStyle(fontSize: 12)),
        const SizedBox(height: 5),
        _weatherDayLine(day.day, trip),
        const SizedBox(height: 5),
        Text(day.usesKnownPlace
          ? 'Local candidato: ${day.stopKind}. Distância até a via em linha reta: '
              '${day.routeProximityMeters?.toStringAsFixed(0) ?? 'não medida'} m. Verifique acesso e hospedagem.'
          : 'Parada aproximada nas coordenadas ${day.stopLatitude.toStringAsFixed(4)}, '
              '${day.stopLongitude.toStringAsFixed(4)}. Não indica cidade ou hospedagem confirmada.',
          style: Theme.of(context).textTheme.bodySmall),
      ],
    ));
  }

  Widget _librarySection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 22),
    Text('Viagens salvas', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 6),
    if (_loadingLibrary) const LinearProgressIndicator(),
    if (_saved.isEmpty && !_loadingLibrary)
      const Text('Nenhuma viagem salva. Calcule e salve para consultar sem internet.'),
    for (final trip in _saved)
      Card(child: ListTile(
        leading: const Icon(Icons.directions_bike_rounded),
        title: Text('${trip.origin.title} → ${trip.destination.title}', maxLines: 2),
        subtitle: Text('${(trip.selectedRoute.distanceMeters / 1000).toStringAsFixed(1)} km · '
            '${_plan(trip).estimate.dayCount} dia(s) · offline'),
        onTap: () => _loadTrip(trip),
        trailing: IconButton(
          tooltip: 'Excluir viagem', icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => unawaited(_delete(trip)),
        ),
      )),
  ]);

  @override
  Widget build(BuildContext context) => AdaptiveMainScaffold(
    currentIndex: widget.returnToMap ? 5 : 0,
    onDestinationSelected: (index) {
      if (widget.returnToMap && index == 5) { Navigator.of(context).pop(); return; }
      if (index == 0) { Navigator.of(context).pop(); return; }
      navigateToMainDestination(context, index, currentIndex: 0);
    },
    appBar: AppBar(title: const Text('Planejamento'), actions: [
      IconButton(
        tooltip: 'Abrir mapas e downloads offline',
        onPressed: () => Navigator.push<void>(context,
          MaterialPageRoute<void>(builder: (_) => const MapWorkspaceShell())),
        icon: const Icon(Icons.map_rounded),
      ),
    ]),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 32), children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.route_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Planeje sua próxima viagem', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text('Escolha duas cidades ou use seu local atual. Ajuste o ritmo e visualize o trajeto.',
                    style: Theme.of(context).textTheme.bodySmall),
              ])),
            ]),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy || _loadingLibrary ? null : () => unawaited(_newRouteWizard()),
              icon: const Icon(Icons.add_road_rounded),
              label: const Text('Nova rota'),
            ),
          ]),
        )),
        if (_busy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          const Text('Calculando alternativas pela rede. Nenhuma distância será inventada.'),
        ],
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 8),
          child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_draft != null) _preview(_draft!),
        _librarySection(),
      ]),
    ))),
  );
}
