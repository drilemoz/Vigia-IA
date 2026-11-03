import 'dart:async';

import 'package:flutter/material.dart';

import '../services/gemini_map_service.dart';
import '../services/api_credentials_backup_service.dart';
import '../services/google_maps_key_service.dart';
import '../services/native_platform_service.dart';
import '../services/partner_api_key_service.dart';
import '../services/offline_map_service.dart';
import '../widgets/offline_map_manager_sheet.dart';
import 'api_service_help.dart';
import 'partner_api_key_screen.dart';
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
  bool _googleSdkReady = false;
  bool _stadiaConfigured = false;
  bool _geoapifyConfigured = false;
  bool _orsConfigured = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    bool gemini = false;
    bool google = false;
    bool googleSdkReady = false;
    bool stadia = false;
    bool geoapify = false;
    bool ors = false;
    try {
      gemini = (await GeminiMapService.instance.status()).configured;
    } catch (_) {
      // Falha de leitura não deve bloquear a instalação ou apagar a chave.
    }
    try {
      await GoogleMapsKeyService.instance.refresh();
      google = GoogleMapsKeyService.instance.status.configured;
      googleSdkReady = GoogleMapsKeyService.instance.status.sdkReady;
    } catch (_) {}
    try {
      await OfflineMapService.instance.initialize();
      stadia = OfflineMapService.instance.hasStadiaApiKey;
    } catch (_) {}
    try {
      geoapify = (await PartnerApiKeyService.instance.status(
        PartnerApiProvider.geoapify)).configured;
    } catch (_) {}
    try {
      ors = (await PartnerApiKeyService.instance.status(
        PartnerApiProvider.openrouteservice)).configured;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _loading = false;
      _geminiConfigured = gemini;
      _googleConfigured = google;
      _googleSdkReady = googleSdkReady;
      _stadiaConfigured = stadia;
      _geoapifyConfigured = geoapify;
      _orsConfigured = ors;
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

  bool _transferring = false;

  Future<String?> _askBackupPassword({required bool exporting}) async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(exporting ? 'Exportar APIs protegidas' : 'Importar APIs protegidas'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(exporting
                  ? 'O arquivo será criptografado com sua senha e pode ser importado em outro Android. Guarde a senha: não é possível recuperá-la.'
                  : 'Selecione um arquivo .vigiaapis e digite a senha usada na exportação.'),
              const SizedBox(height: 12),
              TextField(controller: password, obscureText: true,
                maxLength: 256, decoration: const InputDecoration(
                  labelText: 'Senha (mínimo de 10 caracteres)',
                  border: OutlineInputBorder())),
              if (exporting) TextField(controller: confirmation, obscureText: true,
                maxLength: 256, decoration: const InputDecoration(
                  labelText: 'Confirmar senha', border: OutlineInputBorder())),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (password.text.length < 10 ||
                    (exporting && password.text != confirmation.text)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(
                    content: Text('Senha muito curta ou confirmação diferente.')));
                  return;
                }
                Navigator.pop(dialogContext, password.text);
              },
              child: Text(exporting ? 'Escolher destino' : 'Selecionar arquivo'),
            ),
          ],
        ),
      );
    } finally {
      password.dispose();
      confirmation.dispose();
    }
  }

  Future<void> _transferApiKeys({required bool exporting}) async {
    if (_transferring) return;
    final password = await _askBackupPassword(exporting: exporting);
    if (!mounted || password == null) return;
    setState(() => _transferring = true);
    try {
      final service = ApiCredentialsBackupService.instance;
      if (exporting) {
        final saved = await service.exportEncrypted(password);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved
          ? 'Arquivo de APIs criptografado exportado com sucesso.'
          : 'Exportação cancelada: nada foi salvo.')));
      } else {
        final archive = await service.selectAndDecrypt(password);
        if (!mounted || archive == null) return;
        final label = archive.providers.join(', ');
        final confirmed = await showDialog<bool>(context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirmar importação'),
            content: Text('Provedores no arquivo: $label.\n\n'
              'As chaves presentes substituirão as correspondentes neste aparelho. '
              'As demais serão mantidas. A chave incorporada ao APK do Google Maps NÃO muda.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Importar')),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await service.apply(archive);
        await _refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chaves importadas. Use Testar em cada provedor para validar.')));
      }
    } catch (error) {
      if (!mounted) return;
      // A mensagem de plataforma nunca inclui a senha nem chaves.
      final message = error is FormatException ? error.message :
          'Não foi possível concluir a operação. Confira a senha e o arquivo.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
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
            Text('Central de Serviços e APIs',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Configure serviços opcionais. O Vigia Maps continua funcionando com OpenStreetMap e dados offline sem chaves. Geoapify auxilia pesquisas e pontos; OpenRouteService calcula rotas de bicicleta quando suas chaves estão disponíveis. Sem elas, o mapa usa serviços OSM.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showApiServiceGuide(context),
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Como conseguir todas as APIs?'),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: _transferring ? null : () => _transferApiKeys(exporting: true),
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Exportar APIs'),
              ),
              OutlinedButton.icon(
                onPressed: _transferring ? null : () => _transferApiKeys(exporting: false),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Importar APIs'),
              ),
            ]),
            const SizedBox(height: 6),
            const Text('Backup com senha (AES-256-GCM). Inclui somente chaves configuradas; '
              'Open-Meteo não tem chave e a chave Google Maps incorporada ao APK não é exportada.',
              style: TextStyle(fontSize: 12)),
            const SizedBox(height: 14),
            if (_loading || _transferring) const LinearProgressIndicator(),
            _ApiServiceCard(
              icon: Icons.auto_awesome_rounded,
              title: 'Google Gemini',
              description: 'Assistência para interpretar pesquisas de locais em linguagem natural. Usa conexão e cota da sua conta.',
              configured: _geminiConfigured,
              integrationNote: 'Integrado à busca assistida; chave salva não confirma cota ou autenticação.',
              onConfigure: () => _openScreen(const GeminiMapSettingsScreen()),
              onHelp: () => showApiServiceHelp(context, ApiHelpProvider.gemini),
              helpLabel: 'Obter chave no AI Studio',
            ),
            const SizedBox(height: 10),
            _ApiServiceCard(
              icon: Icons.map_outlined,
              title: 'Google Maps Platform',
              description: 'Mapa Google opcional. Exige chave incluída no APK, faturamento e restrições do pacote/certificado.',
              configured: _googleConfigured,
              integrationNote: _googleSdkReady
                  ? 'Chave presente no APK; autenticação depende do Google Cloud e SHA-1.'
                  : _googleConfigured
                      ? 'Chave salva apenas neste aparelho; SDK NÃO habilitado neste APK.'
                      : 'SDK inativo: configure MAPS_API_KEY no build (GitHub Secret).',
              onConfigure: () => _openScreen(const GoogleMapsKeyScreen()),
              onHelp: () => showApiServiceHelp(context, ApiHelpProvider.googleMaps),
              helpLabel: 'Obter chave no Google Cloud',
            ),
            const SizedBox(height: 10),
            _ApiServiceCard(
              icon: Icons.layers_outlined,
              title: 'Stadia Maps',
              description: 'Para downloads de mapas e estilos autorizados. Mantenha os limites, créditos e termos definidos pela Stadia Maps.',
              configured: _stadiaConfigured,
              integrationNote: 'Integrado ao download de mapas; disponibilidade depende do provedor.',
              onConfigure: _openStadia,
              onHelp: () => showApiServiceHelp(context, ApiHelpProvider.stadia),
              helpLabel: 'Obter chave no painel Stadia',
            ),
            const SizedBox(height: 10),
            _ApiServiceCard(
              icon: Icons.place_outlined,
              title: 'Geoapify',
              description: 'Busca online de destinos e pontos de interesse, com alternativas OSM quando indisponível.',
              configured: _geoapifyConfigured,
              integrationNote: 'Busca de destinos e alternativa de pontos próximos online; sem chave mantém OSM/Overpass.',
              onConfigure: () => _openScreen(const PartnerApiKeyScreen(provider: PartnerApiProvider.geoapify)),
              onHelp: () => showApiServiceHelp(context, ApiHelpProvider.geoapify),
              helpLabel: 'Como conseguir a chave?',
            ),
            const SizedBox(height: 10),
            _ApiServiceCard(
              icon: Icons.directions_bike_outlined,
              title: 'OpenRouteService · HeiGIT',
              description: 'Rotas ciclísticas, manobras e elevação; Valhalla permanece como alternativa.',
              configured: _orsConfigured,
              integrationNote: 'Rotas de bicicleta por ORS com elevação e manobras; Valhalla é alternativa automática.',
              onConfigure: () => _openScreen(const PartnerApiKeyScreen(provider: PartnerApiProvider.openrouteservice)),
              onHelp: () => showApiServiceHelp(context, ApiHelpProvider.openrouteservice),
              helpLabel: 'Como conseguir a chave?',
            ),
            const SizedBox(height: 10),
            _ApiServiceCard(
              icon: Icons.cloud_outlined,
              title: 'Open-Meteo',
              description: 'Previsão meteorológica de até 48 horas com vento, chuva, radiação solar e UV. Previsão em três pontos da rota por toque. Acesso público não comercial sem chave.',
              configured: false,
              keyRequired: false,
              integrationNote: 'Clima e previsão na rota integrados; não exige chave no acesso público não comercial.',
              onConfigure: () => showApiServiceHelp(context, ApiHelpProvider.openMeteo),
              onHelp: () => showApiServiceHelp(context, ApiHelpProvider.openMeteo),
              helpLabel: 'Entender o serviço',
            ),
            const SizedBox(height: 14),
            Text('Chave cadastrada não significa API autenticada ou recurso integrado. '
              'Para Google Maps, só uma chave incorporada ao APK habilita o SDK; '
              'chaves de usuário armazenadas no Android são apenas gerenciadas. '
              'Nunca inclua credenciais em relatórios.',
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
    this.keyRequired = true,
    this.integrationNote,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool configured;
  final VoidCallback onConfigure;
  final VoidCallback onHelp;
  final String helpLabel;
  final bool keyRequired;
  final String? integrationNote;

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
              message: !keyRequired ? 'Não exige chave' : configured ? 'Chave configurada' : 'Ainda não configurada',
              child: Icon(!keyRequired ? Icons.cloud_done_outlined
                  : configured ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: configured || !keyRequired ? scheme.primary : scheme.onSurfaceVariant),
            ),
          ]),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 8),
          Text(!keyRequired ? 'Sem chave · disponível automaticamente'
              : configured ? 'Chave cadastrada' : 'Sem chave · opcional',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          if (integrationNote != null) ...[
            const SizedBox(height: 5),
            Text(integrationNote!,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            FilledButton.tonalIcon(
              onPressed: onConfigure,
              icon: const Icon(Icons.settings_outlined),
              label: Text(!keyRequired ? 'Informações' : configured ? 'Gerenciar chave' : 'Configurar chave'),
            ),
            TextButton.icon(
              onPressed: onHelp,
              icon: const Icon(Icons.help_outline_rounded),
              label: Text(helpLabel),
            ),
          ]),
        ]),
      ),
    );
  }
}
