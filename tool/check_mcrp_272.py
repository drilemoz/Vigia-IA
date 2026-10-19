#!/usr/bin/env python3
"""Contrato estático de compatibilidade com Minha Câmera 1.4.74.
Não substitui compilação ou teste com Android/Redmi A3.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
read = lambda n: (root / n).read_text(encoding='utf8')
client = read('lib/services/mcrp_client.dart')
controls = read('lib/widgets/mcrp_remote_controls.dart')
monitor = read('lib/screens/monitor_screen.dart')
portrait = read('lib/screens/monitor_screen_portrait.dart')
menus = read('lib/screens/monitor_screen_fullscreen.dart')
support = read('lib/screens/monitor_screen_mcrp_support.dart')
screen = read('lib/screens/mcrp_camera_screen.dart')
checks = {
  'zoom limitado ao protocolo 0..100': "RegExp(r'^zoom/(0|[1-9][0-9]?|100)$')" in client,
  'lanterna comandos permitidos': all(f"'torch/{a}'" in client for a in ('off', '30', '120', 'record')),
  'telemetria remota': all(f"'x-{k}'" in client for k in ('fps-measured','torch-supported','zoom-percent','battery-level')),
  'controles apenas URL local': 'MinhaCameraLiveUrl.isValid(url)' in support and 'VideoSourceType.remotePhone' in support,
  'MCRP não interfere vigiaia pair': 'McrpAddress.parse(widget.liveUrl)' in controls and 'McrpClient' in controls,
  'não abre segunda conexão de vídeo': 'MinhaCameraMjpegSource(' not in controls and 'VlcPlayer' not in controls,
  'botões no Ao Vivo': '_buildPortraitRemoteControls(context)' in portrait,
  'controle remoto acessível em fullscreen, sem menu redundante': '_showFullscreenRemoteControls()' in menus and '_monitorMenu()' not in menus,
  'controle exclusivo para Minha Câmera': 'if (_activeMcrpLiveUrl != null)' in menus and '_activeMcrpLiveUrl' in support,
  'cliente reutilizado na tela da câmera': 'McrpControlPanel(' in screen,
  'codec somente fora do Ao vivo': 'allowCodecChange: true' in screen and 'this.allowCodecChange = false' in controls,
  'comandos via POST': 'await _http.postUrl(uri)' in client,
  'status via GET': 'await _get(address.status)' in client,
  'testes de widget': (root/'test/mcrp_remote_controls_test.dart').is_file(),
}
for label, success in checks.items():
    if not success: raise SystemExit('FALHOU: '+label)
print(f'MCRP 272: {len(checks)} contratos aprovados.')
