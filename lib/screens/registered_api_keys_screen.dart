import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/gemini_map_service.dart';
import '../services/google_maps_key_service.dart';
import '../services/offline_map_service.dart';
import '../services/partner_api_key_service.dart';

/// Relação das APIs cadastradas: revela somente após toque em cada chave.
/// Credenciais nunca são incluídas em logs ou enviadas a serviços externos.
class RegisteredApiKeysScreen extends StatefulWidget {
  const RegisteredApiKeysScreen({super.key});

  @override
  State<RegisteredApiKeysScreen> createState() => _RegisteredApiKeysScreenState();
}

enum _Credential { gemini, googleMaps, stadia, geoapify, openrouteservice }

extension _CredentialDetails on _Credential {
  String get title => switch (this) {
    _Credential.gemini => 'Google Gemini',
    _Credential.googleMaps => 'Google Maps (chave salva)',
    _Credential.stadia => 'Stadia Maps',
    _Credential.geoapify => 'Geoapify',
    _Credential.openrouteservice => 'OpenRouteService',
  };
}

class _RegisteredApiKeysScreenState extends State<RegisteredApiKeysScreen> {
  final Map<_Credential, bool?> _configured = <_Credential, bool?>{};
  final Map<_Credential, String> _revealed = <_Credential, String>{};
  bool _loading = true;
  bool _sdkReady = false;
  _Credential? _busy;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _revealed.clear();
    });
    final values = <_Credential, bool?>{};
    Future<void> read(_Credential id, Future<bool> Function() loader) async {
      try {
        values[id] = await loader();
      } catch (_) {
        values[id] = null;
      }
    }
    await read(_Credential.gemini, () async =>
        (await GeminiMapService.instance.status()).configured);
    await read(_Credential.googleMaps, () async {
      await GoogleMapsKeyService.instance.refresh();
      return GoogleMapsKeyService.instance.status.userConfigured;
    });
    final sdkReady = GoogleMapsKeyService.instance.status.sdkReady;
    await read(_Credential.stadia, () async {
      await OfflineMapService.instance.initialize();
      return OfflineMapService.instance.hasStadiaApiKey;
    });
    await read(_Credential.geoapify, () async =>
        (await PartnerApiKeyService.instance.status(
          PartnerApiProvider.geoapify)).configured);
    await read(_Credential.openrouteservice, () async =>
        (await PartnerApiKeyService.instance.status(
          PartnerApiProvider.openrouteservice)).configured);
    if (!mounted) return;
    setState(() {
      _configured..clear()..addAll(values);
      _sdkReady = sdkReady;
      _loading = false;
    });
  }

  Future<String?> _readKey(_Credential id) => switch (id) {
    _Credential.gemini => GeminiMapService.instance.reveal(),
    _Credential.googleMaps => GoogleMapsKeyService.instance.reveal(),
    _Credential.stadia => OfflineMapService.instance.revealStadiaApiKey(),
    _Credential.geoapify => PartnerApiKeyService.instance.reveal(
        PartnerApiProvider.geoapify),
    _Credential.openrouteservice => PartnerApiKeyService.instance.reveal(
        PartnerApiProvider.openrouteservice),
  };

  Future<void> _showOrHide(_Credential id) async {
    if (_busy != null) return;
    if (_revealed.containsKey(id)) {
      setState(() => _revealed.remove(id));
      return;
    }
    setState(() => _busy = id);
    try {
      final key = await _readKey(id);
      if (!mounted) return;
      if (key == null || key.isEmpty) {
        _message('Não foi possível ler essa chave.');
      } else {
        setState(() => _revealed[id] = key);
      }
    } catch (_) {
      if (mounted) _message('Não foi possível ler essa chave.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _copy(_Credential id) async {
    if (_busy != null) return;
    setState(() => _busy = id);
    try {
      final key = _revealed[id] ?? await _readKey(id);
      if (!mounted) return;
      if (key == null || key.isEmpty) {
        _message('Não há chave disponível para copiar.');
        return;
      }
      await Clipboard.setData(ClipboardData(text: key));
      if (mounted) _message('Chave copiada. A área de transferência pode ficar visível a outros apps.');
    } catch (_) {
      if (mounted) _message('Não foi possível copiar a chave.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(value)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('APIs e chaves cadastradas'),
        actions: [
          IconButton(
            tooltip: 'Atualizar lista',
            onPressed: _loading || _busy != null ? null : () => unawaited(_refresh()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Consulte quais serviços têm chave salva neste aparelho. '
              'Toque no olho para mostrar ou ocultar cada chave. '
              'Uma chave salva não garante que a API esteja funcionando.'),
          const SizedBox(height: 14),
          if (_loading) const LinearProgressIndicator(),
          for (final id in _Credential.values) ...[
            Card(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(id.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  _loading || !_configured.containsKey(id)
                    ? 'Consultando...'
                    : _configured[id] == null
                        ? 'Não foi possível consultar'
                        : _configured[id]!
                            ? 'Chave salva no aparelho'
                            : 'Nenhuma chave salva',
                  style: theme.textTheme.bodySmall,
                ),
                if (_revealed.containsKey(id)) ...[
                  const SizedBox(height: 8),
                  SelectableText(_revealed[id]!,
                    style: const TextStyle(fontFamily: 'monospace')),
                ],
                if (_configured[id] == true && !_loading) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    TextButton.icon(
                      onPressed: _busy == null ? () => unawaited(_showOrHide(id)) : null,
                      icon: Icon(_revealed.containsKey(id)
                          ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      label: Text(_revealed.containsKey(id) ? 'Ocultar' : 'Mostrar'),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: _busy == null ? () => unawaited(_copy(id)) : null,
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copiar'),
                    ),
                  ]),
                ],
              ]),
            )),
            const SizedBox(height: 6),
          ],
          Card(child: ListTile(
            title: const Text('Google Maps SDK (chave do APK)'),
            subtitle: Text(_sdkReady
              ? 'Configurado no APK; a chave incorporada não é exibida nem exportada.'
              : 'Não configurado neste APK.'),
          )),
          Card(child: const ListTile(
            title: Text('Open-Meteo'),
            subtitle: Text('Acesso público não comercial: não exige chave.'),
          )),
        ],
      ),
    );
  }
}
