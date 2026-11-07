# Vigia IA 1.0.367+367 — Atualizações GitHub Releases

## Novo em Sobre

- Botão Verificar atualizações; versão instalada, nova versão, notas da Release, progresso real do download em MiB e MiB/s, cancelamento e abertura do instalador após confirmação.
- Consulta automática no início/retorno a primeiro plano, com janela mínima de um minuto e aviso de atualização sem baixar ou instalar automaticamente.
- A API pública GitHub Releases de `drilemoz/Vigia-IA` fornece a versão e o `digest` SHA-256 do APK universal.

## Proteções

- Sem hash SHA-256 no metadado: download pelo aplicativo bloqueado, link para Releases disponível.
- Repositório fixo, nome/URL da Release verificados, apenas versão maior e APK universal publicado, tamanho limitado.
- Android valida novamente SHA-256, `com.vigiaia.app`, versionCode maior e mesma assinatura do APK já instalado antes de abrir o instalador; usuário autoriza fontes desconhecidas e confirma a instalação. Não desinstalar a versão anterior.
- Erros DNS/SSL/HTTP/timeout não impedem uso offline e não geram downloads automáticos.

## Validação

- Testes Python estruturais e política Dart incluídos. Flutter Analyze, Flutter Test e APK devem ser verificados pelo próximo workflow Android.
