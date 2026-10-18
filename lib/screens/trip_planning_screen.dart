import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/bike_trip_plan.dart';
import '../models/map_cycling_route.dart';
import '../models/map_destination_search.dart';
import '../models/map_route_point.dart';
import '../models/map_navigation_target.dart';
import '../models/map_travel_mode.dart';
import '../models/planned_bike_trip.dart';
import '../services/bike_trip_planner.dart';
import '../services/bike_trip_schedule.dart';
import '../services/map_cycling_route_service.dart';
import '../services/map_destination_search_service.dart';
import '../services/map_view_settings_service.dart';
import '../services/offline_map_service.dart';
import '../services/planned_bike_trip_service.dart';
import '../services/route_explorer_service.dart';
import '../services/saved_bike_route_service.dart';
import '../widgets/main_navigation_bar.dart';
import '../widgets/main_navigation_routes.dart';
import 'map_workspace_shell.dart';

/// Planejamento voluntário: não inicia localização, vídeo, IA ou serviço em
/// primeiro plano. Busca remota somente ao enviar pesquisa/cálculo/apoios.
class TripPlanningScreen extends StatefulWidget {
  const TripPlanningScreen({super.key});

  @override
  State<TripPlanningScreen> createState() => _TripPlanningScreenState();
}

class _TripPlanningScreenState extends State<TripPlanningScreen> {
  final _originField = TextEditingController();
  final _destinationField = TextEditingController();
  final _citySearch = MapDestinationSearchService.instance;
  final _offlineMaps = OfflineMapService.instance;
  final _routeProvider = MapCyclingRouteService();
  final _library = const PlannedBikeTripService();
  final _lastMapPreview = const SavedBikeRouteService();
  final _planner = const BikeTripPlanner();

