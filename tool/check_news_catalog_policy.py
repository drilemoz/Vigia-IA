#!/usr/bin/env python3
"""Contrato do catálogo de Novidades da versão instalada.

NÃO proíbe linguagem de manutenção: uma correção de bug é mudança
legítima para comunicar ao usuário. Exige versão, entrada única e textos.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def validate(root=ROOT):
    pubspec = (root / 'pubspec.yaml').read_text('utf-8')
    matched = re.search(r'(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$', pubspec)
    if not matched:
        raise ValueError('pubspec sem versão e build válidos')
    version, build = matched.groups()
    if int(version.split('.')[-1]) != int(build):
        raise ValueError('versão e build precisam ser sequenciais')
    catalog = (root / 'lib/services/update_news_catalog.dart').read_text('utf-8')
    expected = f"AppBuildVersion(version: '{version}', build: {build})"
    if catalog.count(expected) != 2:
        raise ValueError('a versão atual deve constar no cabeçalho e na única entrada')
    if len(re.findall(r'(?m)^\s*UpdateRelease\s*\(', catalog)) != 1:
        raise ValueError('a popup deve conter apenas o release atual')
    match = re.search(r'changes:\s*<String>\s*\[(.*?)\]', catalog, flags=re.S)
    if not match:
        raise ValueError('mensagens de mudanças ausentes')
    messages = re.findall(r"(?m)^\s*'([^'\n]+)',?\s*$", match.group(1))
    if not messages or any(len(message.strip()) < 12 for message in messages):
        raise ValueError('Novidades precisam conter mensagens descritivas')
    if any(re.search(r'(?i)\b(todo|placeholder|lorem ipsum)\b', msg) for msg in messages):
        raise ValueError('mensagens provisórias não podem ir para o usuário')
    print(f'Novidades: uma entrada válida para {version}+{build}, {len(messages)} mensagens.')


if __name__ == '__main__':
    try:
        validate()
    except (OSError, ValueError) as error:
        print(f'ERRO NO CATÁLOGO: {error}', file=sys.stderr)
        raise SystemExit(1)
