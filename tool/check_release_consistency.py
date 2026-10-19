#!/usr/bin/env python3
"""Validate the packaged version/build as a pair in all active release sources.

This checker obtains expected values from pubspec.yaml and never hardcodes an
older build. It prevents an outdated grep guard from blocking CI again.
"""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def validate():
    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    match = re.search(r'(?m)^version: (\d+\.\d+\.\d+)\+(\d+)\s*$', pubspec)
    if match is None:
        raise ValueError('pubspec.yaml: versão no formato X.Y.Z+build ausente')
    version, build_string = match.groups()
    build = int(build_string)
    if int(version.split('.')[-1]) != build:
        raise ValueError('pubspec.yaml: build divergente da versão sequencial')

    metadata = (ROOT / 'lib/core/app_metadata.dart').read_text('utf-8')
    if f"static const String version = '{version}';" not in metadata:
        raise ValueError('AppMetadata.version divergente')
    if f'static const int build = {build};' not in metadata:
        raise ValueError('AppMetadata.build divergente')

    catalog = (ROOT / 'lib/services/update_news_catalog.dart').read_text('utf-8')
    entry = f"AppBuildVersion(version: '{version}', build: {build})"
    if catalog.count(entry) != 2:
        raise ValueError('Catalogo de Novidades deve referenciar a versão e o build atuais duas vezes')
    release_note = ROOT / f'RELEASE-{version}.md'
    if not release_note.is_file():
        raise ValueError(f'Notas de release ausentes: {release_note.name}')

    about = (ROOT / 'lib/screens/app_info_screen_components.dart').read_text('utf-8')
    if f"version: '{version}',\n          current: true," not in about:
        raise ValueError('Tela Sobre: versão atual não está marcada')

    for name in ('app_identity.json', 'github-manager.json'):
        data = json.loads((ROOT / name).read_text('utf-8'))
        if data.get('version') != version or data.get('build') != build:
            raise ValueError(f'{name}: versão/build divergente')
        if name == 'github-manager.json':
            android = data['android']
            if android.get('versionName') != version or android.get('versionCode') != build:
                raise ValueError('github-manager.json: versão Android divergente')

    checker = (ROOT / 'tool/verify_project.sh').read_text('utf-8')
    if 'python3 tool/check_release_consistency.py' not in checker:
        raise ValueError('O verificador integral deve executar este contrato')
    print(f'Versao e build sincronizados: {version}+{build}')


if __name__ == '__main__':
    try:
        validate()
    except (ValueError, KeyError, OSError) as exc:
        print(f'ERRO DE VERSAO: {exc}', file=sys.stderr)
        raise SystemExit(1)
