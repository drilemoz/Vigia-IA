# Vigia IA 1.0.323+323 · Ajustar ritmo durante a navegação

## Alterações

- O painel de navegação Bike expandido contém **Ajustar ritmo**, mesmo depois que o percurso começou. Mantém o controle de minimizar/expandir.
- Diálogo de planejamento reutilizado com média manual de 8 a 30 km/h, 1 a 12 horas/dia, opção de equilibrar dias e média aprendida somente quando confiável.
- Confirmação salva as preferências e recalcula a duração restante estimada, o total de dias e o plano Bike, sem terminar a navegação.
- Se a navegação mudou de destino enquanto o diálogo estava aberto, o resultado não é aplicado à navegação antiga. O plano assíncrono continua usando checagens de destino/traçado já existentes.
- O diagnóstico registra `editar_ritmo_navegacao_ativa` e `ritmo_navegacao_recalculado`, sem valores, credenciais ou localização.
- Recurso exige que haja uma navegação de bicicleta ativa. Não promete roteamento offline e não altera o VLC ou Media3.

## Testes

- Regressões Python estruturais e teste Flutter de estimativa de pedal. O SDK Flutter/Android não está disponível nesta sessão: `flutter analyze`, `flutter test` e APK aguardam execução no workflow GitHub Actions.
