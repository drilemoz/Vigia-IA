part of 'monitor_screen.dart';

extension _MonitorDetectionPanel on _MonitorScreenState {
  Widget _buildDetectionPanelBody(
    BuildContext context, {
    required bool compact,
    required bool showHeader,
    ScrollController? scrollController,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = _controller.aiEnabled;
    final tracked = enabled && _controller.trackingEnabled;
    final detections = enabled
        ? (tracked
            ? _controller.trackedDetections.map((item) => item.detection)
            : _controller.detections)
        : _controller.detections.take(0);
    final current = detections.toList(growable: false);
    final people = current
        .where((item) => ObjectFilterCatalog.people.contains(item.label))
        .length;
    final vehicles = current
        .where((item) => ObjectFilterCatalog.vehicles.contains(item.label))
        .length;
    final others = current.length - people - vehicles;
    final names = <String, int>{};
    for (final detection in current) {
      names.update(detection.displayLabel, (value) => value + 1,
          ifAbsent: () => 1);
    }
    final counterReady = enabled && _controller.trackingEnabled;
    final counting = _controller.vehicleCountingEnabled;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 12,
          compact ? 12 : 16, 22),
      children: [
        if (showHeader) ...[
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detecções ao vivo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    Text('Objetos visíveis neste instante',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              _CountBadge(count: current.length),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: _LiveDetectionMetric(
                icon: Icons.person_outline_rounded,
                label: 'Pessoas agora',
                count: enabled ? '$people' : '—',
                tint: scheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _LiveDetectionMetric(
                icon: Icons.directions_car_outlined,
                label: 'Veículos agora',
                count: enabled ? '$vehicles' : '—',
                tint: scheme.tertiary,
              ),
            ),
          ],
        ),
        if (others > 0) ...[
          const SizedBox(height: 5),
          Text('Outros objetos visíveis: $others',
              style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.alt_route_rounded, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Passagens de veículos',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        Text('Teste experimental · câmera fixa',
                            style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: counting,
                    onChanged: counterReady
                        ? _controller.setVehicleCountingEnabled
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(counting ? '${_controller.vehiclePassageCount}' : '—',
                      style: const TextStyle(fontSize: 28,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(counting
                        ? 'Passagens confirmadas nesta sessão'
                        : 'Contador desligado',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  if (counting)
                    TextButton.icon(
                      onPressed: _controller.resetVehiclePassageCount,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Zerar'),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                !counterReady
                    ? 'Ative IA e rastreamento para testar a contagem.'
                    : 'Conta carros, motos, ônibus e caminhões cruzando a linha vertical central. Com a câmera em movimento, o resultado não é confiável. Não é salvo ao fechar.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Monitoramento',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _RuntimeSummary(controller: _controller),
        if (!_controller.voiceLanguageInstalled &&
            !_controller.initializing) ...[
          const SizedBox(height: 8),
          const _InfoStrip(
            icon: Icons.volume_off_outlined,
            text: 'A voz do Android em pt-BR não está instalada. Os áudios integrados continuam disponíveis.',
          ),
        ],
        const SizedBox(height: 14),
        Text('Categorias visíveis',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (current.isEmpty && !_controller.initializing)
          _EmptyDetectionState(
            text: !enabled
                ? 'IA desativada.'
                : !_controller.scheduleActive
                    ? 'Pausado pela agenda. O monitor retomará no próximo horário.'
                    : _controller.motionOnly
                        ? 'Aguardando atividade relevante.'
                        : 'Nenhum objeto acima do limite de confiança.',
          )
        else
          for (final item in names.entries)
            _DetectionCard(label: '${item.key}  ·  ${item.value}'),
      ],
    );
  }
}

class _LiveDetectionMetric extends StatelessWidget {
  const _LiveDetectionMetric({
    required this.icon,
    required this.label,
    required this.count,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String count;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: tint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(count, style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
