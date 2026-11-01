import 'package:flutter/material.dart';

import '../models/map_destination_search.dart';
import '../models/map_route_point.dart';
import '../models/offline_map_package.dart';
import '../models/offline_poi_package.dart';
import '../services/gemini_map_service.dart';
import '../services/map_destination_search_service.dart';
import 'api_services_setup_screen.dart';

/// Respostas da IA não criam pontos automaticamente: apenas consultas
/// verificadas via Nominatim/dados locais entram na lista selecionável.
class GeminiMapAssistantScreen extends StatefulWidget {
  const GeminiMapAssistantScreen({
    super.key,
    required this.current,
    required this.onlineAllowed,
    required this.offlineMaps,
    required this.offlinePoiPackages,
  });
  final MapRoutePoint current;
  final bool onlineAllowed;
  final List<OfflineMapPackage> offlineMaps;
  final List<OfflinePoiPackage> offlinePoiPackages;

  @override
  State<GeminiMapAssistantScreen> createState() => _GeminiMapAssistantScreenState();
}

class _GeminiMapAssistantScreenState extends State<GeminiMapAssistantScreen> {
  final _controller = TextEditingController();
  final _gemini = GeminiMapService.instance;
  final _search = MapDestinationSearchService.instance;
  GeminiMapSuggestion? _suggestion;
  List<MapDestinationSearchResult> _places = const [];
  String? _message;
  bool _loading = false;
  bool _configured = false;
  bool _showSettingsHint = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _gemini.status();
      if (mounted) setState(() { _configured = status.configured; _showSettingsHint = !status.configured; });
    } catch (_) {
      if (mounted) setState(() => _showSettingsHint = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces() async {
    if (_loading) return;
    if (!widget.onlineAllowed) {
      setState(() => _message = 'Gemini precisa de internet. Use a busca tradicional com dados offline.');
      return;
    }
    setState(() { _loading = true; _message = null; _places = const []; _suggestion = null; });
    try {
      final suggestion = await _gemini.interpret(_controller.text);
      await _search.searchSubmitted(
        query: suggestion.searchQuery,
        current: widget.current,
        onlineAllowed: true,
        offlineMaps: widget.offlineMaps,
        offlinePoiPackages: widget.offlinePoiPackages,
      );
      if (!mounted) return;
      setState(() {
        _suggestion = suggestion;
        _places = _search.results;
        _message = _places.isEmpty
            ? 'A IA sugeriu uma busca, mas nenhum local foi confirmado. Tente incluir cidade e estado.'
            : '${_places.length} local(is) encontrado(s) em fontes cartográficas. Confira antes de navegar.';
      });
    } on GeminiMapException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'Não foi possível concluir a busca assistida.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar com Gemini')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Descreva o local que procura', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('Ex.: “encontre campings em Lagoa da Prata, MG” ou “hospital em Piumhi, Minas Gerais”. A IA apenas prepara uma consulta; os locais listados vêm do mapa.'),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLength: 500,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchPlaces(),
          decoration: const InputDecoration(
            labelText: 'O que deseja encontrar?',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.auto_awesome_outlined),
          ),
        ),
        FilledButton.icon(
          onPressed: _loading || !_configured || !widget.onlineAllowed ? null : _searchPlaces,
          icon: const Icon(Icons.search_rounded),
          label: const Text('Buscar locais com IA'),
        ),
        if (_showSettingsHint)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key_rounded),
            title: const Text('Serviços e APIs'),
            subtitle: const Text('Abra Gemini na central para configurar a busca assistida.'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const ApiServicesSetupScreen()));
              if (mounted) await _loadStatus();
            },
          ),
        if (!widget.onlineAllowed) const Text('Modo offline: a pesquisa por IA está desativada.'),
        if (_loading) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        if (_suggestion != null) Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Consulta sugerida: ${_suggestion!.searchQuery}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_suggestion!.explanation),
          ]),
        )),
        if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_message!)),
        if (_places.isNotEmpty) ...[
          Text('Locais verificados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final place in _places)
            Card(child: ListTile(
              title: Text(place.title),
              subtitle: Text('${place.kind.label} · ${place.subtitle}', maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.place_outlined),
              onTap: () => Navigator.of(context).pop(place),
            )),
        ],
        const SizedBox(height: 12),
        const Text('⚠️ Confira localização, acesso, funcionamento e segurança antes de usar uma sugestão. Gemini não calcula rotas, não substitui o GPS e pode gerar interpretações incorretas. A busca normal do Vigia Maps permanece disponível.'),
      ]),
    );
  }
}
