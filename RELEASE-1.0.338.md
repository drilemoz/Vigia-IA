# Vigia IA 1.0.338+338 — Modo Offline e downloads de mapas

- Base: 1.0.337+337. Sem alterações funcionais nas câmeras, IA, credenciais da central e roteamento online.
- Offline = MBTiles raster local, inclusive quando o APK possui Google Maps habilitado. Auto/Online usam provedor online onde disponível e fallback local em perda de internet.
- Cobertura avaliada na posição do mapa visível e zoom (nunca garantia de tiles completos); avisos para arquivo ausente, pacote fora dos limites ou corredor não verificado.
- Download Stadia: limitação de tamanho, timeouts, cancelamento ativo e até três tentativas para erros transitórios.
- Downloads por URL preservam espaço livre e verificam conteúdo de um tile. Importar, baixar ou excluir o último pacote não troca modo offline para Auto sem autorização.
- Atualizações dos pacotes Stadia preservam o antigo até que o substituto esteja pronto; se dois pacotes excederem o limite de cache, a atualização é recusada sem apagar o mapa.
- Sem permissão de exportar Google Maps para MBTiles; sem recálculo de rotas por MBTiles raster.
- Testes de contrato em `tool/test_offline_mode_download_338.py` e Dart em `test/offline_map_render_policy_test.dart`; conferir `VALIDATION-1.0.338.md`.
