import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_metadata.dart';

/// Fonte fixa do aplicativo: não aceita URL de APK arbitrária, token ou segredo.
class VigiaGitHubRelease {
  const VigiaGitHubRelease({
    required this.version,
    required this.build,
    required this.tag,
    required this.assetName,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.size,
    required this.notes,
    required this.sha256Digest,
  });

  final String version;
  final int build;
  final String tag;
  final String assetName;
  final Uri downloadUrl;
  final Uri releaseUrl;
  final int size;
  final String notes;
  final String? sha256Digest;
}

class VigiaGitHubReleasePolicy {
  const VigiaGitHubReleasePolicy._();

  static const repository = 'drilemoz/Vigia-IA';
  static const maxApkBytes = 300 * 1024 * 1024;
  static const maxResponseBytes = 4 * 1024 * 1024;
  static final _tag = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)\+(\d+)$');
  static final _digest = RegExp(r'^sha256:([a-fA-F0-9]{64})$');

  /// Ignora rascunhos, ativos sem upload finalizado, outras arquiteturas e
  /// versões antigas. Não confia em URLs retornadas por terceiros.
  static VigiaGitHubRelease? newest(
    String body, {
    String installedVersion = AppMetadata.version,
    int installedBuild = AppMetadata.build,
  }) {
    final installed = installedVersion.split('.').map(int.tryParse).toList();
    if (installed.length != 3 || installed.any((value) => value == null)) {
      return null;
    }
    final decoded = jsonDecode(body);
    if (decoded is! List) return null;
    VigiaGitHubRelease? chosen;
    for (final entry in decoded.take(40)) {
      if (entry is! Map || entry['draft'] == true) continue;
      final tag = entry['tag_name'];
      if (tag is! String) continue;
      final match = _tag.firstMatch(tag);
      if (match == null) continue;
      final parts = <int>[];
      for (var i = 1; i <= 4; i++) {
        final value = int.tryParse(match.group(i)!);
        if (value == null) break;
        parts.add(value);
      }
      if (parts.length != 4) continue;
      final version = '${parts[0]}.${parts[1]}.${parts[2]}';
      final build = parts[3];
      final tuple = parts.take(3).toList();
      var newerVersion = false;
      for (var i = 0; i < 3; i++) {
        if (tuple[i] != installed[i]) {
          newerVersion = tuple[i] > installed[i]!;
          break;
        }
        if (i == 2) newerVersion = build > installedBuild;
      }
      if (!newerVersion || build <= installedBuild) continue;
      final assetName = 'VigiaIA-v$version+$build-universal.apk';
      final expectedUrl = Uri.parse(
        'https://github.com/$repository/releases/download/$tag/$assetName',
      );
      final releaseUrl = Uri.parse(
        'https://github.com/$repository/releases/tag/$tag',
      );
      final assets = entry['assets'];
      if (assets is! List) continue;
      for (final asset in assets) {
        if (asset is! Map || asset['name'] != assetName) continue;
        if (asset['state'] != 'uploaded') continue;
        final rawUrl = asset['browser_download_url'];
        final sourceUrl = rawUrl is String ? Uri.tryParse(rawUrl) : null;
        if (sourceUrl == null ||
            sourceUrl.scheme != 'https' ||
            sourceUrl.host != 'github.com' ||
            sourceUrl.userInfo.isNotEmpty ||
            sourceUrl.hasPort ||
            sourceUrl.hasQuery ||
            sourceUrl.hasFragment ||
            !listEquals(sourceUrl.pathSegments, expectedUrl.pathSegments)) {
          continue;
        }
        final size = asset['size'];
        if (size is! int || size <= 0 || size > maxApkBytes) continue;
        final rawDigest = asset['digest'];
        final digest = rawDigest is String
            ? _digest.firstMatch(rawDigest)?.group(1)?.toLowerCase()
            : null;
        final notes = entry['body'] is String
            ? (entry['body'] as String).substring(
                0, math.min(1800, (entry['body'] as String).length))
            : '';
        final release = VigiaGitHubRelease(
          version: version,
          build: build,
          tag: tag,
          assetName: assetName,
          downloadUrl: sourceUrl,
          releaseUrl: releaseUrl,
          size: size,
          notes: notes,
          sha256Digest: digest,
        );
        if (chosen == null || release.build > chosen.build) chosen = release;
      }
    }
    return chosen;
  }
}

enum VigiaUpdateStatus { idle, checking, upToDate, available, error }

class VigiaGitHubUpdateService extends ChangeNotifier {
  VigiaGitHubUpdateService._();
  static final instance = VigiaGitHubUpdateService._();
  static const _native = MethodChannel('vigiaia/updates');

  VigiaUpdateStatus status = VigiaUpdateStatus.idle;
  VigiaGitHubRelease? latest;
  String? message;
  bool downloading = false;
  bool readyToInstall = false;
  int downloadedBytes = 0;
  int totalBytes = 0;
  double speedBytesPerSecond = 0;
  String? downloadError;

  DateTime? _lastAutomaticCheck;
  bool _cancelRequested = false;
  String? _dismissedVersion;

  static const _checkFrequency = Duration(minutes: 1);

  Future<VigiaGitHubRelease?> checkOnForeground() async {
    if (downloading || readyToInstall || status == VigiaUpdateStatus.checking) {
      return null;
    }
    final now = DateTime.now();
    if (_lastAutomaticCheck != null &&
        now.difference(_lastAutomaticCheck!) < _checkFrequency) {
      return null;
    }
    _lastAutomaticCheck = now;
    await check();
    final release = latest;
    if (status == VigiaUpdateStatus.available &&
        release != null && _dismissedVersion != release.tag) {
      return release;
    }
    return null;
  }

