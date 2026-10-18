part of 'multi_camera_screen.dart';

extension _LanCameraDiscoveryActions on _MultiCameraScreenState {
  Future<void> _scanLocalNetwork() async {
    final discovered = <LanCameraCandidate>[];
    bool scanning = true;
    StateSetter? updateDialog;
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
              width: 480,
              height: 320,
              child: Column(children: [
                if (scanning) const LinearProgressIndicator(),
                const SizedBox(height: 10),
                Text(scanning
                    ? 'Procurando transmissores Vigia IA e cameras ONVIF na rede local…'
                    : discovered.isEmpty
                        ? 'Nenhum anuncio recebido. Confirme que ambos estao na mesma rede. Use QR ou cadastro RTSP manual.'
                        : 'Selecione um dispositivo para configurar.',
                  style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Expanded(child: ListView.builder(
                  itemCount: discovered.length,
                  itemBuilder: (_, i) {
                    final candidate = discovered[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(candidate.kind == LanCameraKind.vigiaIa
                            ? Icons.phone_android_rounded : Icons.videocam_rounded),
                        title: Text(candidate.name),
                        subtitle: Text(candidate.kind == LanCameraKind.vigiaIa
                            ? '${candidate.host} · exige pareamento por QR'
                            : '${candidate.host} · ONVIF encontrado; RTSP nao verificado'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(dialogContext, candidate),
                      ),
                    );
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
    // A varredura nao escuta a rede permanentemente e nao descobre segredos.
    unawaited(LanCameraDiscoveryService.discover(
      onFound: (candidate) {
        discovered.add(candidate);
        if (mounted && updateDialog != null) {
          updateDialog!(() {});
        }
      },
    ).catchError((Object _) => <LanCameraCandidate>[]).then((_) {
      scanning = false;
      if (mounted && updateDialog != null) updateDialog!(() {});
    }));
    final selected = await selectedFuture;
    updateDialog = null;
    if (!mounted || selected == null) return;
    if (selected.kind == LanCameraKind.vigiaIa) {
      final shouldScanQr = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(selected.name),
          content: const Text(
            'Vigia IA encontrado na rede. Por seguranca, a descoberta nao '
            'compartilha chaves de controle. Abra o QR no transmissor e '
            'escaneie para autorizar o pareamento.'),
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
    final candidate = await _showCameraEditor(
      type: CameraEndpointType.rtsp,
      initialName: selected.name,
      // Endereco base de sugestao: usuario precisa confirmar path de stream.
      initialAddress: 'rtsp://${selected.host}:554/',
    );
    if (candidate == null) return;
    await _registry.save(candidate);
    if (mounted) _updateMonitoringState(() {});
    await _refreshStatuses();
  }

}
