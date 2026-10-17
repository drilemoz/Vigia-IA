part of 'session_status_panel.dart';

class _VideoSummaryCard extends StatelessWidget {
  const _VideoSummaryCard({required this.data, this.onTap});

  final SessionStatusData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap ??
            () {
              final size = MediaQuery.sizeOf(context);
              if (size.width >= 840) {
                showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(28),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 860,
                        maxHeight: size.height * 0.84,
                      ),
                      child: VideoSessionDetailsPanel(data: data),
                    ),
                  ),
                );
                return;
              }
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => FractionallySizedBox(
                  heightFactor: 0.78,
                  child: VideoSessionDetailsPanel(data: data),
                ),
              );
            },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.videocam_outlined,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.imageSource,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.compactVideoSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.photo_size_select_large_outlined,
                    label: data.analysisResolution,
                  ),
                  _InfoChip(
                    icon: Icons.speed_rounded,
                    label: '${data.analyzedFps.toStringAsFixed(1)} FPS IA',
                  ),
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: data.frameDelayMs == null
                        ? 'Atraso —'
                        : 'Atraso ${data.frameDelayMs} ms',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceSection extends StatelessWidget {
  const _DeviceSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.telemetry,
    required this.connectionFallback,
    this.unavailable = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final DeviceTelemetrySnapshot? telemetry;
  final String connectionFallback;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final device = telemetry;
    final connection = device?.connectionType?.trim().isNotEmpty == true
        ? device!.connectionType!
        : connectionFallback;
    final summaryChips = <Widget>[
      if (device?.batteryPercent != null)
        _DeviceSummaryChip(
          icon: Icons.battery_std_rounded,
          label: '${device!.batteryPercent}%',
        ),
      if (device?.batteryTemperatureC != null)
        _DeviceSummaryChip(
          icon: Icons.thermostat_rounded,
          label: '${device!.batteryTemperatureC!.toStringAsFixed(1)} °C',
        ),
      _DeviceSummaryChip(icon: Icons.wifi_rounded, label: connection),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (summaryChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: summaryChips),
          ],
          const SizedBox(height: 10),
          if (unavailable)
            const _MetricGroup(
              children: [
                _MetricRow(label: 'Estado', value: 'Não utilizado nesta sessão'),
              ],
            )
          else
            _MetricGroup(
              children: [
                _MetricRow(
                  label: 'Bateria',
                  value: device?.batteryPercent == null ? '—' : '${device!.batteryPercent}%',
                ),
                _MetricRow(
                  label: 'Carga',
                  value: _chargingText(device),
                  detail: device?.batteryCurrentMa == null
                      ? null
                      : '${device!.batteryCurrentMa!.toStringAsFixed(0)} mA',
                ),
                _MetricRow(
                  label: 'Temperatura',
                  value: device?.batteryTemperatureC == null
                      ? '—'
                      : '${device!.batteryTemperatureC!.toStringAsFixed(1)} °C',
                ),
                _MetricRow(
                  label: 'Brilho',
                  value: device?.screenBrightnessPercent == null
                      ? '—'
                      : '${device!.screenBrightnessPercent}%',
                  detail: device?.automaticBrightness == true ? 'Automático' : null,
                ),
                _MetricRow(
                  label: 'CPU do Vigia IA',
                  value: device?.appCpuPercent == null
                      ? 'Calculando…'
                      : '${device!.appCpuPercent!.toStringAsFixed(1)}%',
                  detail: device?.processorCount == null
                      ? null
                      : '${device!.processorCount} núcleos disponíveis',
                ),
                _MetricRow(
                  label: 'RAM do app',
                  value: device?.appMemoryUsedBytes == null
                      ? '—'
                      : StorageSizeFormatter.formatBytes(device!.appMemoryUsedBytes!),
                  detail: _ramDetail(device),
                ),
                _MetricRow(
                  label: 'Armazenamento livre',
                  value: device?.freeStorageBytes == null
                      ? '—'
                      : StorageSizeFormatter.formatBytes(device!.freeStorageBytes!),
                  detail: device?.totalStorageBytes == null
                      ? null
                      : 'de ${StorageSizeFormatter.formatBytes(device!.totalStorageBytes!)}',
                ),
                _MetricRow(label: 'Conexão', value: connection),
              ],
            ),
        ],
      ),
    );
  }

  static String _chargingText(DeviceTelemetrySnapshot? device) {
    final current = device;
    if (current?.batteryCharging == null) return '—';
    if (current!.batteryCharging != true) return 'Na bateria';
    return current.batteryPowerSource ?? 'Carregando';
  }

  static String? _ramDetail(DeviceTelemetrySnapshot? device) {
    final current = device;
    if (current?.memoryAvailableBytes == null ||
        current?.memoryTotalBytes == null) {
      return null;
    }
    return '${StorageSizeFormatter.formatBytes(current!.memoryAvailableBytes!)} livres de ${StorageSizeFormatter.formatBytes(current.memoryTotalBytes!)}';
  }
}

