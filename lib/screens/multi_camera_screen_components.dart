part of 'multi_camera_screen.dart';

class _CentralHeader extends StatelessWidget {
  const _CentralHeader({
    required this.total,
    required this.online,
    required this.disabled,
    required this.lastRefresh,
    required this.onScanPhone,
    required this.onScanNetwork,
    required this.onAddPhone,
    required this.onAddRtsp,
    required this.onManageEsp32,
  });

  final int total;
  final int online;
  final int disabled;
  final DateTime? lastRefresh;
  final VoidCallback onScanPhone;
  final VoidCallback onScanNetwork;
  final VoidCallback onAddPhone;
  final VoidCallback onAddRtsp;
  final VoidCallback onManageEsp32;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _MetricChip(icon: Icons.videocam_outlined, label: '$total câmeras'),
                      _MetricChip(icon: Icons.wifi_rounded, label: '$online online'),
                      if (disabled > 0)
                        _MetricChip(
                          icon: Icons.pause_circle_outline_rounded,
                          label: '$disabled desativadas',
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sobre as câmeras e a contagem',
                  icon: const Icon(Icons.help_outline_rounded),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Sobre as câmeras'),
                      content: const Text(
                        'Cada câmera é independente. Adicionar outra câmera não ativa contador. '
                        'Uma futura contagem poderá ser habilitada por câmera, separadamente.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Entendi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              lastRefresh == null
                  ? 'Verificando disponibilidade…'
                  : 'Status automático a cada 15 s · atualizado ${_formatTime(lastRefresh!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(
              'Adicionar fonte',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _SourceAction(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'QR',
                    tooltip: 'Adicionar câmera por QR',
                    onPressed: onScanPhone,
                    primary: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SourceAction(
                    icon: Icons.phone_android_rounded,
                    label: 'Celular',
                    tooltip: 'Cadastrar câmera de outro celular',
                    onPressed: onAddPhone,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SourceAction(
                    icon: Icons.router_outlined,
                    label: 'RTSP',
                    tooltip: 'Adicionar câmera RTSP',
                    onPressed: onAddRtsp,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SourceAction(
                    icon: Icons.memory_rounded,
                    label: 'ESP32',
                    tooltip: 'Configurar câmera e sensores ESP32',
                    onPressed: onManageEsp32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onScanNetwork,
              icon: const Icon(Icons.radar_rounded),
              label: const Text('Escanear rede Wi-Fi'),
            ),
          ],
        ),
      ),
    );
  }
}


class _SourceAction extends StatelessWidget {
  const _SourceAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
    final style = primary
        ? FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            minimumSize: const Size(0, 58),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          )
        : OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            minimumSize: const Size(0, 58),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          );
    return Tooltip(
      message: tooltip,
      child: primary
          ? FilledButton(onPressed: onPressed, style: style, child: content)
          : OutlinedButton(onPressed: onPressed, style: style, child: content),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.camera,
    required this.cameraAvailable,
    required this.status,
    required this.lastEvent,
    required this.onOpen,
    required this.onOpenWithSecond,
    required this.onMcrpControls,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final CameraEndpoint camera;
  final bool cameraAvailable;
  final CameraProbeResult? status;
  final MonitorEvent? lastEvent;
  final VoidCallback onOpen;
  final VoidCallback? onOpenWithSecond;
  final VoidCallback? onMcrpControls;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = camera.enabled && (status?.online ?? false);
    final statusColor = !camera.enabled
        ? scheme.outline
        : online
            ? const Color(0xFF4ADE80)
            : status == null
                ? scheme.primary
                : scheme.error;
    final statusText = !camera.enabled
        ? 'Desativada'
        : status == null
            ? 'Verificando…'
            : online
                ? 'Online'
                : 'Offline';
    final latency = status?.latency;
    final remoteStatus = status?.remoteStatus;
    final sourceKind = switch (camera.type) {
      CameraEndpointType.local => 'Local',
      CameraEndpointType.rtsp => 'RTSP',
      CameraEndpointType.remotePhone =>
          'Câmera remota',
      CameraEndpointType.esp32 => 'ESP32',
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    switch (camera.type) {
                      CameraEndpointType.local => Icons.camera_alt_outlined,
                      CameraEndpointType.rtsp => Icons.router_outlined,
                      CameraEndpointType.remotePhone => Icons.phone_android_rounded,
                      CameraEndpointType.esp32 => Icons.memory_rounded,
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              online && latency != null
                                  ? '$sourceKind · $statusText · ${latency.inMilliseconds} ms'
                                  : '$sourceKind · $statusText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: camera.enabled && cameraAvailable ? onOpen : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  label: const Text(
                    'Monitorar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                if (onMcrpControls != null ||
                    onOpenWithSecond != null ||
                    onEdit != null ||
                    onToggle != null ||
                    onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: 'Opções da câmera',
                    onSelected: (value) {
                      if (value == 'controls') onMcrpControls?.call();
                      if (value == 'second') onOpenWithSecond?.call();
                      if (value == 'edit') onEdit?.call();
                      if (value == 'toggle') onToggle?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      if (onMcrpControls != null)
                        const PopupMenuItem(
                          value: 'controls',
                          child: Text('Controles e arquivos'),
                        ),
                      if (onOpenWithSecond != null)
                        const PopupMenuItem(
                          value: 'second',
                          child: Text('Duas câmeras'),
                        ),
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar / renomear'),
                        ),
                      if (onToggle != null)
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(camera.enabled ? 'Desativar' : 'Ativar'),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Remover'),
                        ),
                    ],
                  ),
              ],
            ),
            if (camera.type != CameraEndpointType.local) ...[
              const SizedBox(height: 7),
              _CameraDetails(
                camera: camera,
                cameraAvailable: cameraAvailable,
                status: status,
                remoteStatus: remoteStatus,
              ),
            ],
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: lastEvent == null
                  ? const Text('Último evento: nenhum registrado')
                  : Text(
                      'Último: ${lastEvent!.displayLabel.startsWith('Possível') ? lastEvent!.displayLabel : ObjectFilterCatalog.displayNameForLabel(lastEvent!.label) ?? 'Detecção'} · ${_eventKind(lastEvent!.type)} · ${_formatDateTime(lastEvent!.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _eventKind(MonitorEventType type) => switch (type) {
      MonitorEventType.alert => 'alerta',
      MonitorEventType.entered => 'entrada',
      MonitorEventType.exited => 'saída',
      MonitorEventType.cameraObstructed => 'câmera obstruída',
      MonitorEventType.cameraMoved => 'câmera deslocada',
    };

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
