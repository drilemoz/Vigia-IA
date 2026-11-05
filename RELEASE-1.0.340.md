# Vigia IA 1.0.340+340 — Correção do workflow APK 296

- Corrigido o teste `tool/test_news_catalog_policy_301.py`: não procura mais texto de mapas offline já substituído na 1.0.339. Agora corrompe uma mensagem realmente presente no catálogo e valida a rejeição, além de teste de versão antiga.
- Sincronizados versionName/versionCode, Novidades, histórico de mudanças, metadados, README, CHANGELOG e documentação.
- Mantidas as funcionalidades de transporte RTSP automático UDP/TCP por câmera, mapas e downloads offline.
- Compilação Flutter e Android não comprovadas nesta entrega; executar GitHub Actions e testes físicos.
