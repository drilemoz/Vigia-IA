# Validação específica — Vigia IA 1.0.335+335

- `bash tool/verify_project.sh`: **aprovado (exit 0)** em 2026-11-03.
- Suíte Python agregada: **406 testes executados, 405 aprovados, 1 ignorado**, incluindo 7 novos contratos de Geoapify, ORS, Open-Meteo, consultas por cidade e atalhos.
- `python3 tool/check_version_sync.py`: aprovado; `python3 tool/check_release_consistency.py`: aprovado.
- Testes estruturais também preservam fallback para OSM/Nominatim/Overpass/Valhalla, separação entre POIs manuais da cidade e alertas de GPS, ausência de chave obrigatória e limite de dois atalhos.
- `test/partner_map_integrations_335_test.dart`: testes Dart de parser Geoapify, ORS GeoJSON com elevação e Open-Meteo com UV/radiação incluídos **para execução no CI**; não executados localmente.
- **Pendentes**: `flutter analyze`, `flutter test`, compilação Gradle/Android, respostas com credenciais reais, visualização em telas menores, consulta e persistência com GPS e rede reais. O SDK Flutter/Android não está disponível neste ambiente.
- Verificar no APK que fallback não provoca espera infinita ou cobrança inesperada, e que as consultas de outras cidades não geram alertas de GPS. Nunca incluir tokens ou dados sensíveis em logs e arquivos do repositório.
