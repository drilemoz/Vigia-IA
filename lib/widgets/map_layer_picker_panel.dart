import 'package:flutter/material.dart';

import '../services/map_view_settings_service.dart';

/// Seleção local do painel: só é persistida depois de tocar em OK.
class MapLayerPickerSelection {
  const MapLayerPickerSelection({
    required this.appearancePreset,
    required this.appearanceMode,
    required this.provider,
    required this.stylePreset,
  });

  final MapAppearancePreset appearancePreset;
  final MapAppearanceMode appearanceMode;
  final MapProvider provider;
  final MapStylePreset stylePreset;
}

enum _LayerPickerTab { appearance, provider, base }

/// Seletor compacto, sem atalhos de API: chaves pertencem a Configurações.
class MapLayerPickerPanel extends StatefulWidget {
  const MapLayerPickerPanel({
    super.key,
    required this.initial,
    required this.googleSdkConfigured,
    required this.googleOnlineAvailable,
    required this.stadiaConfigured,
    required this.onConfirm,
    required this.onCancel,
    this.styleThumbnailBuilder,
  });

  final MapLayerPickerSelection initial;
  final bool googleSdkConfigured;
  /// Google pode renderizar tiles online neste momento; offline usa o mapa atual.
  final bool googleOnlineAvailable;
  final bool stadiaConfigured;
  final ValueChanged<MapLayerPickerSelection> onConfirm;
  final VoidCallback onCancel;
  final Widget Function(MapStylePreset)? styleThumbnailBuilder;

  @override
  State<MapLayerPickerPanel> createState() => _MapLayerPickerPanelState();
}

class _MapLayerPickerPanelState extends State<MapLayerPickerPanel> {
  _LayerPickerTab _tab = _LayerPickerTab.appearance;
  late MapAppearancePreset _appearancePreset;
  late MapAppearanceMode _appearanceMode;
  late MapProvider _provider;
  late MapStylePreset _stylePreset;

  @override
  void initState() {
    super.initState();
    _appearancePreset = widget.initial.appearancePreset;
    _appearanceMode = widget.initial.appearanceMode;
    _provider = widget.initial.provider;
    _stylePreset = widget.initial.stylePreset;
    if (!_styleAllowed(_stylePreset)) {
      // Uma credencial removida não deve bloquear a alteração do tema.
      _stylePreset = MapStylePreset.topographic;
    }
  }

  String get _appearanceLabel => switch (_appearanceMode) {
        MapAppearanceMode.manual => _appearancePreset.label,
        MapAppearanceMode.followSystem => 'Sistema',
        MapAppearanceMode.dayNight => 'Dia/noite',
      };

  String get _selectedLabel => switch (_tab) {
        _LayerPickerTab.appearance => _appearanceLabel,
        _LayerPickerTab.provider => _provider.label,
        _LayerPickerTab.base => _stylePreset.label,
      };

  String get _selectedDescription => switch (_tab) {
        _LayerPickerTab.appearance => switch (_appearanceMode) {
            MapAppearanceMode.manual => _appearancePreset.description,
            MapAppearanceMode.followSystem =>
              'Acompanha o tema claro ou escuro do Android.',
            MapAppearanceMode.dayNight =>
              'Alterna pelo horário local, sem depender de internet.',
          },
        _LayerPickerTab.provider => _provider == MapProvider.google
            ? 'Usa o SDK Google Maps quando habilitado neste APK e há conexão.'
            : 'Mantém o mapa atual e o suporte a pacotes offline.',
        _LayerPickerTab.base => _stylePreset.description,
      };

  bool _styleAllowed(MapStylePreset style) =>
      (_provider == MapProvider.google && widget.googleOnlineAvailable) ||
      !style.needsStadiaKey ||
      widget.stadiaConfigured;

  void _selectProvider(MapProvider provider) {
    if (provider == MapProvider.google && !widget.googleSdkConfigured) return;
    setState(() {
      _provider = provider;
      if (!_styleAllowed(_stylePreset)) {
        // Evita persistir uma base indisponível ao voltar ao mapa atual.
        _stylePreset = MapStylePreset.topographic;
      }
    });
  }

