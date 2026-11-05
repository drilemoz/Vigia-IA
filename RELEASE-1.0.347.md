# Vigia IA 1.0.347+347 — Visual do mapa mais simples

- Painel Aparência e camadas substituído por **Visual do mapa**, com três abas independentes e uma lista de modos por vez.
- Aparência: Padrão, Escuro, Alto contraste, Bike/Viagem, Sistema e Dia/noite.
- Provedor: Mapa atual e Google Maps (somente quando o APK incluir a chave de build necessária).
- Base: Padrão, Bike/Viagem, Terreno, Topográfico e Satélite; os estilos que dependem de Stadia permanecem bloqueados sem chave no renderer atual.
- Seleção acompanhada de descrição; botão OK aplica e Cancelar/fechar descarta.
- Serviços e APIs foi removido do seletor, permanecendo em Configurações; sem migração de preferências e sem alteração de mapas offline.
- Novos testes Flutter e contratos preventivos.

**Limitações:** requer `flutter analyze`, `flutter test`, build Android e validação visual em aparelho pelo workflow; nenhum APK incluído neste ZIP de código-fonte.
