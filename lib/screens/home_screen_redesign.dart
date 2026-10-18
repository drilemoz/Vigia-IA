part of 'home_screen.dart';

extension _HomeRedesign on _HomeScreenState {
  void _navigateMain(int index) {
    if (index == 0) return;
    if (index == 2) {
      unawaited(_startLocalCamera());
      return;
    }
    navigateToMainDestination(context, index, currentIndex: 0);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    if (mounted) await _loadSettings();
  }

  void _openScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _changeMode() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LaunchModeScreen(manualReview: false),
      ),
      (_) => false,
    );
  }

  List<Widget> _monitorConfiguration(int activeZones) {
    return [
      _buildSourcePanel(context),
      const SizedBox(height: 14),
      _PrivacyCard(sourceType: _sourceType),
      const SizedBox(height: 20),
      _SectionTitle(
        eyebrow: 'MONITORAMENTO',
        title: 'O que a IA deve observar',
        subtitle:
            'Os ajustes mais usados ficam aqui; parâmetros técnicos ficam em Ajustes → Avançado.',
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.filter_alt_outlined,
        title: 'Objetos monitorados',
        subtitle: objectFilterSummary(_alertLabels),
        badge: '${objectFilterGroupCount(_alertLabels)}/3',
        onTap: _configureObjectFilter,
      ),
      _ActionCard(
        icon: Icons.rule_outlined,
        title: 'Regras inteligentes',
        subtitle: smartAlertRulesSummary(_smartAlertRules),
        onTap: _configureSmartAlertRules,
      ),
      _ActionCard(
        icon: Icons.grid_view_rounded,
        title: 'Áreas de vigilância',
        subtitle: activeZones == 0
            ? 'Tela inteira. Áreas limitam onde a IA observa; elas não fazem contagem.'
            : '$activeZones ativa(s) de ${_monitoringZones.length}. Áreas limitam a região observada e não contam passagens.',
        badge: activeZones == 0 ? 'Tela toda' : '$activeZones',
      ),
      _ActionCard(
        icon: Icons.schedule_rounded,
        title: 'Agenda automática',
        subtitle: monitorScheduleSummary(_schedule),
        badge: _schedule.enabled ? 'Ativa' : 'Manual',
        onTap: _configureSchedule,
      ),
      const SizedBox(height: 14),
      const _SectionTitle(
        eyebrow: 'AUTOMAÇÃO',
        title: 'Recursos do monitor',
        subtitle: 'Ligue só o que fizer sentido para o seu cenário.',
      ),
      const SizedBox(height: 10),
      _FeatureGrid(
        motionOnly: _motionOnly,
        clipRecordingEnabled: _clipRecordingEnabled,
        trackingEnabled: _trackingEnabled,
        announceEntryExit: _trackingEnabled && _announceEntryExit,
        backgroundMonitoringEnabled: _backgroundMonitoringEnabled,
        voiceEnabled: _voiceEnabled,
        onMotionChanged: (value) {
          _updateHomeState(() => _motionOnly = value);
          _schedulePersist();
        },
        onClipChanged: (value) {
          _updateHomeState(() => _clipRecordingEnabled = value);
          _schedulePersist();
        },
        onTrackingChanged: (value) {
          _updateHomeState(() => _trackingEnabled = value);
          _schedulePersist();
        },
        onEntryExitChanged: _trackingEnabled
            ? (value) {
                _updateHomeState(() => _announceEntryExit = value);
                _schedulePersist();
              }
            : null,
        onBackgroundChanged: (value) {
          _updateHomeState(() => _backgroundMonitoringEnabled = value);
          _schedulePersist();
        },
        onVoiceChanged: (value) {
          _updateHomeState(() => _voiceEnabled = value);
          _schedulePersist();
        },
      ),
    ];
  }

  Widget _buildRedesignedHome(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeZones = _monitoringZones.where((zone) => zone.enabled).length;
    final sourceText = switch (_sourceType) {
      VideoSourceType.localCamera => 'Câmera celular',
      VideoSourceType.rtsp => 'Câmera RTSP',
      VideoSourceType.remotePhone => 'Celular remoto',
      VideoSourceType.esp32 => 'Câmera ESP32',
    };

    return AdaptiveMainScaffold(
      currentIndex: 0,
      onDestinationSelected: _navigateMain,
      appBar: _buildHomeAppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Manter a Home útil sem esticar cartões em aparelhos altos.
                // Se a altura for pequena, a rolagem continua disponível.
                final compactHeight = constraints.maxHeight < 570;
                final gap = compactHeight ? 12.0 : 18.0;
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const VigiaSectionHeading(
                              title: 'Modos',
                              subtitle: 'Escolha uma função para este aparelho.',
                            ),
                            const SizedBox(height: 10),
                            _buildModeCards(compactHeight: compactHeight),
                            SizedBox(height: gap),
                            VigiaSectionHeading(
                              title: 'Monitoramento atual',
                              subtitle: 'Operações e ajustes deste monitor.',
                              trailing: VigiaStatusPill(
                                label: _schedule.enabled ? 'Agendado' : 'Pronto',
                                icon: _schedule.enabled
                                    ? Icons.schedule_rounded
                                    : Icons.check_circle_outline_rounded,
                                color: VigiaColors.green,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildCompactMonitorCards(sourceText, activeZones),
                          ],
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, gap, 16, 18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildSystemStatusStrip(sourceText, activeZones),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusStrip(String sourceText, int activeZones) {
    final scheme = Theme.of(context).colorScheme;
    final aiDescription = _loadedSettings.aiEnabled
        ? 'IA habilitada'
        : 'IA desativada';
    final scheduleDescription = _schedule.enabled
        ? 'Agenda ativa'
        : 'Agenda manual';
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openScreen(const ErrorCenterScreen()),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.monitor_heart_outlined, color: scheme.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado do sistema',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$sourceText · $aiDescription · $scheduleDescription'
                      '${activeZones > 0 ? ' · $activeZones área(s)' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Telemetria',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: scheme.primary,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar() {
    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [VigiaColors.cyan, VigiaColors.blue],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.visibility_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vigia IA',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  'Seu copiloto inteligente',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Alterar modo inicial',
          onPressed: _changeMode,
          icon: const Icon(Icons.swap_horiz_rounded),
        ),
        IconButton(
          tooltip: 'Ajustes',
          onPressed: () => unawaited(_openSettings()),
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildModeCards({bool compactHeight = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = <Widget>[
          VigiaModeCard(
            compact: true,
            icon: Icons.videocam_rounded,
            imageAsset: 'assets/images/modes/live.png',
            title: 'Monitorar',
            subtitle: 'Câmera + IA',
            accent: VigiaColors.cyan,
            onTap: () => unawaited(_startLocalCamera()),
          ),
          VigiaModeCard(
            compact: true,
            icon: Icons.cast_connected_rounded,
            imageAsset: 'assets/images/modes/transmission.png',
            title: 'Transmitir',
            subtitle: 'Enviar imagem',
            accent: VigiaColors.blue,
            onTap: () => _openScreen(const NativeTransmitterScreen()),
          ),
          VigiaModeCard(
            compact: true,
            icon: Icons.phonelink_ring_rounded,
            imageAsset: 'assets/images/modes/remote.png',
            title: 'Receber',
            subtitle: 'Câmera remota',
            accent: VigiaColors.green,
            onTap: () => _openScreen(const MonitorConnectScreen()),
          ),
          VigiaModeCard(
            compact: true,
            icon: Icons.memory_rounded,
            imageAsset: 'assets/images/modes/esp32.png',
            title: 'ESP32',
            subtitle: 'Módulos e sensores',
            accent: VigiaColors.blue,
            onTap: () => _openScreen(const Esp32SettingsScreen()),
          ),
        ];
        final columns = constraints.maxWidth >= 780 ? 4 : 2;
        final spacing = constraints.maxWidth < 420 ? 8.0 : 10.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: columns == 4 ? 108 : (compactHeight ? 103 : 116),
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  Widget _buildCompactMonitorCards(String sourceText, int activeZones) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 360 ? 6.0 : 9.0;
        final itemWidth = (constraints.maxWidth - (spacing * 2)) / 3;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: itemWidth,
              child: _HomeDashboardCard(
                icon: Icons.videocam_outlined,
                title: sourceText,
                value: 'Iniciar',
                description: activeZones == 0 ? 'IA pronta' : '$activeZones área(s)',
                onTap: () => unawaited(_start()),
              ),
            ),
            SizedBox(width: spacing),
            SizedBox(
              width: itemWidth,
              child: _HomeDashboardCard(
                icon: Icons.data_usage_rounded,
                title: 'Uso de dados',
                value: DataUsageService.formatBytes(_dataUsage.snapshot.today.total),
                description: 'Hoje',
                onTap: () => _openScreen(const DataUsageScreen()),
              ),
            ),
            SizedBox(width: spacing),
            SizedBox(
              width: itemWidth,
              child: _HomeDashboardCard(
                icon: Icons.tune_rounded,
                title: 'Ajuste',
                value: 'Configurar',
                description: 'Fonte e IA',
                onTap: () => unawaited(_openMonitorAdjustments()),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMonitorAdjustments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.50,
        maxChildSize: 0.97,
        builder: (context, scrollController) => ValueListenableBuilder<int>(
          valueListenable: _monitorEditorVersion,
          builder: (context, _, child) {
            final activeZones =
                _monitoringZones.where((zone) => zone.enabled).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Ajuste do monitoramento',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar ajustes',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: _monitorConfiguration(activeZones),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
