part of 'monitor_screen.dart';

/// O controle remoto MCRP é opcional e só aparece para uma fonte Minha Câmera
/// válida. Nenhum comando será enviado às fontes RTSP/ESP32/vigiaia://pair.
extension _MonitorMcrpSupport on _MonitorScreenState {
  Widget _buildMcrpRecordingStrip(BuildContext context) {
    final url = _activeMcrpLiveUrl;
    if (url == null) return const SizedBox.shrink();
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: McrpLiveStatusCache.status,
      builder: (context, data, _) {
        if (McrpLiveStatusCache.liveUrl != url || data.isEmpty ||
            data['x-link-unavailable'] == '1') {
          return const Padding(
            padding: EdgeInsets.fromLTRB(14, 7, 14, 2),
            child: Text('Transmissão: aguardando status do transmissor',
              style: TextStyle(fontSize: 11)),
          );
        }
        final live = data['x-transmitting'] == '1';
        final paused = data['x-transmitting'] == '0';
        final rec = data['x-recording'] == '1';
        final transmissionTime = data['x-transmission-seconds'];
        final recordingTime = data['x-recording-seconds'];
        final status = paused ? 'PAUSADO' : live ? 'AO VIVO' : 'ESTADO DESCONHECIDO';
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 3),
          child: Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(paused ? Icons.pause_circle_outline : Icons.sensors_rounded,
                  size: 15, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 5),
                Text(status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                if (live && transmissionTime != null) Text(
                  ' · ${McrpLiveStatusCache.duration(transmissionTime)}',
                  style: const TextStyle(fontSize: 11)),
              ]),
              if (rec)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.fiber_manual_record, size: 13, color: Colors.red),
                  const SizedBox(width: 5),
                  Text(recordingTime == null ? 'REC em andamento'
                      : 'REC ${McrpLiveStatusCache.duration(recordingTime)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
            ],
          ),
        );
      },
    );
  }

  String? get _activeMcrpLiveUrl {
    final source = _controller.sourceConfig;
    if (source.type != VideoSourceType.remotePhone) return null;
    final url = source.remoteBaseUrl;
    if (!MinhaCameraLiveUrl.isValid(url)) return null;
    try {
      McrpAddress.parse(url!);
      return url;
    } on FormatException {
      return null;
    }
  }

  Widget _buildPortraitRemoteControls(BuildContext context) {
    final url = _activeMcrpLiveUrl;
    if (url == null || _primaryContentMode != _MonitorPrimaryContentMode.camera) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
      child: McrpLiveRemoteControls(
        liveUrl: url,
        partialPersonEnabled: _controller.partialPersonHintsEnabled,
        onTogglePartialPerson: () => _controller.setPartialPersonHintsEnabled(
          !_controller.partialPersonHintsEnabled,
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showMcrpRemoteSheet() async {
    final url = _activeMcrpLiveUrl;
    if (url == null) return;
    if (_fullscreen) await _toggleFullscreen();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          McrpLiveRemoteControls(
        liveUrl: url,
        partialPersonEnabled: _controller.partialPersonHintsEnabled,
        onTogglePartialPerson: () => _controller.setPartialPersonHintsEnabled(
          !_controller.partialPersonHintsEnabled,
        ),
      ),
        ]),
      ),
    );
  }
}
