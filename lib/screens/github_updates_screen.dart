import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_metadata.dart';
import '../services/github_release_update_service.dart';

/// Tela acessível em Sobre. Atualizações são verificadas online, mas o app
/// continua funcional offline. Download e instalação exigem ações explícitas.
class GitHubUpdatesScreen extends StatefulWidget {
  const GitHubUpdatesScreen({super.key});

  @override
  State<GitHubUpdatesScreen> createState() => _GitHubUpdatesScreenState();
}

class _GitHubUpdatesScreenState extends State<GitHubUpdatesScreen> {
  final _updates = VigiaGitHubUpdateService.instance;
  String? _installMessage;

  @override
  void initState() {
    super.initState();
    if (_updates.status == VigiaUpdateStatus.idle) {
      unawaited(_updates.check());
    }
  }

  static String _size(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MiB';

  Future<void> _confirmDownload(VigiaGitHubRelease release) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Baixar ${release.version}+${release.build}?'),
        content: const Text(
          'O APK universal será baixado do GitHub e conferido por SHA-256. '
          'A instalação só ocorrerá com sua autorização no Android. '
          'Não desinstale a versão atual, pois isso pode apagar seus dados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Baixar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _updates.download(release);
  }

  Future<void> _install() async {
    final response = await _updates.install();
    if (mounted) setState(() => _installMessage = response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atualizações pelo GitHub')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _updates,
          builder: (context, _) {
            final release = _updates.latest;
            final checking = _updates.status == VigiaUpdateStatus.checking;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.verified_outlined),
                  title: Text('Versão instalada'),
                  subtitle: Text('${AppMetadata.version}+${AppMetadata.build}'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: checking || _updates.downloading
                      ? null
                      : () => unawaited(_updates.check()),
                  icon: const Icon(Icons.system_update_outlined),
                  label: const Text('Verificar atualizações'),
                ),
                const SizedBox(height: 16),
                if (checking) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  const Text('Consultando GitHub Releases…'),
                ] else if (_updates.status == VigiaUpdateStatus.upToDate) ...[
                  const ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('O Vigia IA está atualizado'),
                  ),
                ] else if (_updates.status == VigiaUpdateStatus.error) ...[
                  Text(
                    _updates.message ?? 'Não foi possível consultar o GitHub.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 10),
                  const Text('Sem internet, o Vigia IA continua funcionando normalmente.'),
                ] else if (_updates.status == VigiaUpdateStatus.available && release != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Versão disponível: ${release.version}+${release.build}',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          if (release.size > 0)
                            Text('APK universal · ${_size(release.size)}'),
                          if (release.notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('Novidades', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 6),
                            SelectableText(release.notes),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (release.downloadUrl == null)
                    const Text('Uma versão nova foi publicada, mas nenhum APK universal '
                        'compatível com a verificação interna foi encontrado. '
                        'Abra Releases no GitHub para consultar os arquivos oficiais.')
                  else if (release.sha256Digest == null)
                    const Text('A Release não informa um SHA-256 verificável. '
                        'O download interno está bloqueado; consulte a página oficial.')
                  else if (!_updates.downloading && !_updates.readyToInstall)
                    FilledButton.icon(
                      onPressed: () => unawaited(_confirmDownload(release)),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Baixar atualização'),
                    ),
                ],
                if (_updates.downloading) ...[
                  const SizedBox(height: 14),
                  Text('Baixando ${_updates.totalBytes > 0 ? '${(_updates.downloadedBytes / _updates.totalBytes * 100).clamp(0, 100).toStringAsFixed(0)}%' : ''}'),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _updates.totalBytes > 0
                        ? (_updates.downloadedBytes / _updates.totalBytes).clamp(0.0, 1.0)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text('${_size(_updates.downloadedBytes)} de ${_size(_updates.totalBytes)} · '
                      '${_size(_updates.speedBytesPerSecond.round())}/s'),
                  if (_updates.speedBytesPerSecond > 0 &&
                      _updates.totalBytes > _updates.downloadedBytes)
                    Text('Tempo restante aproximado: '
                        '${((_updates.totalBytes - _updates.downloadedBytes) / _updates.speedBytesPerSecond / 60).ceil()} min'),
                  OutlinedButton.icon(
                    onPressed: _updates.cancelDownload,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar download'),
                  ),
                ],
                if (_updates.downloadError != null) ...[
                  const SizedBox(height: 8),
                  Text(_updates.downloadError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (_updates.readyToInstall) ...[
                  const SizedBox(height: 14),
                  const Text('APK baixado e SHA-256 conferido.'),
                  FilledButton.icon(
                    onPressed: () => unawaited(_install()),
                    icon: const Icon(Icons.install_mobile_outlined),
                    label: const Text('Instalar atualização'),
                  ),
                ],
                if (_installMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_installMessage!),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => unawaited(_updates.openReleases()),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir Releases no GitHub'),
                ),
                const SizedBox(height: 12),
                const Text('A verificação é feita ao abrir e ao retomar o aplicativo, '
                    'com intervalo mínimo de um minuto. Nunca há download ou '
                    'instalação automática. A atualização exige a mesma assinatura '
                    'da versão instalada para preservar seus dados.'),
              ],
            );
          },
        ),
      ),
    );
  }
}