  void dismiss(VigiaGitHubRelease release) {
    _dismissedVersion = release.tag;
  }

  Future<void> check() async {
    if (status == VigiaUpdateStatus.checking || downloading) return;
    status = VigiaUpdateStatus.checking;
    message = null;
    notifyListeners();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.https('api.github.com',
          '/repos/${VigiaGitHubReleasePolicy.repository}/releases',
          const {'per_page': '20'});
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/${AppMetadata.version}');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('GitHub respondeu HTTP ${response.statusCode}');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final part in response.timeout(const Duration(seconds: 12))) {
        bytes.add(part);
        if (bytes.length > VigiaGitHubReleasePolicy.maxResponseBytes) {
          throw const FormatException('Resposta do GitHub muito grande');
        }
      }
      final release = VigiaGitHubReleasePolicy.newest(
        utf8.decode(bytes.takeBytes()),
      );
      latest = release;
      readyToInstall = false;
      status = release == null ? VigiaUpdateStatus.upToDate : VigiaUpdateStatus.available;
    } catch (error) {
      status = VigiaUpdateStatus.error;
      message = _errorMessage(error);
    } finally {
      client.close(force: true);
      notifyListeners();
    }
  }

  static String _errorMessage(Object error) {
    if (error is SocketException) return 'Sem internet ou DNS indisponível. Tente novamente com conexão.';
    if (error is TimeoutException) return 'O GitHub demorou para responder. Tente novamente.';
    if (error is HandshakeException) return 'Falha de certificado/SSL ao acessar o GitHub.';
    if (error is HttpException) return error.message;
    return 'Não foi possível consultar as atualizações. Verifique sua conexão.';
  }

  void cancelDownload() {
    _cancelRequested = true;
  }

  Future<void> download(VigiaGitHubRelease release) async {
    if (downloading || latest?.tag != release.tag) return;
    if (release.sha256Digest == null) {
      downloadError = 'Esta Release não informa SHA-256; use a página oficial do GitHub.';
      notifyListeners();
      return;
    }
    downloading = true;
    readyToInstall = false;
    downloadedBytes = 0;
    totalBytes = release.size;
    speedBytesPerSecond = 0;
    downloadError = null;
    _cancelRequested = false;
    notifyListeners();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    File? pending;
    try {
      final baseDir = await getTemporaryDirectory();
      final dir = Directory('${baseDir.path}/updates');
      await dir.create(recursive: true);
      pending = File('${dir.path}/vigiaia-pending.apk');
      final verified = File('${dir.path}/vigiaia-update.apk');
      if (await pending.exists()) await pending.delete();
      if (await verified.exists()) await verified.delete();
      final request = await client.getUrl(release.downloadUrl).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/${AppMetadata.version}');
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download HTTP ${response.statusCode}');
      }
      if (response.contentLength > VigiaGitHubReleasePolicy.maxApkBytes) {
        throw const FormatException('APK maior que o limite de segurança');
      }
      final sink = pending.openWrite();
      var sinkClosed = false;
      try {
        final watch = Stopwatch()..start();
        var previousTime = 0;
        var previousBytes = 0;
        await for (final chunk in response.timeout(const Duration(seconds: 25))) {
          if (_cancelRequested) throw const _DownloadCancelled();
          downloadedBytes += chunk.length;
          if (downloadedBytes > VigiaGitHubReleasePolicy.maxApkBytes ||
              downloadedBytes > release.size) {
            throw const FormatException('Arquivo excede o tamanho publicado');
          }
          sink.add(chunk);
          final elapsed = watch.elapsedMilliseconds;
          if (elapsed - previousTime >= 400) {
            final dt = elapsed - previousTime;
            speedBytesPerSecond = dt > 0
                ? (downloadedBytes - previousBytes) * 1000 / dt
                : 0;
            previousTime = elapsed;
            previousBytes = downloadedBytes;
            notifyListeners();
          }
        }
        await sink.flush();
        await sink.close();
        sinkClosed = true;
      } finally {
        if (!sinkClosed) await sink.close();
      }
      if (_cancelRequested) throw const _DownloadCancelled();
      if (downloadedBytes != release.size) {
        throw const FormatException('Tamanho baixado difere do GitHub');
      }
      final digest = await sha256.bind(pending.openRead()).first;
      if (digest.toString().toLowerCase() != release.sha256Digest) {
        throw const FormatException('SHA-256 não confere: instalação bloqueada');
      }
      await pending.rename(verified.path);
      readyToInstall = true;
      notifyListeners();
    } on _DownloadCancelled {
      downloadError = 'Download cancelado.';
    } catch (error) {
      downloadError = error is FormatException
          ? error.message
          : _errorMessage(error);
    } finally {
      client.close(force: true);
      if (pending != null && await pending.exists()) await pending.delete();
      downloading = false;
      notifyListeners();
    }
  }

  Future<String> install() async {
    final release = latest;
    final hash = release?.sha256Digest;
    if (!readyToInstall || release == null || hash == null) {
      return 'Nenhum APK verificado está disponível.';
    }
    try {
      final result = await _native.invokeMethod<String>('install', {
        'expectedBuild': release.build,
        'sha256': hash,
      });
      return switch (result) {
        'permission_required' => 'Autorize o Vigia IA a instalar atualizações nas configurações do Android e toque em Instalar novamente.',
        'installer_opened' => 'Instalador aberto. Confirme a atualização no Android.',
        _ => 'Não foi possível iniciar o instalador Android.',
      };
    } on PlatformException catch (error) {
      return error.message ?? 'APK rejeitado pelo Android. Confira assinatura e versão.';
    } catch (_) {
      return 'Não foi possível abrir o instalador Android.';
    }
  }

  Future<void> openReleases() async {
    await _native.invokeMethod<void>('openReleases');
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}
