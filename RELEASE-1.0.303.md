# Vigia IA 1.0.303+303

## Correção do Android-APK-254 (Flutter Test)

- Ajustado o teste de controles MCRP para o **zoom compacto** vigente desde 1.0.297: título `Zoom`, X com tooltip `Fechar` e restauro 1× pelo tooltip `Zoom original (1×)`.
- O teste continua verificando a exibição de 40%/50%/0% e a sequência real de comandos `record/start`, `zoom/50`, `zoom/0`, `quality/480`, `fps/10` e `torch/30`. Nenhuma alteração de rede ou API do transmissor.
- Criada verificação estática de regressão para detectar referências a textos antigos do modal nos testes Flutter.
- Versão 1.0.303+303, metadados, catálogo de Novidades, documentação e User-Agents sincronizados.

### Evidência

O workflow Android-APK-254 passou em `flutter analyze` e chegou ao `flutter test`, onde **569 testes foram aprovados e 1 falhou** exclusivamente por procurar `Zoom da câmera` (texto removido pela interface compacta). A compilação APK **não chegou a começar**.

### Testes pendentes

- `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` e `flutter build apk` para a versão 1.0.303 dependem do próximo workflow GitHub Actions; SDK Flutter não disponível neste ambiente.
- Interação real em dois celulares permanece pendente.
