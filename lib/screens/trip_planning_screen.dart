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
import '../services/bike_trip_planner.dart';
import '../services/bike_trip_editor_bridge.dart';
import '../services/bike_trip_schedule.dart';
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
  bool _showOnlineBaseMap = false;
  String? _message;
  double _speedKmh = 15;
  double _hoursPerDay = 5;
  bool _balanceDays = true;
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

  BikeTripPlan _plan(PlannedBikeTrip trip) => _planner.buildPlan(
    routePoints: trip.selectedRoute.points,
    routeDistanceMeters: trip.selectedRoute.distanceMeters,
    preferences: BikeTravelPreferences(
      averageSpeedKmh: trip.averageSpeedKmh,
      ridingHoursPerDay: trip.ridingHoursPerDay,
      balanceDays: trip.balanceDays,
    ),
    destinationLabel: trip.destination.title,
    candidates: trip.places,
  );

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
        forceLunch: _forceLunch,
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
      setState(() => _draft = draft.copyWith(places: places));
      _notify(places.isEmpty
          ? 'Nenhum apoio confirmado. Os pernoites permanecem aproximados.'
          : '${places.length} local(is) identificado(s); confira os desvios e serviços.');
    } catch (_) {
      _notify('Não foi possível buscar apoios. A rota permanece disponível.');
    } finally {
      if (mounted) setState(() => _fetchingPlaces = false);
    }
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
      setState(() => _draft = trip.copyWith(places: places));
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
        subtitle: const Text('Distribui distâncias parecidas por dia'),
        value: _balanceDays,
        onChanged: (value) {
          setState(() => _balanceDays = value);
          _refreshDraftPreferences();
          unawaited(_persistDefaults());
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
    return Column(key: _previewKey, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      Text('Resultado do planejamento', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (trip.routes.length > 1)
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (var i = 0; i < trip.routes.length; i++)
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
              label: Text('Rota ${i + 1} · ${(trip.routes[i].distanceMeters / 1000).toStringAsFixed(0)} km'),
              selected: trip.selectedIndex == i,
              onSelected: (_) {
                _selectPreviewMapForRoute(trip.routes[i]);
                final next = trip.copyWith(selectedIndex: i, places: const []);
                setState(() => _draft = next);
                unawaited(_fillLocalPlaces(next));
              },
            )),
        ])),
      const SizedBox(height: 8),
      _routeMap(trip),
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
          Expanded(child: _metric('Pedalando', '${estimate.ridingHours.toStringAsFixed(1)} h', Icons.timer_outlined)),
          Expanded(child: _metric('Dias', '${estimate.dayCount}', Icons.calendar_today_outlined)),
        ]),
        const SizedBox(height: 8),
        const Text('Estimativas com velocidade definida. Relevo, vento, segurança e desvios não foram avaliados.',
          style: TextStyle(fontSize: 11), textAlign: TextAlign.center),
      ]))),
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
      for (final day in plan.days)
        _dayCard(day, trip),
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

  Widget _dayCard(BikeTripDayPlan day, PlannedBikeTrip trip) {
    final schedule = BikeTripSchedule.forDay(
      day: day,
      departureMinute: trip.departureMinute,
      breakEveryKm: trip.breakEveryKm,
      breakDurationMinutes: trip.breakMinutes,
      lunchDurationMinutes: trip.lunchMinutes,
      forceLunch: trip.forceLunch,
    );
    return Card(child: ExpansionTile(
      leading: CircleAvatar(child: Text('${day.day}')),
      title: Text('Dia ${day.day} · ${(day.distanceMeters / 1000).toStringAsFixed(1)} km'),
      subtitle: Text(day.stopLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
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
            '${_planner.estimate(distanceMeters: trip.selectedRoute.distanceMeters,
              preferences: BikeTravelPreferences(averageSpeedKmh: trip.averageSpeedKmh,
                ridingHoursPerDay: trip.ridingHoursPerDay)).dayCount} dia(s) · offline'),
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
