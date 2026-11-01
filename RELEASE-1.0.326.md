# Vigia IA 1.0.326+326 — Assistente inicial de serviços e APIs

- Após a tela de permissões, surge a etapa **Serviços e APIs** com Gemini, Google Maps Platform e Stadia Maps, todas opcionais.
- Cada cartão oferece acesso às telas existentes de configurar/salvar/testar chave e ao site oficial de obtenção da credencial.
- Stadia reutiliza a janela já existente dentro do gerenciador de mapas offline, com limites/créditos preservados.
- Usuário pode prosseguir sem chave; configurações permanecem acessíveis posteriormente por Configurações > Serviços e APIs ou opções individuais existentes.
- A conclusão do onboarding só ocorre após a etapa de APIs. Marcador Android local (não sensível, fora de backup) retoma a etapa após interrupção.
- Não modifica a política de cobrança nem chama APIs automaticamente. OpenStreetMap, mapas offline, câmeras, RTSP e IA local mantidos.
- A atualização não repete o onboarding para instalações já concluídas.

**Validação:** testes Python estruturais e `tool/verify_project.sh`; build Flutter/Android e teste do assistente em dispositivo reais pendentes.
