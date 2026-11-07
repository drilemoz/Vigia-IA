# Vigia IA 1.0.369+369 — GitHub: corrigido falso atualizado

## Resumo

- Uma Release com tag maior agora é detectada independentemente do arquivo de download.
- Se o APK universal estiver ausente, com URL inadequada ou acima do limite, a tela mostra a versão disponível e orienta abrir a Release oficial, sem permitir baixar arquivo inseguro.
- Limite de APK universal aumentado para 600 MiB, mantendo SHA-256, packageName, versionCode e assinatura no verificador Android.
- A verificação continua online sob demanda ou ao retomar; funções offline não consultam internet para operar.
- Download e instalação permanecem manuais.
