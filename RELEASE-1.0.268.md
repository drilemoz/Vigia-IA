# Vigia IA 1.0.268+268

**Melhoria de FPS da análise da câmera local.** Código-fonte Flutter, sem APK compilado.

- Removido o bloqueio oculto que elevava qualquer cadência inferior a 900 ms para 900 ms (teto de ~1,1 FPS nos quadros analisados).
- Respeitado o intervalo definido pelo usuário ou pelo perfil Bike: padrão 400 ms (~2,5 FPS alvo), Bike economia 650 ms (~1,5 FPS), extrema 1000 ms (~1 FPS).
- Limite mínimo de 250 ms (~4 FPS alvo), alinhado à política de conversão da câmera; Ajustes avançados permite configurar 250–2000 ms.
- Diagnóstico agora distingue FPS de quadros submetidos à IA, meta configurada e FPS do CameraPreview nativo.
- Backpressure de conversão e do detector preservado para evitar acumular frames; FPS observado pode ser inferior ao alvo em hardware carregado.
- Aviso: maior taxa de análise aumenta CPU/temperatura/consumo, especialmente com câmera + duas fontes + mapa; valide gradualmente e teste limites térmicos.
- Não altera RTSP/MJPEG remoto, não promete ganho garantido e não muda resolução nem modelo padrão.

Validação via scripts Python e integridade ZIP; Flutter analyze/test e build Android devem ser confirmados no CI.
