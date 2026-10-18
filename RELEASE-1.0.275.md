# Vigia IA 1.0.275+275

## Correção de compilação do APK 228

- Incorporada a dependência `Nv21Frames.kt` que faltava ao serviço de captura nativo, responsável por rotacionar os quadros NV21 antes de publicar o vídeo.
- Fonte original do Minha Câmera 1.4.74 copiada para `android/app/src/main/kotlin/com/minhacamera` e `tool/android/native_transmitter`, mantendo a compilação após o bootstrap Android.
- Adicionada regressão Kotlin JVM para rotações 0/90/180/270 e preservação dos planos de crominância NV21; guardrails estáticos evitam omissão futura.
- Mantidos controles MCRP, modo Ao vivo e transmissor Flutter legado sem alterações de comportamento.

## Estado da validação

- Os logs do APK 228 registraram Flutter Analyze e testes passando; erro apenas em `:app:compileReleaseKotlin` por símbolo ausente.
- Os testes locais da 1.0.275 não substituem um build Android real e teste no Redmi A3.