  MapDestinationSearchResult? _origin;
  MapDestinationSearchResult? _destination;
  PlannedBikeTrip? _draft;
  List<PlannedBikeTrip> _saved = const <PlannedBikeTrip>[];
  bool _lookingForOrigin = true;
  bool _busy = false;
  bool _loadingLibrary = true;
  bool _libraryReadFailed = false;
  bool _fetchingPlaces = false;
  bool _showOnlineBaseMap = false;
  String? _message;
  double _speedKmh = 15;
  double _hoursPerDay = 5;
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
        MapViewSettingsService.instance.initialize(),
      ]);
      final trips = await _library.load();
      if (!mounted) return;
      final preferences = MapViewSettingsService.instance.bikeTravelPreferences;
      setState(() {
        _saved = trips;
        _speedKmh = preferences.averageSpeedKmh.clamp(5, 40).toDouble();
        _hoursPerDay = preferences.ridingHoursPerDay.clamp(1, 12).toDouble();
        _loadingLibrary = false;
      });
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
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _citySearch.removeListener(_searchChanged);
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
    unawaited(_citySearch.rememberRecentPlace(place));
    _citySearch.updateLocalQuery(
      query: '', current: _reference,
      offlineMaps: _offlineMaps.packages,
      offlinePoiPackages: const [], onlyDownloaded: true,
    );
  }

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
      );
      setState(() => _draft = trip);
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
    ),
    destinationLabel: trip.destination.title,
    candidates: trip.places,
  );

  void _refreshDraftPreferences() {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _draft = draft.copyWith(
      averageSpeedKmh: _speedKmh,
      ridingHoursPerDay: _hoursPerDay,
      departureMinute: _departure.hour * 60 + _departure.minute,
      breakEveryKm: _breakEveryKm,
      breakMinutes: _breakMinutes,
      lunchMinutes: _lunchMinutes,
    ));
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
      final ordered = <PlannedBikeTrip>[
        draft,
        ..._saved.where((item) => item.id != draft.id),
      ].take(PlannedBikeTripService.maximumTrips).toList(growable: false);
      await _library.saveAll(ordered);
      if (!mounted) return;
      setState(() => _saved = ordered);
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
      if (mounted) setState(() => _saved = updated);
    } catch (_) {
      _notify('Não foi possível excluir a viagem.');
    }
  }

  void _loadTrip(PlannedBikeTrip trip) {
    setState(() {
      _draft = trip;
      _origin = trip.origin;
      _destination = trip.destination;
      _originField.text = trip.origin.title;
      _destinationField.text = trip.destination.title;
      _speedKmh = trip.averageSpeedKmh;
      _hoursPerDay = trip.ridingHoursPerDay;
      _departure = TimeOfDay(hour: trip.departureMinute ~/ 60,
          minute: trip.departureMinute % 60);
      _breakEveryKm = trip.breakEveryKm;
      _breakMinutes = trip.breakMinutes;
      _lunchMinutes = trip.lunchMinutes;
      _message = null;
    });
  }

  Future<void> _openMap(PlannedBikeTrip trip) async {
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
      _notify('Prévia preparada. No mapa, abra “Rota salva” para visualizar.');
      await Navigator.push<void>(context,
        MaterialPageRoute<void>(builder: (_) => const MapWorkspaceShell()));
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
        onTap: () => setState(() => _lookingForOrigin = origin),
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
    if (activeText.isEmpty || results.isEmpty && !_citySearch.searchLoading) {
      if (activeText.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(_citySearch.searchStatusMessage ??
            'Digite uma cidade; toque na lupa para pesquisar pela internet.',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Card(
      child: Column(children: [
        if (_citySearch.searchLoading) const LinearProgressIndicator(),
        for (final place in results)
          ListTile(
            dense: true,
            leading: Icon(Icons.location_city_rounded, color: Theme.of(context).colorScheme.primary),
            title: Text(place.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(place.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: place.storedLocally ? const Icon(Icons.offline_pin_outlined, size: 18) : null,
            onTap: () => _selectCity(place),
          ),
      ]),
    );
  }

  Widget _settings() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ritmo da viagem', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Velocidade média: ${_speedKmh.toStringAsFixed(0)} km/h'),
        Slider(value: _speedKmh, min: 5, max: 40, divisions: 35,
            label: '${_speedKmh.toStringAsFixed(0)} km/h',
            onChanged: (v) { setState(() => _speedKmh = v); _refreshDraftPreferences(); }),
        Text('Pedal por dia: ${_hoursPerDay.toStringAsFixed(0)} h'),
        Slider(value: _hoursPerDay, min: 1, max: 12, divisions: 11,
            label: '${_hoursPerDay.toStringAsFixed(0)} h',
            onChanged: (v) { setState(() => _hoursPerDay = v); _refreshDraftPreferences(); }),
        Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ActionChip(
            avatar: const Icon(Icons.schedule_rounded, size: 19),
            label: Text('Saída ${_departure.format(context)}'),
            onPressed: () async {
              final value = await showTimePicker(context: context, initialTime: _departure);
              if (value == null || !mounted) return;
              setState(() => _departure = value);
              _refreshDraftPreferences();
            },
          ),
          _choice('Pausas a cada', _breakEveryKm, const [15, 20, 30], 'km', (v) {
            setState(() => _breakEveryKm = v); _refreshDraftPreferences();
          }),
          _choice('Pausa', _breakMinutes, const [5, 10, 15, 20], 'min', (v) {
            setState(() => _breakMinutes = v); _refreshDraftPreferences();
          }),
          _choice('Almoço', _lunchMinutes, const [0, 30, 40, 60], 'min', (v) {
            setState(() => _lunchMinutes = v); _refreshDraftPreferences();
          }),
        ]),
      ]),
    ),
  );

  Widget _choice(String label, int selected, List<int> options, String unit,
      ValueChanged<int> change) => PopupMenuButton<int>(
    tooltip: label,
    onSelected: change,
    itemBuilder: (_) => [for (final v in options)
      PopupMenuItem(value: v, child: Text('$v $unit'))],
    child: Chip(label: Text('$label: $selected $unit'),
      avatar: const Icon(Icons.tune_rounded, size: 16)),
  );

  List<MapDestinationSearchResult> _nearbyRoutePlaces(PlannedBikeTrip trip) {
    // Distância até amostras do traçado: não equivale a acesso rodoviário.
    final points = trip.selectedRoute.points;
    final step = (points.length / 600).ceil().clamp(1, 100000).toInt();
    const measure = Distance();
    final close = <MapDestinationSearchResult>[];
    for (final place in trip.places) {
      final location = LatLng(place.latitude, place.longitude);
      var minimum = double.infinity;
      for (var i = 0; i < points.length; i += step) {
        final meters = measure.as(LengthUnit.Meter, points[i], location);
        if (meters < minimum) minimum = meters;
      }
      if (minimum < 2500) close.add(place.copyWith(distanceMeters: minimum));
    }
    close.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return close.take(12).toList(growable: false);
  }

  Widget _preview(PlannedBikeTrip trip) {
    final route = trip.selectedRoute;
    final plan = _plan(trip);
    final estimate = plan.estimate;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      Text('Resultado do planejamento', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
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
      if (trip.routes.length > 1)
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (var i = 0; i < trip.routes.length; i++)
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
              label: Text('Rota ${i + 1} · ${(trip.routes[i].distanceMeters / 1000).toStringAsFixed(0)} km'),
              selected: trip.selectedIndex == i,
              onSelected: (_) => setState(() => _draft = trip.copyWith(selectedIndex: i, places: const [])),
            )),
        ])),
      const SizedBox(height: 8),
      _routeMap(route),
      const SizedBox(height: 6),
      Text(_showOnlineBaseMap
        ? 'Mapa online: OpenStreetMap. A geometria da rota permanece salva offline.'
        : 'Traçado da rota sem mapa-base, disponível offline. Ative o mapa online se desejar.',
        style: Theme.of(context).textTheme.bodySmall),
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
        Text('Localidades e apoios próximos do traçado',
          style: Theme.of(context).textTheme.titleMedium),
        for (final place in _nearbyRoutePlaces(trip))
          ListTile(
            dense: true,
            leading: const Icon(Icons.place_outlined),
            title: Text(place.title),
            subtitle: Text('${place.kind.label} · ${place.distanceMeters.toStringAsFixed(0)} m em linha reta da geometria'),
          ),
        Text('Proximidade em linha reta não confirma passagem pela via, acesso seguro, água ou hospedagem.',
          style: Theme.of(context).textTheme.bodySmall),
      ],
      const SizedBox(height: 8),
      Text('Etapas da viagem', style: Theme.of(context).textTheme.titleMedium),
      for (final day in plan.days)
        _dayCard(day, trip),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () => unawaited(_save()),
        icon: const Icon(Icons.save_outlined),
        label: const Text('Salvar viagem para consultar offline'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => unawaited(_openMap(trip)),
        icon: const Icon(Icons.map_outlined),
        label: const Text('Abrir prévia nos Mapas'),
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

  Widget _routeMap(MapCyclingRoute route) {
    final points = route.points;
    final routePoints = points.length <= 1200 ? points : <LatLng>[
      for (var i = 0; i < points.length; i += (points.length / 1200).ceil()) points[i],
      points.last,
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(height: 220, child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: FlutterMap(
          key: ValueKey('${_draft?.id}-${_draft?.selectedIndex}-$_showOnlineBaseMap'),
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: routePoints,
              padding: const EdgeInsets.all(32),
              minZoom: 2,
              maxZoom: 14,
            ),
          ),
          children: [
            if (_showOnlineBaseMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vigiaia.app',
                maxNativeZoom: 19,
              ),
            PolylineLayer(polylines: [
              Polyline(points: routePoints, color: Theme.of(context).colorScheme.primary, strokeWidth: 5),
            ]),
            MarkerLayer(markers: [
              Marker(point: points.first, width: 32, height: 32,
                  child: const Icon(Icons.trip_origin_rounded, color: Colors.green, size: 28)),
              Marker(point: points.last, width: 32, height: 32,
                  child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 32)),
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
    );
    return Card(child: ExpansionTile(
      leading: CircleAvatar(child: Text('${day.day}')),
      title: Text('Dia ${day.day} · ${(day.distanceMeters / 1000).toStringAsFixed(1)} km'),
      subtitle: Text(day.stopLabel, maxLines: 2, overflow: TextOverflow.ellipsis),
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
    currentIndex: 0,
    onDestinationSelected: (index) {
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
        Text('Nova cicloviagem', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Escolha cidades independentes da posição GPS. A busca online é acionada pela lupa.'),
        const SizedBox(height: 14),
        _cityField(origin: true),
        const SizedBox(height: 12),
        _cityField(origin: false),
        _searchResults(),
        const SizedBox(height: 10),
        _settings(),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : () => unawaited(_calculate()),
          icon: const Icon(Icons.route_rounded),
          label: Text(_busy ? 'Calculando rota…' : 'Calcular rotas para bicicleta'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) Padding(padding: const EdgeInsets.only(top: 8),
          child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_draft != null) _preview(_draft!),
        _librarySection(),
      ]),
    ))),
  );
}
