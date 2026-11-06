"""Fonte única de versão para contratos de regressão históricos."""
from pathlib import Path
import re

def current_release(root: Path) -> str:
    pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')
    match = re.search(r'(?m)^version: (1\.0\.\d+\+\d+)\s*$', pubspec)
    if match is None:
        raise AssertionError('pubspec sem versão no formato esperado')
    return match.group(1)

def version_only(root: Path) -> str:
    return current_release(root).split('+')[0]

def catalog_reference(root: Path) -> str:
    return f"AppBuildVersion(version: '{version_only(root)}', build: {current_release(root).split('+')[1]})"

def current_build(root: Path) -> int:
    return int(current_release(root).split('+')[1])
