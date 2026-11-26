# Validação 1.0.380+380 — Android APK #324

- Log analisado: `Vigia-IA-Android-APK-324-logs.zip`, etapa 10 (Verificacao preventiva). Falha de asserção do texto antigo Geoapify em `test_maps_sdk_build_key_333.py`.
- Corrigidos os contratos de integração, de versão futura e de classificação de campings na busca de apoio; mantidos os testes de segurança e de coordenadas.
- Suíte Python: 590 testes, 589 aprovados, 1 ignorado, 0 falhas.
- `check_version_sync.py` e `check_release_consistency.py`: aprovados.
- Base: ZIP local 1.0.379; GitHub main 1.0.379; Drive 1.0.376. Nenhum arquivo da base removido.
- Contrato de prévia de rota 235 atualizado: aviso explícito de relevo e segurança sem verificação em campo; pavimento desconhecido continua separado.
- SDK Android 36 e workflow de APK preservados. Flutter/Dart SDK indisponível localmente; análise Flutter, testes Dart, build e instalação pendentes de execução no CI.
