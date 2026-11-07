# Validação 1.0.365+365

## Análise de causa

- O HUD apresentava `Sem sinal atual` para qualquer leitura não considerada fresca em 20 segundos, mesmo com serviço do Android ativo e última posição válida.
- A assinatura passiva usava filtro de movimento de 35 m, logo podia permanecer sem eventos enquanto o celular estava parado.
- A busca de pontos permitia no máximo 18 s, mesmo tendo dois servidores Overpass com espera própria de até 17 s.

## Correções

- `MapGpsHudPolicy` exibe estado de permissão/GPS e última leitura em separado.
- `AndroidSettings(intervalDuration: 15 s, distanceFilter: 0)` para mapa visível e passivo, mantendo a economia anterior quando a tela não consome localização.
- Overpass com prazos individuais menores e total de 30 s; sem garantia de disponibilidade dos serviços públicos.
- Mensagens seguras e pesquisa pelo centro do mapa sem depender da leitura GPS.

## Validação local

- Testes direcionados de GPS/POI e testes históricos de mapas/permissões: aprovados.
- `python3 -m unittest discover -s tool -p "test_*.py" -q`: **541 testes executados, 540 aprovados, 1 ignorado**, nenhum erro.
- `bash tool/verify_project.sh`: **aprovado, saída 0** (contratos e verificações complementares).
- `python3 tool/check_version_sync.py`, `python3 tool/check_release_consistency.py` e `python3 tool/check_latest_baseline.py`: aprovados.
- Não existe garantia de que a rede ou serviço Overpass funcione sem internet ou responda em todas as regiões.
- SDK Flutter/Android ausente no ambiente local: `flutter analyze`, `flutter test` e APK devem ser confirmados no CI.
