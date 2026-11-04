# Validação — Vigia IA 1.0.347+347

## Escopo

- Nova janela compacta `MapLayerPickerPanel`: três abas para aparência, provedor e base; opções selecionadas localmente, com resumo e OK/Cancelar.
- Preserva quatro aparências manuais e Sistema/Dia-noite; dois provedores; cinco estilos de base. Credenciais de serviços ficam fora da janela.
- Suporte a mapa atual e pacotes offline sem conversão ou migração da base de preferências; guardas para SDK Google e chave Stadia.

## Evidências locais (2026-11-04)

- `tool/verify_project.sh`: **aprovado (exit 0)** após ajuste dos contratos históricos para a nova organização.
- Suíte Python consolidada: **460 testes executados, 459 aprovados, 1 ignorado, 0 falhas**.
- `tool/test_map_layer_picker_347.py`: **4 contratos aprovados** (opções, confirmação, APIs fora do painel e restrições de chave).
- `tool/check_version_sync.py` e política de Novidades: **1.0.347+347 sincronizado**.
- `bash -n tool/verify_project.sh`: sintaxe aprovada.
- `test/map_layer_picker_panel_test.dart`: quatro cenários escritos (confirmação; restrições de chaves; Google habilitado; Google offline), **não executados localmente**.

## Limitações

- Flutter SDK não instalado neste ambiente: `flutter analyze` e `flutter test` Dart não executados; precisam passar no GitHub Actions.
- APK Android, layout físico, renderizadores Google/OSM/MapLibre e testes no aparelho ainda pendentes.
- Não atribuir à verificação Python a execução dos testes Flutter ou validação do APK.
