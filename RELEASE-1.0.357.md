# Vigia IA 1.0.357+357 — Cidades e apoios no corredor da cicloviagem

A lista do Planejamento agora apresenta nomes existentes em dados salvos ao longo da geometria da rota, na ordem da viagem e com quilometragem aproximada. Localidades ainda não indexadas precisam de conexão ou importação de pacotes. Ao criar ou abrir uma viagem, não há busca online automática; o botão Buscar apoios dispara a consulta manual em lotes pequenos com limites de serviço. POIs offline próximos do segmento também aparecem no mapa com maior fidelidade.

**Não há garantia de identificação de todas as cidades ou de acesso rodoviário, água e hospedagem.** Distâncias até o traçado são em linha reta; a geometria pode se aproximar de uma localidade sem atravessá-la. Relevo, chuva, recálculo offline e importação de extratos OSM permanecem fora deste release. O aplicativo conserva o limite contratual de downloads diretos da Stadia Maps.

Validação: executar `tool/verify_project.sh`, `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` e montagem de APK. Sem SDK Flutter instalado no ambiente local, compilação e teste Android precisam de GitHub Actions e dispositivo.
