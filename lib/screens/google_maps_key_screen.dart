import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_service_help.dart';

import '../services/google_maps_key_service.dart';
import '../services/native_platform_service.dart';

/// Permite que cada pessoa use a própria chave do Google Maps Platform.
class GoogleMapsKeyScreen extends StatefulWidget {
  const GoogleMapsKeyScreen({super.key});

  @override
  State<GoogleMapsKeyScreen> createState() => _GoogleMapsKeyScreenState();
}

class _GoogleMapsKeyScreenState extends State<GoogleMapsKeyScreen> {
  final GoogleMapsKeyService _service = GoogleMapsKeyService.instance;
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;
  bool _hasSavedUserKey = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _service.refresh();
    if (!mounted) return;
    setState(() => _hasSavedUserKey = _service.status.isUserKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = GoogleMapsKeyService.validate(_controller.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await _service.save(_controller.text);
      if (!mounted) return;
      setState(() { _hasSavedUserKey = true; _controller.clear(); _obscure = true; });
      _showMessage(
        'Chave salva de forma criptografada. Para ativar o Maps SDK, '
        'é necessário compilar o APK com o Secret MAPS_API_KEY.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível salvar a chave: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover chave?'),
        content: const Text(
          'Remover esta chave salva no aparelho não altera a chave que já '
          'foi incorporada no APK. O mapa OSM continua disponível.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _service.save('');
      if (!mounted) return;
      setState(() {
        _hasSavedUserKey = false;
        _controller.clear();
        _error = null;
      });
      _showMessage('Chave removida.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Não foi possível remover a chave: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final clipboardText = data?.text;
      if (clipboardText == null || clipboardText.isEmpty) {
        _showMessage('Área de transferência vazia.');
        return;
      }
      setState(() { _controller.text = clipboardText; _error = null; });
    } catch (_) {
      if (mounted) _showMessage('Não foi possível colar a chave.');
    }
  }

  Future<void> _copy() async {
    try {
      final key = _controller.text.isNotEmpty
          ? _controller.text : (_hasSavedUserKey ? await _service.reveal() : null);
      if (!mounted) return;
      if (key == null || key.isEmpty) {
        _showMessage('Não existe chave do usuário para copiar.');
        return;
      }
      await Clipboard.setData(ClipboardData(text: key));
      if (mounted) _showMessage('Chave copiada. Limpe a área de transferência após usar.');
    } catch (_) {
      if (mounted) _showMessage('Não foi possível copiar a chave.');
    }
  }

  Future<void> _toggleReveal() async {
    if (!_obscure) { setState(() => _obscure = true); return; }
    if (_controller.text.isEmpty && _hasSavedUserKey) {
      final key = await _service.reveal();
      if (!mounted) return;
      if (key == null || key.isEmpty) { _showMessage('Não foi possível ler a chave salva.'); return; }
      _controller.text = key;
    }
    setState(() => _obscure = false);
  }

  Future<void> _check() async {
    try {
      await _service.refresh();
      if (!mounted) return;
      final status = _service.status;
      _showMessage(status.sdkReady
          ? 'Maps SDK configurado no APK. Isso não confirma autenticação, cotas ou SHA-1 no Google Cloud.'
          : status.userConfigured
              ? 'Chave salva neste aparelho, mas NÃO incorporada ao APK. Configure o Secret MAPS_API_KEY e gere novo APK.'
              : 'Maps SDK não habilitado neste APK. Configure o Secret MAPS_API_KEY na compilação.');
    } catch (_) {
      if (mounted) _showMessage('Não foi possível consultar a configuração.');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final status = _service.status;
        final sourceLabel = status.sdkReady
            ? 'Maps SDK configurado no APK (não validado online)'
            : status.userConfigured
                ? 'Chave salva no aparelho · SDK inativo neste APK'
                : 'Maps SDK não configurado neste APK';
        return Scaffold(
          appBar: AppBar(title: const Text('Chave do Google Maps'), actions: [
            IconButton(tooltip: 'Como obter?', icon: const Icon(Icons.help_outline_rounded),
              onPressed: () => showApiServiceHelp(context, ApiHelpProvider.googleMaps)),
          ]),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: status.sdkReady
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
                      : theme.colorScheme.errorContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(status.sdkReady
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sourceLabel,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            if (status.configured)
                              Text(status.masked),
                            if (!status.sdkReady)
                              const Text(
                                'O mapa Google exige uma chave incluída na compilação; OSM/offline continua disponível.',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: 'Chave da API (Maps SDK for Android)',
                  hintText: 'AIza...',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: _saving ? null : () => unawaited(_toggleReveal()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => unawaited(_save()),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Salvar chave'),
                    ),
                  ),
                  if (_hasSavedUserKey) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => unawaited(_remove()),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remover'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(onPressed: _saving ? null : () => unawaited(_paste()),
                  icon: const Icon(Icons.content_paste_rounded), label: const Text('Colar')),
                OutlinedButton.icon(onPressed: _saving ? null : () => unawaited(_copy()),
                  icon: const Icon(Icons.copy_outlined), label: const Text('Copiar')),
                OutlinedButton.icon(onPressed: _saving ? null : () => unawaited(_check()),
                  icon: const Icon(Icons.fact_check_outlined), label: const Text('Verificar configuração')),
              ]),
              const SizedBox(height: 8),
              Text('O Maps SDK for Android valida a chave incluída no manifesto quando abre o mapa. Salvar nesta tela não altera o APK; o teste local não comprova autenticação ou SHA-1.',
                style: theme.textTheme.bodySmall),
              const SizedBox(height: 20),
              Text('Como obter uma chave',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                '1. Acesse console.cloud.google.com e crie um projeto.\n'
                '2. Ative o faturamento (o Google exige, mas há cota gratuita mensal).\n'
                '3. Em APIs e serviços, ative "Maps SDK for Android".\n'
                '4. Em Credenciais, crie uma chave de API.\n'
                '5. Restrinja a chave a apps Android: pacote com.vigiaia.app e a '
                'impressão digital SHA-1 do certificado que assinou este APK.\n'
                '6. Para ativar o mapa Google: crie no GitHub o Secret MAPS_API_KEY '
                'e gere um novo APK assinado. Colar nesta tela apenas guarda a chave, sem ativar o SDK.',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => unawaited(NativePlatformService.instance
                    .openExternalUrl('https://console.cloud.google.com/google/maps-apis')),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir Google Maps Platform'),
              ),
              const SizedBox(height: 16),
              Text(
                'A chave salva nesta tela é protegida no aparelho, mas não é injetada no SDK. '
                'Uma chave MAPS_API_KEY usada na compilação ficará no APK e deve ter restrições Android '
                '(pacote e SHA-1). Cobranças e cotas são da sua conta Google Cloud.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