  Widget _choice({
    required String keyName,
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    required IconData icon,
    Widget? leading,
    String? disabledExplanation,
  }) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return ListTile(
      key: ValueKey('layer-choice-$keyName'),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: selected,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.42),
      leading: leading ?? Icon(icon, size: 23),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
      subtitle: enabled || disabledExplanation == null
          ? null
          : Text(disabledExplanation, style: Theme.of(context).textTheme.bodySmall),
      trailing: Icon(
        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
        color: selected ? colors.primary : (enabled ? null : colors.outline),
      ),
      enabled: enabled,
      onTap: onTap,
    );
  }

  Widget _options() => switch (_tab) {
        _LayerPickerTab.appearance => Column(
            children: [
              for (final preset in MapAppearancePreset.values)
                _choice(
                  keyName: 'appearance-${preset.name}',
                  label: preset.label,
                  selected: _appearanceMode == MapAppearanceMode.manual &&
                      _appearancePreset == preset,
                  icon: switch (preset) {
                    MapAppearancePreset.standard => Icons.light_mode_outlined,
                    MapAppearancePreset.dark => Icons.dark_mode_outlined,
                    MapAppearancePreset.highContrast => Icons.contrast_rounded,
                    MapAppearancePreset.bikeTravel => Icons.directions_bike_rounded,
                  },
                  onTap: () => setState(() {
                    _appearancePreset = preset;
                    _appearanceMode = MapAppearanceMode.manual;
                  }),
                ),
              const Divider(height: 10),
              _choice(
                keyName: 'appearance-system',
                label: 'Sistema (automático)',
                selected: _appearanceMode == MapAppearanceMode.followSystem,
                icon: Icons.phone_android_rounded,
                onTap: () => setState(() =>
                    _appearanceMode = MapAppearanceMode.followSystem),
              ),
              _choice(
                keyName: 'appearance-day-night',
                label: 'Dia/noite (automático)',
                selected: _appearanceMode == MapAppearanceMode.dayNight,
                icon: Icons.brightness_6_outlined,
                onTap: () => setState(() =>
                    _appearanceMode = MapAppearanceMode.dayNight),
              ),
            ],
          ),
        _LayerPickerTab.provider => Column(
            children: [
              for (final provider in MapProvider.values)
                _choice(
                  keyName: 'provider-${provider.name}',
                  label: provider.label,
                  selected: _provider == provider,
                  icon: provider == MapProvider.google
                      ? Icons.public_rounded
                      : Icons.map_outlined,
                  disabledExplanation: provider == MapProvider.google &&
                          !widget.googleSdkConfigured
                      ? 'Indisponível: exige chave Google Maps incorporada ao APK.'
                      : null,
                  onTap: provider == MapProvider.google &&
                          !widget.googleSdkConfigured
                      ? null
                      : () => _selectProvider(provider),
                ),
            ],
          ),
        _LayerPickerTab.base => Column(
            children: [
              for (final style in MapStylePreset.values)
                _choice(
                  keyName: 'base-${style.name}',
                  label: style.label,
                  selected: _stylePreset == style,
                  icon: style == MapStylePreset.satellite
                      ? Icons.satellite_alt_outlined
                      : style == MapStylePreset.terrain
                          ? Icons.terrain_rounded
                          : style == MapStylePreset.topographic
                              ? Icons.landscape_outlined
                              : style == MapStylePreset.bikeTravel
                                  ? Icons.directions_bike_rounded
                                  : Icons.map_outlined,
                  leading: widget.styleThumbnailBuilder?.call(style),
                  disabledExplanation: !_styleAllowed(style)
                      ? 'Exige chave Stadia Maps para o mapa atual.'
                      : null,
                  onTap: _styleAllowed(style)
                      ? () => setState(() => _stylePreset = style)
                      : null,
                ),
            ],
          ),
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Visual do mapa',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  tooltip: 'Fechar sem aplicar',
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final tab in _LayerPickerTab.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        key: ValueKey('layer-tab-${tab.name}'),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(switch (tab) {
                            _LayerPickerTab.appearance => 'Aparência',
                            _LayerPickerTab.provider => 'Provedor',
                            _LayerPickerTab.base => 'Base',
                          }),
                        ),
                        selected: _tab == tab,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _tab = tab),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                key: ValueKey('layer-options-scroll-${_tab.name}'),
                child: _options(),
              ),
            ),
            const Divider(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selecionado: $_selectedLabel',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(_selectedDescription,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('layer-apply-button'),
                    onPressed: () => widget.onConfirm(
                      MapLayerPickerSelection(
                        appearancePreset: _appearancePreset,
                        appearanceMode: _appearanceMode,
                        provider: _provider,
                        stylePreset: _stylePreset,
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
