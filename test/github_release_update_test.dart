import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/github_release_update_service.dart';

void main() {
  const repository = VigiaGitHubReleasePolicy.repository;
  const validHash = 'sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  Map<String, Object?> release({
    String tag = 'v1.0.368+368',
    String? filename,
    String? assetUrl,
    int size = 5000000,
    String? digest = validHash,
    bool draft = false,
    String state = 'uploaded',
  }) {
    final name = filename ?? 'VigiaIA-v1.0.368+368-universal.apk';
    return {
      'tag_name': tag,
      'draft': draft,
      'body': 'Atualização de testes',
      'assets': [{
        'name': name,
        'size': size,
        'state': state,
        'digest': digest,
        'browser_download_url': assetUrl ??
            'https://github.com/$repository/releases/download/$tag/$name',
      }],
    };
  }

  test('seleciona somente APK universal mais novo publicado', () {
    final data = jsonEncode([
      release(tag: 'v1.0.367+367', filename: 'VigiaIA-v1.0.367+367-universal.apk'),
      release(),
    ]);
    final found = VigiaGitHubReleasePolicy.newest(data,
        installedVersion: '1.0.367', installedBuild: 367);
    expect(found?.build, 368);
    expect(found?.sha256Digest, validHash.substring(7));
  });

  test('não oferece versão instalada ou antiga', () {
    final data = jsonEncode([release(tag: 'v1.0.366+366',
        filename: 'VigiaIA-v1.0.366+366-universal.apk')]);
    expect(VigiaGitHubReleasePolicy.newest(data,
        installedVersion: '1.0.367', installedBuild: 367), isNull);
  });

  test('recusa outro repositório, arquivo ou arquitetura', () {
    final wrongHost = release(assetUrl:
        'https://attacker.example/invalid.apk');
    final wrongAbi = release(filename: 'VigiaIA-v1.0.368+368-arm64-v8a.apk');
    final wrongState = release(state: 'new');
    final found = VigiaGitHubReleasePolicy.newest(
        jsonEncode([wrongHost, wrongAbi, wrongState]),
        installedVersion: '1.0.367', installedBuild: 367);
    expect(found?.build, 368);
    expect(found?.downloadUrl, isNull); // mostra novidade sem permitir APK inseguro
    expect(found?.hasDownloadableApk, isFalse);
  });

  test('não oferece rascunho, tag inválida nem tamanho abusivo', () {
    final bad = jsonEncode([
      release(draft: true),
      release(tag: 'other-tag'),
      release(size: VigiaGitHubReleasePolicy.maxApkBytes + 1),
    ]);
    final found = VigiaGitHubReleasePolicy.newest(bad,
        installedVersion: '1.0.367', installedBuild: 367);
    expect(found?.build, 368);
    expect(found?.hasDownloadableApk, isFalse);
  });

  test('sem SHA-256 mostra release mas bloqueia download interno', () {
    final found = VigiaGitHubReleasePolicy.newest(jsonEncode([release(digest: null)]),
        installedVersion: '1.0.367', installedBuild: 367);
    expect(found, isNotNull);
    expect(found?.sha256Digest, isNull);
    expect(found?.hasDownloadableApk, isFalse);
  });

  test('não confunde troca de major menor patch e build', () {
    final candidate = release(tag: 'v1.0.368+300', filename: 'VigiaIA-v1.0.368+300-universal.apk');
    expect(VigiaGitHubReleasePolicy.newest(jsonEncode([candidate]),
        installedVersion: '1.0.367', installedBuild: 367), isNull);
  });
  test('versão nova sem APK universal não é confundida com atualizado', () {
    final candidate = release(filename: 'VigiaIA-v1.0.368+368-arm64-v8a.apk');
    final found = VigiaGitHubReleasePolicy.newest(jsonEncode([candidate]),
        installedVersion: '1.0.367', installedBuild: 367);
    expect(found?.tag, 'v1.0.368+368');
    expect(found?.downloadUrl, isNull);
    expect(found?.hasDownloadableApk, isFalse);
  });

  test('APK universal acima do limite não apaga detecção da nova versão', () {
    final candidate = release(size: VigiaGitHubReleasePolicy.maxApkBytes + 1);
    final found = VigiaGitHubReleasePolicy.newest(jsonEncode([candidate]),
        installedVersion: '1.0.367', installedBuild: 367);
    expect(found?.build, 368);
    expect(found?.downloadUrl, isNull);
  });

  test('APK universal grande dentro do limite é aceito com SHA-256', () {
    final candidate = release(size: 450 * 1024 * 1024);
    final found = VigiaGitHubReleasePolicy.newest(jsonEncode([candidate]),
        installedVersion: '1.0.367', installedBuild: 367);
    expect(found?.hasDownloadableApk, isTrue);
  });

}
