# Validação Vigia IA 1.0.333+333

## Escopo

- Separação de chave Google Maps salva localmente versus chave de build exigida pelo Maps SDK.
- GitHub Secret opcional `MAPS_API_KEY`, incluído no `AndroidManifest` apenas na compilação.
- Desativação da injeção não documentada em `ApplicationInfo.metaData`.
- Controle seguro do renderer Google e fallback OpenStreetMap/offline.
- Central de seis APIs informa as integrações efetivas sem confundir chave salva e autenticação validada.

## Testes

- `python3 -m unittest -q tool/test_maps_sdk_build_key_333.py`
- `python3 tool/check_version_sync.py`
- `python3 tool/check_release_consistency.py`
- `bash tool/verify_project.sh`
- `python3 -m unittest discover -s tool -p 'test_*.py' -q`
- Integridade e metadados do ZIP.

## Pendências

Flutter SDK e Android SDK não disponíveis para `flutter analyze`, `flutter test` e `assembleRelease` neste ambiente. Para validar Google Maps: adicionar Secret `MAPS_API_KEY`, compilar APK assinado, verificar SHA-1/pacote no Google Cloud, abrir mapa em aparelho com Play Services e verificar Logcat. Chave em manifesto não prova autorização do Google.
