# Validação — Vigia IA 1.0.342+342

## Origem

Workflow Android APK 287: `bash tool/verify_project.sh` falhou com `test/app_metadata_test.dart espera uma versao diferente do pubspec`. O arquivo Dart exigia 1.0.340+340 em um pacote que já usava 1.0.341+341. O Flutter/Android ainda não havia sido compilado no workflow.

## Mudanças

- Teste Dart dinâmico a partir do pubspec, com assertivas sobre `AppMetadata.version` e `AppMetadata.build`.
- Python `check_version_sync.py` exige a leitura dinâmica e proíbe expectativas numéricas antigas; novo `test_app_metadata_dynamic_342.py` executado pela verificação preventiva.
- Sincronização de todos os identificadores correntes, release 1.0.342 e documentação; sem mudanças funcionais no planejamento da cicloviagem.

## Evidências e limites

- `bash tool/verify_project.sh`: **aprovado (exit 0)** nesta entrega.
- Suíte consolidada `python3 -m unittest discover -s tool -p 'test_*.py' -v`: **443 testes, 442 aprovados e 1 ignorado**; nenhuma falha.
- `tool/test_app_metadata_dynamic_342.py` (3 testes) e `tool/check_version_sync.py`: aprovados.
- `tool/check_map_ui_220.py` e `tool/check_route_preview_229.py` atualizados para conferir a interface unificada. Ambos passaram, sem remover validação do almoço manual nem aviso sobre acesso por vias.
- Os dois painéis de Mudanças/Sobre apresentam a versão 1.0.342 como atual, preservando histórico 1.0.341; regressões da tela passaram.
- `tool/check_release_consistency.py` e `tool/check_news_catalog_policy.py`: aprovados.
- `bash -n tool/verify_project.sh`: aprovado.
- Validação estrutural e CRC do ZIP: conferidas ao empacotar.
- Sem Flutter/Android SDK neste ambiente: `flutter analyze`, `flutter test`, APK e teste em dispositivo **não executados**; dependem do workflow GitHub Actions.
