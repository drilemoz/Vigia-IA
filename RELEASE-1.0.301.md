# Vigia IA 1.0.301+301 · Correção do workflow Android APK 252

- Corrigido falso positivo na verificação preventiva: um bloqueio histórico de 1.0.199 rejeitava palavras como `erro`, `falha` e `corrigido` em *qualquer* release atual.
- A política de Novidades agora exige a versão empacotada, uma única entrada e textos descritivos, e permite mensagens legítimas de correções e estabilidade.
- Adicionados testes de regressão para liberar descrições de correção e rejeitar catálogo antigo ou texto provisório.
- Preservados descoberta RTSP, transmissão, reprodução, gravação e demais módulos sem alterações funcionais nesta versão.
- APK 252 não avançou à análise Flutter/Gradle. A compilação e os testes em aparelho permanecem pendentes.
