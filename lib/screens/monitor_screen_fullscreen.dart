part of 'monitor_screen.dart';

extension _MonitorFullscreen on _MonitorScreenState {
  Future<void> _toggleFullscreen() async {
    if (_fullscreenChanging) return;
    _fullscreenChanging = true;
    final entering = !_fullscreen;
    if (entering) {
      _fillBeforeFullscreen = _fillPreview;
    }
    _updateFullscreenState(() {
      _fullscreen = entering;
      _fillPreview = entering ? true : _fillBeforeFullscreen;
      _fullscreenControlsVisible = true;
      _editingZoneId = null;
    });
    try {
      if (entering) {
        // Ao vivo em tela inteira acompanha a rotacao do aparelho.
        await AppOrientationService.allowTransmissionRotation();
        if (mounted) await SystemUiService.immersive();
        _revealFullscreenControls();
      } else {
        _fullscreenControlsTimer?.cancel();
        await SystemUiService.edgeToEdge();
        await AppOrientationService.lockPortrait();
      }
    } finally {
      if (mounted) _updateFullscreenState(() => _fullscreenChanging = false);
    }
  }

  void _revealFullscreenControls() {
    if (!mounted || !_fullscreen) return;
    if (!_fullscreenControlsVisible) _updateFullscreenState(() => _fullscreenControlsVisible = true);
    _fullscreenControlsTimer?.cancel();
    _fullscreenControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _fullscreen) _updateFullscreenState(() => _fullscreenControlsVisible = false);
    });
  }

  Future<void> _showFullscreenRemoteControls() async {
    final url = _activeMcrpLiveUrl;
    if (url == null || !mounted) return;
    _fullscreenControlsTimer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.72,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text('Controles do transmissor',
                  style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 12),
              McrpLiveRemoteControls(liveUrl: url),
            ],
          ),
        ),
      ),
    );
    if (mounted && _fullscreen) _revealFullscreenControls();
  }

  Future<void> _fullscreenQuickCommand(String action) async {
    final url = _activeMcrpLiveUrl;
    if (url == null || !mounted || _fullscreenRemoteCommandBusy) return;
    _fullscreenRemoteCommandBusy = true;
    final client = McrpClient(McrpAddress.parse(url));
    try {
      var command = action;
      if (action == 'record/toggle') {
        final state = await client.status();
        command = state['x-recording'] == '1' ? 'record/stop' : 'record/start';
      }
      await client.command(command);
      if (!mounted) return;
      _revealFullscreenControls();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(
          command == 'photo' ? 'Foto solicitada ao transmissor.'
          : command == 'record/start' ? 'Gravação iniciada no transmissor.'
          : 'Gravação encerrada no transmissor.',
        )));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Comando remoto não confirmado. Verifique a conexão.'),
        ));
      }
    } finally {
      client.close();
      _fullscreenRemoteCommandBusy = false;
    }
  }

  Future<void> _changeMode() async {
    if (_fullscreen) await _toggleFullscreen();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LaunchModeScreen(manualReview: false),
      ),
      (_) => false,
    );
  }

  Future<void> _setMonitorMapVisibilityQuick(
    MonitorMapVisibilityMode mode,
  ) async {
    if (_mapRoute.monitorVisibility == mode &&
        (mode == MonitorMapVisibilityMode.hidden || _monitorMapActivated)) {
      return;
    }
    _miniMapReady = false;
    if (mode == MonitorMapVisibilityMode.hidden) _deactivateMonitorMap();
    await _mapRoute.setMonitorVisibility(mode);
    if (!mounted) return;
    if (mode != MonitorMapVisibilityMode.hidden) {
      await _activateMonitorMap();
      if (!mounted) return;
    }
    final message = switch (mode) {
      MonitorMapVisibilityMode.always =>
        'Mapa configurado para aparecer no monitor.',
      MonitorMapVisibilityMode.hidden =>
        'Mapa ocultado no monitor.',
      MonitorMapVisibilityMode.automatic =>
        'Mapa voltou para o modo automático.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _monitorMenu() {
    final mapMode = _mapRoute.monitorVisibility;
    final mapVisible = _shouldShowMonitorMap;
    return PopupMenuButton<String>(
      tooltip: 'Mais opções',
      onSelected: (value) {
        if (_fullscreenChanging) return;
        if (value == 'toggle_map') {
          unawaited(
            _setMonitorMapVisibilityQuick(
              mapVisible
                  ? MonitorMapVisibilityMode.hidden
                  : MonitorMapVisibilityMode.always,
            ),
          );
          return;
        }
        if (value == 'map_auto') {
          unawaited(
            _setMonitorMapVisibilityQuick(
              MonitorMapVisibilityMode.automatic,
            ),
          );
          return;
        }
        if (value == 'aux_person') {
          _controller.setPartialPersonHintsEnabled(
            !_controller.partialPersonHintsEnabled,
          );
          return;
        }
        if (value == 'mcrp') {
          unawaited(_showMcrpRemoteSheet());
          return;
        }
        if (value == 'lan') {
          unawaited(_showLanAccess());
          return;
        }
        if (value == 'events') {
          unawaited(_openStandardScreen(const EventsScreen()));
          return;
        }
        if (value == 'settings') {
          unawaited(_openStandardScreen(const SettingsScreen()));
          return;
        }
        if (value == 'mode') {
          unawaited(_changeMode());
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'toggle_map',
          child: Text(mapVisible ? 'Ocultar mapa' : 'Mostrar mapa'),
        ),
        if (mapMode != MonitorMapVisibilityMode.automatic)
          const PopupMenuItem(
            value: 'map_auto',
            child: Text('Mapa automático'),
          ),
        CheckedPopupMenuItem<String>(
          value: 'aux_person',
          checked: _controller.partialPersonHintsEnabled,
          child: const Text('Possivel pessoa (experimental)'),
        ),
        const PopupMenuDivider(),
        if (_activeMcrpLiveUrl != null)
          const PopupMenuItem(value: 'mcrp', child: Text('Controle remoto da câmera')),
        const PopupMenuItem(value: 'lan', child: Text('Rede local')),
        const PopupMenuItem(value: 'events', child: Text('Eventos')),
        const PopupMenuItem(
          value: 'settings',
          child: Text('Configurações'),
        ),
        const PopupMenuItem(value: 'mode', child: Text('Alterar modo')),
      ],
    );
  }

  Widget _voiceButton() => IconButton(
    tooltip: _controller.voiceEnabled ? 'Desativar voz' : 'Ativar voz',
    onPressed: () => _controller.setVoiceEnabled(!_controller.voiceEnabled),
    icon: Icon(_controller.voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded),
  );

  Widget _buildFullscreen(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _revealFullscreenControls(),
    child: Stack(fit: StackFit.expand, children: [
      Theme(
        data: ThemeData.dark(useMaterial3: true),
        child: _buildAdaptiveCameraStage(context),
      ),
      if (_fullscreenControlsVisible && _activeMcrpLiveUrl != null)
        Positioned(
          left: 12,
          right: 12,
          bottom: 82,
          child: Center(child: Material(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(24),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton.icon(
                onPressed: _fullscreenRemoteCommandBusy
                    ? null : () => unawaited(_fullscreenQuickCommand('photo')),
                icon: const Icon(Icons.photo_camera_outlined, color: Colors.white),
                label: const Text('Foto', style: TextStyle(color: Colors.white)),
              ),
              TextButton.icon(
                onPressed: _fullscreenRemoteCommandBusy
                    ? null : () => unawaited(_fullscreenQuickCommand('record/toggle')),
                icon: const Icon(Icons.fiber_manual_record, color: Color(0xFFFF7979)),
                label: const Text('REC', style: TextStyle(color: Colors.white)),
              ),
            ]),
          )),
        ),
      if (_fullscreenControlsVisible)
        Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(
          top: false,
          minimum: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            child: Theme(
              data: ThemeData.dark(useMaterial3: true),
              child: Row(children: [
              IconButton(
                tooltip: 'Sair do monitoramento',
                onPressed: () => unawaited(_closeMonitor()),
                icon: const Icon(Icons.close_rounded),
              ),
              IconButton(
                tooltip: 'Sair da tela inteira',
                onPressed: _fullscreenChanging ? null : () => unawaited(_toggleFullscreen()),
                icon: const Icon(Icons.fullscreen_exit_rounded),
              ),
              Expanded(child: Text('Detectados $_currentDetectionCount',
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(
                tooltip: _fillPreview ? 'Ajustar: mostrar imagem completa' : 'Preencher: ocupar a tela',
                onPressed: () => _updateFullscreenState(() => _fillPreview = !_fillPreview),
                icon: Icon(_fillPreview ? Icons.fit_screen_rounded : Icons.crop_free_rounded),
              ),
              if (_activeMcrpLiveUrl != null)
                IconButton(
                  tooltip: 'Controles do transmissor',
                  onPressed: () => unawaited(_showFullscreenRemoteControls()),
                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                ),
              _voiceButton(),
              _monitorMenu(),
            ])),
          ),
        )),
    ]),
  );
}
