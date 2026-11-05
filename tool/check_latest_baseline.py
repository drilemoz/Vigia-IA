#!/usr/bin/env python3
"""Guard against accidentally resuming an older Vigia IA release branch.

Every new release MUST update tool/version_baseline.json after checking the
latest real ZIP in the work directory/connected Drive. This mechanical floor
cannot itself query Drive; the source verification is a human/workflow step.
"""
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
base=json.loads((ROOT/'tool/version_baseline.json').read_text('utf8'))
value=re.search(r'(?m)^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$',
                (ROOT/'pubspec.yaml').read_text('utf8'))
if value is None:raise SystemExit('ERRO: pubspec.yaml sem version')
current=value.group(1)
if current!=base['new_version']:
    raise SystemExit(f'ERRO: versão {current} diverge da base verificada {base["new_version"]}. '
                     'Localize o ZIP mais recente antes de editar e atualize version_baseline.json.')
def number(version):
    _, build=version.split('+')
    return int(build)
if number(current) <= number(base['verified_latest_base']):
    raise SystemExit('ERRO: regressão: versão atual não supera a base verificada')
if not base['source'] or not base['verified_date']:
    raise SystemExit('ERRO: falta registrar fonte e data da verificação')
print(f'Base verificada: {base["verified_latest_base"]} -> {current}')
