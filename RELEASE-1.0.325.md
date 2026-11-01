# Vigia IA 1.0.325+325 — Busca Gemini opcional no mapa

- Configurações e configurações do mapa ganham opção **Gemini para Mapas**, com chave privada e ações Salvar, Colar, Copiar, Mostrar/Ocultar, Remover e Testar.
- Usa Android Keystore + AES-GCM e regras de backup para excluir a chave; não copia configuração do Uai Cortes automaticamente, sendo apps independentes.
- Modelo padrão `gemini-3.5-flash-lite`, alternativo `gemini-3.8-flash`, ambos sujeitos à disponibilidade/cotas da chave.
- Botão **Buscar com Gemini (opcional)** dentro da pesquisa tradicional do mapa. Gemini interpreta a frase e devolve texto para buscar via índice local/Nominatim; só resultados confirmados exibem ações para navegar, salvar ou adicionar parada.
- Chamadas só após solicitação; nenhuma localização GPS ou chave é incluída em logs ou relatórios. Pesquisas são enviadas ao Gemini e a expressão sugerida ao Nominatim. Uso pode gerar custo.
- Rede ausente, chave inválida, modelo não disponível, respostas vazias e limites de cota tratados. Os recursos offline permanecem independentes.

**Validação:** `tool/test_gemini_maps_325.py` e suíte Python; Flutter analyze/test, build APK, autenticação com chave real e testes Android continuam pendentes fora deste ambiente.
