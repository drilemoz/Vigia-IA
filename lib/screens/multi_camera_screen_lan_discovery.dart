part of 'multi_camera_screen.dart';

extension _LanCameraDiscoveryActions on _MultiCameraScreenState {
  Future<void> _scanLocalNetwork() async {
    final discovered = <LanCameraCandidate>[];
    final cancel = LanScanCancelToken();
    bool scanning = true;
    String status = 'Identificando a rede Wi-Fi…';
    int checked = 0;
    int total = 0;
    String gateway = '';
    StateSetter? updateDialog;

    int priority(LanCameraCandidate candidate) => switch (candidate.kind) {
      LanCameraKind.vigiaIa => 4,
      LanCameraKind.onvif => 3,
      LanCameraKind.rtsp => 2,
      LanCameraKind.network => 1,
    };
    void refresh() {
      if (!cancel.cancelled && mounted && updateDialog != null) {
        updateDialog!(() {});
      }
    }
    void addCandidate(LanCameraCandidate candidate) {
      if (cancel.cancelled) return;
      // Um único item por IPv4. ONVIF / Vigia IA prevalece sobre TCP genérico.
      final index = discovered.indexWhere((old) => old.host == candidate.host);
      if (index < 0) {
        if (discovered.length < 64) discovered.add(candidate);
      } else if (priority(candidate) > priority(discovered[index])) {
        discovered[index] = candidate;
      }
      discovered.sort((a, b) => a.host.compareTo(b.host));
      refresh();
    }

    final selectedFuture = showDialog<LanCameraCandidate>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          updateDialog = update;
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            title: const Row(children: [
              Icon(Icons.radar_rounded),
              SizedBox(width: 10),
              Expanded(child: Text('Escanear rede')),
            ]),
            content: SizedBox(
              width: 500,
              height: 360,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (scanning) const LinearProgressIndicator(),
                const SizedBox(height: 10),
                Text(status, style: Theme.of(context).textTheme.bodySmall),
                if (total > 0 && scanning)
                  Text('Verificados: $checked/$total endereços',
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 12),
                Expanded(child: discovered.isEmpty
                  ? Center(child: Text(scanning
                      ? 'Buscando anúncios ONVIF, transmissores Vigia IA e portas RTSP…'
                      : 'Nenhum dispositivo detectado. Confira Wi-Fi, isolamento entre clientes e permissões; use QR ou RTSP manual.',
                    textAlign: TextAlign.center))
                  : ListView.builder(
                    itemCount: discovered.length,
                    itemBuilder: (_, i) {
                      final candidate = discovered[i];
                      final vigia = candidate.kind == LanCameraKind.vigiaIa;
                      final possibleVigia = candidate.port == 8765;
                      final router = gateway.isNotEmpty && candidate.host == gateway;
                      final onvif = candidate.kind == LanCameraKind.onvif;
                      final rtsp = candidate.kind == LanCameraKind.rtsp;
                      return Card(child: ListTile(
                        leading: Icon(vigia || possibleVigia ? Icons.phone_android_rounded
                            : router ? Icons.router_rounded
                            : onvif || rtsp ? Icons.videocam_rounded : Icons.devices_other_rounded),
                        title: Text(router && !vigia && !rtsp && !onvif
                            ? 'Roteador da rede · ${candidate.host}' : candidate.name),
                        subtitle: Text(vigia || possibleVigia
                            ? '${candidate.host} · pareamento via QR necessário'
                            : onvif
                              ? '${candidate.host} · ONVIF encontrado; RTSP não verificado'
                              : '${candidate.host}:${candidate.port} · ${candidate.protocol ?? 'Serviço detectado'}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(dialogContext, candidate),
                      ));
                    },
                  )),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Fechar')),
            ],
          );
        },
      ),
    );

    unawaited(() async {
      try {
        final permission = await _native.localNetworkPermissionStatus();
        if (permission.required && !permission.granted) {
          status = 'Solicitando permissão para acessar a rede local…';
          refresh();
          final allowed = await _native.requestLocalNetworkPermission();
          if (!allowed) {
            status = 'Permissão de rede local não concedida. Habilite o acesso nas configurações Android.';
            return;
          }
        }
        final range = await LanCameraSubnetScanner.localRange();
        if (cancel.cancelled) return;
        total = range.hosts.length;
        gateway = range.gateway;
        status = range.warning ?? 'Rede ${range.description}: procurando serviços locais';
        refresh();
        await LanCameraSubnetScanner.multicast(true);
        try {
          await Future.wait(<Future<void>>[
            LanCameraDiscoveryService.discover(
              timeout: const Duration(seconds: 6),
              targetBroadcasts: range.broadcast.isEmpty ? null : [range.broadcast],
              cancelled: () => cancel.cancelled,
              onFound: addCandidate,
            ).then((_) {}),
            LanCameraSubnetScanner.scan(
              range: range,
              cancel: cancel,
              onFound: addCandidate,
              onProgress: (value, count) {
                checked = value;
                total = count;
                refresh();
              },
            ),
          ]);
        } finally {
          await LanCameraSubnetScanner.multicast(false);
        }
        if (!cancel.cancelled) {
          status = discovered.isEmpty
              ? 'Busca concluída: nenhum dispositivo respondeu na rede ${range.description}.'
              : 'Busca concluída: ${discovered.length} dispositivos encontrados.';
        }
      } catch (error) {
        if (!cancel.cancelled) status = 'Não foi possível escanear: $error';
      } finally {
        scanning = false;
        refresh();
      }
    }());

    final selected = await selectedFuture;
    cancel.cancel();
    updateDialog = null;
    if (!mounted || selected == null) return;
    if (selected.kind == LanCameraKind.vigiaIa || selected.port == 8765) {
      final shouldScanQr = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(selected.name),
          content: Text(selected.kind == LanCameraKind.vigiaIa
              ? 'Transmissor Vigia IA anunciado na rede. Abra o QR no transmissor para parear com segurança.'
              : 'Porta 8765 aberta: pode ser um transmissor Vigia IA, mas a identidade ainda não foi comprovada. Confira o serviço no outro aparelho e escaneie o QR para autorizar.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Escanear QR')),
          ],
        ),
      );
      if (shouldScanQr == true && mounted) await _scanPhoneQr();
      return;
    }
    if (selected.kind == LanCameraKind.network && gateway.isNotEmpty && selected.host == gateway) {
      final proceed = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gateway da rede'),
          content: const Text('Este IP é o roteador/gateway detectado pelo Android. Uma porta HTTP aberta não comprova a presença de câmera RTSP. Quer tentar cadastrar uma URL RTSP manualmente?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
          ],
        ));
      if (proceed != true || !mounted) return;
    }
    final port = selected.kind == LanCameraKind.rtsp ? selected.port ?? 554 : 554;
    final candidate = await _showCameraEditor(
      type: CameraEndpointType.rtsp,
      initialName: selected.kind == LanCameraKind.network
          ? 'Câmera ${selected.host}' : selected.name,
      // Nunca pressupor que OPTIONS encontrou o caminho real do stream.
      initialAddress: 'rtsp://${selected.host}:$port/',
    );
    if (candidate == null) return;
    await _registry.save(candidate);
    if (mounted) _updateMonitoringState(() {});
    await _refreshStatuses();
  }
}
