#!/usr/bin/env python3
"""Contratos de UX da 1.0.220. Não substitui testes Flutter no aparelho."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
read = lambda path: (root / path).read_text(encoding='utf-8')
key = read('lib/widgets/offline_map_manager_sheet.dart')
mapui = read('lib/screens/map_monitoring_screen.dart')
editor = read('lib/screens/trip_planning_screen.dart')
preview = read('lib/widgets/map_route_preview_card.dart')
schedule = read('lib/services/bike_trip_schedule.dart')
tests = read('test/bike_trip_schedule_test.dart')
checks = {
    'stadia só revela a chave por solicitação explícita':
        key.count('await _service.revealStadiaApiKey()') == 2 and
        key.index('Future<void> _configureStadiaKey() async') < key.index('tooltip: \'Revelar chave\'')
        if 'tooltip: \'Revelar chave\'' in key else 'visibleSavedKey == null' in key,
    'remover a chave requer confirmação':
        'Remover chave Stadia Maps?' in key and 'confirmed != true' in key,
    'o gerenciador reduz quando não há pacotes':
        'heightFactor: hasPackages || service.busy || height < 740' in key and
        'Nenhum mapa offline baixado' in key,
    'almoço manual é respeitado no cálculo':
        'bool forceLunch = false' in schedule and
        'forceLunch: trip.forceLunch' in editor and
        "_choice('Almoço'" in editor and
        'almoço manual é aplicado mesmo em trajetos curtos' in tests,
    'ajustes do plano não bloqueiam a lista de dias':
        'TripPlanningScreen(' in mapui and
        "title: const Text('Almoço automático')" in editor and
        'BikeTripSchedule.forDay(' in editor and
        'Widget _dayCard(' in editor,
    'prévia de rota pode ser recolhida':
        'bool _previewCollapsed = false;' in mapui and
        'onToggleCollapsed:' in mapui and 'onPressed: onToggleCollapsed' in preview and 'Ver trajeto' in preview and 'Salvar offline' in preview,
    'seletor único por abas e com confirmação':
        'MapLayerPickerPanel(' in mapui and
        'showMapCenteredDialog<MapLayerPickerSelection>' in mapui and
        'class _MapStyleThumbnailPainter' in mapui and
        "ValueKey('layer-tab-" in read('lib/widgets/map_layer_picker_panel.dart'),
}
for label, passed in checks.items():
    if not passed:
        raise SystemExit(f'UX 1.0.220: FALHA: {label}')
print('Contratos da interface 1.0.220: OK')
