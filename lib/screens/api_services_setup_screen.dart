import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/gemini_map_service.dart';
import '../services/google_maps_key_service.dart';
import '../services/native_platform_service.dart';
import '../services/offline_map_service.dart';
import '../widgets/offline_map_manager_sheet.dart';
import 'gemini_map_settings_screen.dart';
import 'google_maps_key_screen.dart';
import 'launch_mode_screen.dart';

/// Configuração opcional após as permissões, também acessível em Configurações.
/// Nunca solicita a chave por diálogos novos: reutiliza as telas existentes.
class ApiServicesSetupScreen extends StatefulWidget {
  const ApiServicesSetupScreen({
    super.key,
    this.initialSetup = false,
    this.startMonitorOnLoad = false,
  });

  final bool initialSetup;
  final bool startMonitorOnLoad;

  @override
  State<ApiServicesSetupScreen> createState() => _ApiServicesSetupScreenState();
}

class _ApiServicesSetupScreenState extends State<ApiServicesSetupScreen> {
  bool _loading = true;
  bool _finishing = false;
  bool _geminiConfigured = false;
  bool _googleConfigured = false;
  bool _stadiaConfigured = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    bool gemini = false;
    bool google = false;
    bool stadia = false;
    try {
      gemini = (await GeminiMapService.instance.status()).configured;
    } catch (_) {
      // Falha de leitura não deve bloquear a instalação ou apagar a chave.
    }
    try {
      await GoogleMapsKeyService.instance.refresh();
      google = GoogleMapsKeyService.instance.status.configured;
    } catch (_) {}
    try {
      await OfflineMapService.instance.initialize();
      stadia = OfflineMapService.instance.hasStadiaApiKey;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loading = false;
      _geminiConfigured = gemini;
      _googleConfigured = google;
      _stadiaConfigured = stadia;
    });
  }

  Future<void> _openScreen(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openStadia() async {
    await showOfflineMapManager(context, openStadiaKeyInitially: true);
    if (mounted) await _refresh();
  }

  Future<void> _openOfficial(String url) async {
    final opened = await NativePlatformService.instance.openExternalUrl(url);
    if (opened || !mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link oficial copiado para a área de transferência.')),
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    if (!widget.initialSetup) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _finishing = true);
    final completed = await NativePlatformService.instance.markOnboardingCompleted();
    if (!mounted) return;
    if (!completed) {
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não foi possível concluir a configuração inicial. Tente novamente.'),
      ));
      return;
    }
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => LaunchModeScreen(
          startMonitorOnLoad: widget.startMonitorOnLoad,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.initialSetup,
        title: Text(widget.initialSetup ? 'Serviços e APIs · Configuração inicial' : 'Serviços e APIs'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (widget.initialSetup) ...[
              Text('Etapa 2 de 3', style: TextStyle(color: color.primary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
            ],
            Text('Conecte seus serviços de mapas',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Tudo é opcional. Você pode configurar depois. O Vigia Maps continua funcionando com OpenStreetMap, navegação e recursos offline sem essas chaves.'),
            const SizedBox(height: 14),
            if (_loading) const LinearProgressIndicator(),
            _ApiServiceCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Google Gemini',
              description: 'Assistência para interpretar pesquisas de locais em linguagem natural. Usa conexão e cota da sua conta.',
              configured: _geminiConfigured,
              onConfigure: () => _openScreen(const GeminiMapSettingsScreen()),
              onHelp: () => _openOfficial('https://aistudio.google.com/apikey'),
              helpLabel: 'Obter chave no AI Studio',
            ),
            const SizedBox(height: 10),
            _ApiServiceCard(
              icon: Icons.map_outlined,
              title: 'Google Maps Platform',
              description: 'Mapa Google opcional. Requer Maps SDK for Android, faturamento e restrições Android para o pacote e certificado do app.',
              configured: _googleConfigured,
              onConfigure: () => _openScreen(const GoogleMapsKeyScreen()),
              onHelp: () => _openOfficial('https://console.cloud.google.com/google/maps-apis'),
              helpLabel: 'Obter chave no Google Cloud',
            ),
            const SizedBox(height: 10),
            _ApiServiceCard(
              icon: Icons.layers_outlined,
              title: 'Stadia Maps',
              description: 'Para downloads de mapas e estilos autorizados. Mantenha os limites, créditos e termos definidos pela Stadia Maps.',
              configured: _stadiaConfigured,
              onConfigure: _openStadia,
              onHelp: () => _openOfficial('https://client.stadiamaps.com/dashboard/'),
              helpLabel: 'Obter chave no painel Stadia',
            ),
            const SizedBox(height: 14),
            Text('Cada serviço usa sua própria chave protegida. As opções de salvar, testar, mostrar, copiar e remover continuam nas telas existentes. Não cole suas chaves em relatórios de erro.',
              style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _finishing ? null : _finish,
              icon: _finishing
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(widget.initialSetup ? 'Continuar para escolher o modo' : 'Concluído'),
            ),
            if (widget.initialSetup) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: _finishing ? null : _finish,
                child: const Text('Configurar depois'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ApiServiceCard extends StatelessWidget {
  const _ApiServiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.configured,
    required this.onConfigure,
    required this.onHelp,
    required this.helpLabel,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool configured;
  final VoidCallback onConfigure;
  final VoidCallback onHelp;
  final String helpLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            Tooltip(
              message: configured ? 'Chave configurada' : 'Ainda não configurada',
              child: Icon(configured ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: configured ? scheme.primary : scheme.onSurfaceVariant),
            ),
          ]),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 8),
          Text(configured ? 'Chave cadastrada' : 'Sem chave · opcional',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            FilledButton.tonalIcon(
              onPressed: onConfigure,
              icon: const Icon(Icons.settings_outlined),
              label: Text(configured ? 'Gerenciar chave' : 'Configurar chave'),
            ),
            TextButton.icon(
              onPressed: onHelp,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(helpLabel),
            ),
          ]),
        ]),
      ),
    );
  }
}
