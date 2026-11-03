# Vigia IA 1.0.336+336 — Buildfix Flutter Analyze APK 281

- Base: código-fonte 1.0.335+335; nenhuma substituição funcional de APIs ou mapas.
- Logs do workflow 281: 406 testes preventivos aprovados; `flutter analyze` encontrou 8 diagnósticos (um erro de null-safety, um warning e seis infos) e bloqueou o build.
- Correções nos cinco arquivos: `lib/screens/map_monitoring_screen.dart`, `lib/services/api_credentials_backup_service.dart`, `lib/services/geoapify_map_search_service.dart`, `lib/services/geoapify_poi_service.dart` e `lib/services/map_cycling_route_service.dart`.
- Acesso seguro a métricas opcionais de rota; import redundante eliminado; asserção redundante removida; blocos explícitos para condicionais curtas.
- Versionamento e catálogo de Novidades sincronizados. Não muda backup, protocolos, API keys nem comportamento offline.
- Validação local: `bash tool/verify_project.sh` concluído com exit 0; suíte de 413 testes Python (412 aprovados, 1 ignorado).
- Novos testes `tool/test_build281_flutter_analyze_336.py`: 7/7 aprovados. `tool/check_version_sync.py`, `tool/check_release_consistency.py` e integridade de fontes verificados.
- `flutter analyze`, testes Dart e compilação APK precisam ser confirmados no GitHub Actions.
