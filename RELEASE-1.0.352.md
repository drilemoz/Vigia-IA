# Vigia IA 1.0.352+352 — APIs e backups legíveis

**Base:** `Vigia-IA-v1.0.351-Base350-RTSP-Integrado.zip`, confirmada como última local em 05/11/2026; no Drive, versão 1.0.350.

## Implementado
- Tela Google Maps: Colar, Copiar e Verificar configuração lado a lado em uma única linha.
- Serviços e APIs: nova tela de chaves cadastradas, status por provedor, revelação e cópia sob toque explícito.
- Exportação/importação de arquivo `.env` UTF-8 sem criptografia e sem senha. Importação validada e confirmação de substituição; chaves ausentes no arquivo permanecem salvas.
- Importação antiga `.vigiaapis` com senha preservada; API do Google Maps embutida no APK nunca exportada.
- Seletor nativo também aceita arquivos `.env` curtos.

## Limites
- `.env` exportado contém chaves legíveis: não publicar, não enviar ao GitHub e guardar em local protegido.
- Não altera a chave incorporada ao APK do Google Maps.
- Build Flutter/Android e teste de interface no aparelho pendentes se não houver SDK local.