class _MetricGroup extends StatelessWidget {
  const _MetricGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.12),
                ),
            ],
          ],
        ),
      );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _metricIconForLabel(label),
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail!,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

class _SessionHealthCard extends StatelessWidget {
  const _SessionHealthCard({required this.data});

  final SessionStatusData data;

  @override
  Widget build(BuildContext context) {
    final health = data.health;
    final color = _healthColor(context, health.state);
    final primaryIssue = health.primaryIssue;
    final displayedIssues = <SessionHealthIssue>[
      ?primaryIssue,
      ...health.issues.where((issue) => !identical(issue, primaryIssue)).take(2),
    ];
    final incidents = data.healthIncidents.take(4).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_healthIcon(health.state), size: 20, color: color),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Saúde da sessão',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                health.state.label,
                style: TextStyle(fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(health.summary, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: _healthIcon(health.state), label: health.state.label),
              _InfoChip(icon: Icons.insights_rounded, label: health.bottleneck.label),
            ],
          ),
          if (displayedIssues.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final issue in displayedIssues)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: _healthColor(context, issue.state),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${issue.title}: ${issue.detail}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (incidents.isNotEmpty) ...[
            Divider(
              height: 18,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
            ),
            Text(
              'Ocorrências recentes',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            for (final incident in incidents)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_clockText(incident.occurredAt)} • ${incident.title}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final SessionHealthState state;

  @override
  Widget build(BuildContext context) {
    final color = _healthColor(context, state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _DeviceSummaryChip extends StatelessWidget {
  const _DeviceSummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

Color _healthColor(BuildContext context, SessionHealthState state) => switch (state) {
      SessionHealthState.healthy => Colors.green,
      SessionHealthState.attention => Colors.amber.shade800,
      SessionHealthState.unstable => Colors.deepOrange,
      SessionHealthState.disconnected => Theme.of(context).colorScheme.error,
    };

IconData _healthIcon(SessionHealthState state) => switch (state) {
      SessionHealthState.healthy => Icons.check_circle_outline_rounded,
      SessionHealthState.attention => Icons.warning_amber_rounded,
      SessionHealthState.unstable => Icons.sync_problem,
      SessionHealthState.disconnected => Icons.link_off,
    };

IconData _metricIconForLabel(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('bateria')) return Icons.battery_std_rounded;
  if (normalized.contains('carga')) return Icons.bolt_rounded;
  if (normalized.contains('temperatura')) return Icons.thermostat_rounded;
  if (normalized.contains('brilho')) return Icons.brightness_6_rounded;
  if (normalized.contains('cpu')) return Icons.memory_rounded;
  if (normalized.contains('ram') || normalized.contains('memória')) {
    return Icons.developer_board_rounded;
  }
  if (normalized.contains('armazenamento')) return Icons.sd_storage_rounded;
  if (normalized.contains('conexão')) return Icons.wifi_rounded;
  if (normalized.contains('fps')) return Icons.speed_rounded;
  if (normalized.contains('resolução')) {
    return Icons.photo_size_select_large_outlined;
  }
  if (normalized.contains('atraso') ||
      normalized.contains('latência') ||
      normalized.contains('idade')) {
    return Icons.schedule_rounded;
  }
  if (normalized.contains('inferência') ||
      normalized.contains('processamento') ||
      normalized.contains('detector')) {
    return Icons.psychology_alt_outlined;
  }
  if (normalized.contains('fonte') || normalized.contains('imagem')) {
    return Icons.videocam_outlined;
  }
  if (normalized.contains('quadros') || normalized.contains('frames')) {
    return Icons.filter_frames_rounded;
  }
  return Icons.info_outline_rounded;
}

String _millisecondsText(double? milliseconds) {
  if (milliseconds == null) return '—';
  if (milliseconds < 10) return '${milliseconds.toStringAsFixed(1)} ms';
  return '${milliseconds.toStringAsFixed(0)} ms';
}

String _budgetHeadroomText(double? headroomMs) {
  if (headroomMs == null) return 'Sem medição suficiente ainda.';
  if (headroomMs >= 0) {
    return '${_millisecondsText(headroomMs)} de folga antes do próximo intervalo.';
  }
  return '${_millisecondsText(headroomMs.abs())} acima do intervalo configurado.';
}

String _durationText(int? milliseconds) {
  if (milliseconds == null) return '—';
  if (milliseconds < 1000) return '$milliseconds ms';
  final seconds = milliseconds / 1000;
  return '${seconds.toStringAsFixed(seconds >= 10 ? 0 : 1)} s';
}

String _clockText(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
