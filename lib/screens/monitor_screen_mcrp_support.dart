part of 'monitor_screen.dart';

/// O controle remoto MCRP é opcional e só aparece para uma fonte Minha Câmera
/// válida. Nenhum comando será enviado às fontes RTSP/ESP32/vigiaia://pair.
extension _MonitorMcrpSupport on _MonitorScreenState {
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
