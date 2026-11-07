# Vigia IA — Regras obrigatórias do projeto

Estas regras valem para qualquer correção, melhoria, refatoração, buildfix ou entrega.

## Obrigação anterior a qualquer edição: verificar a versão mais recente

- **Antes de desenvolver, corrigir ou empacotar**, verificar os ZIPs de código-fonte no diretório de trabalho **e** a pasta do Vigia IA no Google Drive conectado, quando acessível; conferir também os metadados reais do repositório quando disponíveis.
- Usar como base a **versão mais recente** de fonte confirmada, nunca a última versão vista numa conversa ou apenas o maior nome de arquivo sem inspecionar o `pubspec.yaml`.
- Caso existam linhas divergentes, comparar arquivos e trazer apenas as funcionalidades ausentes à base mais nova; **não substituir** os módulos novos pelos antigos. Checar que nenhum arquivo da base mais nova foi eliminado inadvertidamente.
- Incrementar `version` e `versionCode` em relação à maior versão encontrada; em caso de conflito ou dúvida, documentar a evidência e preservar ambas antes de integrar.
- Esta regra foi solicitada após a regressão que gerou 1.0.339–341 a partir da 1.0.338, apesar de a 1.0.350 já existir. Origem confirmada nesta recuperação: `Meu Drive/Projetos/Vigia IA/Vigia-IA-v1.0.350-APK294-Flutter-Analyze-Corrigido.zip`.

## Exportação de credenciais autorizada pelo usuário

- **Solicitação da versão 1.0.352:** exportar e importar chaves de APIs em `.env` UTF-8 legível, sem senha nem criptografia de arquivo, quando o usuário acionar a operação. Nunca impedir a exportação solicitada por exigir senha.
- O armazenamento de chaves no Android continua protegido pelo Keystore. Exportação em texto é ação distinta e explícita, com destino selecionado pelo usuário. Não logar credenciais nem incluir arquivos `.env` em ZIPs do código-fonte.
- Exibir as chaves cadastradas apenas quando o usuário escolher Mostrar em cada provedor; não revelar por padrão. A chave Maps SDK incorporada ao APK não é equivalente à chave salva na interface.
- Preservar importação legada `.vigiaapis` para backups anteriores.

## Versionamento obrigatório

- Nunca entregar uma nova modificação usando a mesma versão da entrega anterior.
- Toda entrega nova incrementa a versão pública e o build, inclusive correções pequenas.
- Sequência esperada: `1.0.49+49` → `1.0.50+50` → `1.0.51+51` → `1.0.52+52` → `1.0.53+53` → `1.0.54+54` → `1.0.55+55` → `1.0.56+56` → `1.0.57+57` → `1.0.58+58` → `1.0.59+59` → `1.0.60+60` → `1.0.61+61` → `1.0.62+62` → `1.0.63+63` → `1.0.64+64` → `1.0.65+65` → `1.0.66+66` → `1.0.67+67` → `1.0.68+68` → `1.0.69+69` → `1.0.70+70` → `1.0.71+71` → `1.0.72+72` → `1.0.73+73` → `1.0.74+74` → `1.0.75+75` → `1.0.76+76` → `1.0.77+77` → `1.0.78+78` → `1.0.79+79` → `1.0.80+80` → `1.0.81+81` → `1.0.82+82` → `1.0.83+83` → `1.0.84+84` → `1.0.85+85` → `1.0.86+86` → `1.0.87+87` → `1.0.88+88` → `1.0.89+89` → `1.0.90+90` → `1.0.91+91` → `1.0.92+92` → `1.0.93+93` → `1.0.94+94` → `1.0.95+95` → `1.0.96+96` → `1.0.97+97` → `1.0.98+98` → `1.0.99+99` → `1.0.100+100` → `1.0.101+101` → `1.0.102+102` → `1.0.103+103` → `1.0.104+104` → `1.0.105+105`.
- Nunca reutilizar uma versão que já tenha sido entregue em ZIP.

Antes do ZIP final, manter sincronizados:

- `pubspec.yaml`;
- `lib/core/app_metadata.dart`;
- `app_identity.json`;
- tela Sobre / Mudanças;
- `README.md`;
- `CHANGELOG.md`;
- `ARCHITECTURE.md`, quando aplicável;
- testes/verificadores de versão;
- nome do ZIP final.

## Retenção de versões no Google Drive (pedido do usuário em 06/11/2026)

- Pasta de destino: `Meu Drive/Projetos/Vigia IA/` (se faltar, recriar sob `Projetos`).
- **Manter somente o ZIP de código-fonte da versão vigente** nessa pasta.
- Após novo upload, conferir id, nome, tamanho e pasta pai em readback do Drive. **Só depois** apagar os ZIPs de código-fonte de versões anteriores do Vigia IA nessa pasta; excluir apenas arquivos reconhecidos pela versão e nome do projeto.
- Não apagar documentos não relacionados, outros projetos, nem backups locais. Se upload ou verificação falharem, preservar as versões anteriores e relatar a falha.

## Validação obrigatória

Antes de entregar:

1. confirmar que a versão é maior que a última já entregue;
2. executar `tool/verify_project.sh`;
3. executar `flutter analyze`, quando o SDK estiver disponível;
   - os checadores de imports e contrato de CI ajudam, mas não substituem o analisador Dart;
4. executar `flutter test`, quando o SDK estiver disponível;
5. validar a integridade do ZIP;
6. não reintroduzir nomes antigos do aplicativo;
7. entregar o ZIP com link clicável.

Se Flutter/Android SDK não estiver disponível, declarar explicitamente que analyze/test/build ainda precisam ser confirmados pelo workflow.

## Identidade oficial

- Nome público: `Vigia IA`
- Nome técnico: `vigiaia`
- Package/applicationId: `com.vigiaia.app`
- Protocolo: `vigiaia://pair`

## Checagem final

Antes de responder com uma entrega, conferir:

> A versão foi incrementada? Todos os metadados estão sincronizados? O CHANGELOG foi atualizado? O ZIP foi validado e está linkado?

Se alguma resposta for não, corrigir antes de entregar.

## Atualizador por GitHub Releases (desde 1.0.367)

- Preservar a verificação ao iniciar/retomar (intervalo mínimo de 60 s), o acesso manual em Sobre e a regra de **nunca baixar nem instalar automaticamente**.
- Repositório fixo público `drilemoz/Vigia-IA`; aceitar somente APK universal de release mais nova com nome/tag/URL verificados e digest SHA-256 do GitHub.
- Antes de abrir o instalador Android, validar novamente SHA-256, packageName, versionCode superior e mesma assinatura da versão instalada. Nunca desinstalar para atualizar.
- O CI pode recriar `android/` pelo `tool/bootstrap_android.sh`: manter sincronizados os arquivos `tool/android/MainActivity.kt`, `tool/AndroidManifest.xml`, `tool/android/VigiaUpdateInstaller.kt` e `tool/android/vigia_update_file_paths.xml` com suas cópias ativas.
- Verificar `tool/test_github_updates_367.py` e `test/github_release_update_test.dart` em cada mudança de atualização.
