# Vigia IA 1.0.371+371

Data: 09/11/2026

## Correção Android APK 316

- O verificador de prévia de rotas bloqueava o CI porque o texto de cautela com pontos de apoio mudou na atualização 1.0.370.
- Restaurada a advertência completa em **Ferramentas e ajustes > Localidades e pontos de apoio**, mantendo o novo painel recolhível e a navegação entre dias.
- O aviso informa que a proximidade em linha reta não confirma passagem pela via, acesso seguro, água ou hospedagem. Foi preservado também o aviso de conferência antiga quando a parada mudou.
- A lógica de rotas, mapa offline, clima, conferências, cálculo e navegação entre dias não foi alterada nesta correção.

## Validação

- O teste que falhou no workflow 316 (`tool/check_route_preview_229.py`) passou com 11 contratos estruturais. `bash tool/verify_project.sh` também terminou com código 0; 561 testes no grupo unittest (560 aprovados e 1 pulado sem Dart SDK).
- Compilação e testes Flutter/Android aguardam nova execução do CI; não houve APK produzido localmente.
