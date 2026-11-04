# Vigia IA 1.0.346+346 — APK 291

## Correção
- Atualiza o teste do diálogo de recuperação para o título apresentado quando o incidente foi registrado em outra versão.
- Mantém a distinção entre avisos de memória em segundo plano, falhas recuperadas e erros atuais.
- Adiciona regressão de interface para verificar o título de erro da própria versão instalada.

## Validação
- Verificação preventiva aprovada (exit 0), incluindo 456 testes Python consolidados, 1 ignorado e 0 falhas.
- `flutter analyze`, `flutter test` e compilação Android ainda pendentes do próximo workflow; não se trata de um APK pronto.
